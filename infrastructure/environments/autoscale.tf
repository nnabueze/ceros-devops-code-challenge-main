############################################
# Lunch configuration for autoscaling that 
# that back our ecs cluster
############################################
resource "aws_launch_configuration" "cluster" {
  name                 = "${var.app_name}-${var.app_environment}-cluster"
  image_id             = data.aws_ssm_parameter.ami.value
  instance_type        = var.bh-instance-type
  key_name             = aws_key_pair.bh-key-pair.key_name
  iam_instance_profile = aws_iam_instance_profile.ecs-agent-profile.name
  security_groups      = [aws_security_group.sg-scaling-ecs-cluster.id]

  // Register our EC2 instances with the correct ECS cluster.
  user_data = <<EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.cluster.name}" >> /etc/ecs/ecs.config
    EOF

  depends_on = [
    aws_nat_gateway.nat-gateway
  ]
}

# The autoscaling group that backs our ECS cluster.
resource "aws_autoscaling_group" "asg-cluster" {
  name                      = "${var.app_name}-${var.app_environment}-asg-cluster"
  min_size                  = 3
  max_size                  = 3
  health_check_grace_period = 300
  health_check_type         = "EC2"

  vpc_zone_identifier  = aws_subnet.private-subnet.*.id
  launch_configuration = aws_launch_configuration.cluster.name

  tags = [{
    "key"                 = "Application"
    "value"               = var.app_name
    "propagate_at_launch" = true
    },
    {
      "key"                 = "Environment"
      "value"               = var.app_environment
      "propagate_at_launch" = true
    },
    {
      "key"                 = "Resource"
      "value"               = "modules.ecs.cluster.aws_autoscaling_group.cluster"
      "propagate_at_launch" = true
  }]

  depends_on = [
    aws_nat_gateway.nat-gateway
  ]
}

# # Autoscalling group for sacling up
resource "aws_autoscaling_policy" "agents-scale-up" {
    name = "${var.app_name}-agents-scale-up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.asg-cluster.name}"
}

# # autoscling group for caling down
resource "aws_autoscaling_policy" "agents-scale-down" {
    name = "${var.app_name}-agents-scale-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = "${aws_autoscaling_group.asg-cluster.name}"
}


# #############################################
# # Cloud watch alarm for ec2 memory to trigger
# # Auto scaling
# ############################################
# # This metric monitors ec2 memory for high utilization on agent hosts
resource "aws_cloudwatch_metric_alarm" "memory-high" {
    alarm_name = "${var.app_name}-mem-util-high-agents"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "MemoryUtilization"
    namespace = "System/Linux"
    period = "300"
    statistic = "Average"
    threshold = "80"
    alarm_description = "This metric monitors ec2 memory for high utilization on agent hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.agents-scale-up.arn}"
    ]
    dimensions = {
        AutoScalingGroupName = "${aws_autoscaling_group.asg-cluster.name}"
    }
}

# # This metric monitors ec2 memory for low utilization on agent hosts
resource "aws_cloudwatch_metric_alarm" "memory-low" {
    alarm_name = "${var.app_name}-mem-util-low-agents"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = "2"
    metric_name = "MemoryUtilization"
    namespace = "System/Linux"
    period = "300"
    statistic = "Average"
    threshold = "40"
    alarm_description = "This metric monitors ec2 memory for low utilization on agent hosts"
    alarm_actions = [
        "${aws_autoscaling_policy.agents-scale-down.arn}"
    ]
    dimensions = {
        AutoScalingGroupName = "${aws_autoscaling_group.asg-cluster.name}"
    }
}
