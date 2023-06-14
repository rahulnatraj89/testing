
resource "aws_iam_instance_profile" "app1_instance_profile" {
  name = "app1_stg_instance_profile"
  role = var.app1_iam_role
}
resource "aws_efs_file_system" "app1_efs" {
tags = {
Name = "MyProduct"
  }
}
resource "aws_launch_template" "app1_launch_template" {
  name = "app1-launch-stg-template"
  description = "app1Launch template"
  image_id = var.APP_instance_ami
  instance_type = var.APP_instance_type
  vpc_security_group_ids = var.APP_security_group_ids
  key_name = var.key_pair
  user_data = filebase64("${path.module}/app1_userdata.sh")
  ebs_optimized = true 
  update_default_version = true 
  block_device_mappings {
    device_name = var.device_name
    ebs {  
      volume_size = var.EBS_block_volume_size             
      delete_on_termination = true
      volume_type = var.device_type
    }
   }
  monitoring {
    enabled = true
  }   
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app1-stg-asg"
    }
  }   
}
resource "aws_autoscaling_group" "app1_asg" {
  name_prefix = "app1_stg_asg-"
  desired_capacity = 1
  max_size = var.max_size
  min_size = var.min_size
  vpc_zone_identifier       = var.vpc_zone_identifier
  health_check_type = "EC2"
  launch_template {
    id = aws_launch_template.app1_launch_template.id 
    version = aws_launch_template.app1_launch_template.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50            
    }
  }
  tag {
    key                 = "Name"
    value               = "cgr-stg-tc-9833"
    propagate_at_launch = true
  }
}
resource "aws_eip" "cgr" {
  domain   = "vpc"
}
resource "aws_eip_association" "cgr" {
  instance_id = ""
  allocation_id = aws_eip.cgr
}
resource "aws_autoscaling_policy" "app1_cpu_high" {
  name                   = "${var.name_prefix}-app1-cpu-high"
  autoscaling_group_name = aws_autoscaling_group.app1_asg.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = "1"
  cooldown               = "600"
}
resource "aws_autoscaling_policy" "app1_cpu_low" {
  name                   = "${var.name_prefix}-app1-cpu-high"
  autoscaling_group_name = aws_autoscaling_group.app2_asg.name
  adjustment_type        = "ChangeInCapacity"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = "-1"
  cooldown               = "600"
}
resource "aws_cloudwatch_metric_alarm" "app1_cpu_high_alarm" {
  alarm_name          = "${var.name_prefix}-app1-cpu-high-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "90"
  actions_enabled     = true
  alarm_actions       = ["${aws_autoscaling_policy.app1_cpu_high.arn}"]
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.app1_asg.name}"
  }
}
resource "aws_cloudwatch_metric_alarm" "app1_cpu_low_alarm" {
  alarm_name          = "${var.name_prefix}-app1-cpu-low-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"
  actions_enabled     = true
  alarm_actions       = ["${aws_autoscaling_policy.app1_cpu_low.arn}"]
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.app1_asg.name}"
  }
}

#!/bin/bash
/USAC/usacfirstboot-cloudinit.sh cgr-stg-tc-9833.clouddev.loc

# Associate Elastic IP
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ALLOCATION_ID="your_eip_allocation_id"  # Replace with your EIP allocation ID

aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id $ALLOCATION_ID --region your_aws_region



