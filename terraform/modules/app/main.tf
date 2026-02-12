terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ========== IAM Role for EC2 (SSM + CloudWatch) ==========
resource "aws_iam_role" "app" {
  name = "${var.environment}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.environment}-app-profile"
  role = aws_iam_role.app.name
}

# ========== Launch Template ==========
resource "aws_launch_template" "this" {
  name_prefix   = "${var.environment}-app-"
  image_id      = var.ami_id
  instance_type = var.instance_type


  iam_instance_profile {
    arn = aws_iam_instance_profile.app.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      {
        Name = "${var.environment}-app-instance"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.common_tags,
      {
        Name = "${var.environment}-app-volume"
      }
    )
  }

  # ========== USER DATA: Harden SSH + Install Java App ==========
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-cloudwatch-agent amazon-ssm-agent

    # 🔒 DISABLE PASSWORD AUTHENTICATION
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd

    # Install Java
    amazon-linux-extras install java-openjdk11 -y

    # Download & run Java app (replace with your artifact URL)
    mkdir -p /opt/app
    aws s3 cp s3://${var.artifact_bucket}/${var.artifact_key} /opt/app/app.jar
    chmod +x /opt/app/app.jar

    # Run as systemd service
    cat > /etc/systemd/system/app.service <<'SERVICE_EOF'
    [Unit]
    Description=Java Application
    After=network.target

    [Service]
    User=ec2-user
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/java -jar /opt/app/app.jar --server.port=${var.app_port} --spring.datasource.url=jdbc:postgresql://${var.db_host}:${var.db_port}/${var.db_name} --spring.datasource.username=${var.db_user} --spring.datasource.password=${var.db_password}
    Restart=on-failure
    Environment=JAVA_OPTS="-Xmx512m -Xms256m"

    [Install]
    WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    systemctl enable app.service
    systemctl start app.service

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:AmazonCloudWatch-linux
  EOF
  )


  lifecycle {
    create_before_destroy = true
  }
}

# ========== Auto Scaling Group ==========
resource "aws_autoscaling_group" "this" {
  name                = "${var.environment}-asg"
  vpc_zone_identifier = var.private_subnets
  target_group_arns   = [var.target_group_arn]
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300
  wait_for_elb_capacity     = var.asg_desired_capacity

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ========== Scaling Policies ==========
resource "aws_autoscaling_policy" "cpu_scale_up" {
  name                   = "${var.environment}-cpu-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  alarm_actions = [aws_autoscaling_policy.cpu_scale_up.arn]
}

resource "aws_autoscaling_policy" "cpu_scale_down" {
  name                   = "${var.environment}-cpu-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "4"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }
  alarm_actions = [aws_autoscaling_policy.cpu_scale_down.arn]
}
