###############################
# Iam Role for ecs task excution
##############################
# Create IAM role for task execution role
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name = "${var.app_name}-ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume-role.json
}

# Attaching policy to iam role for ecs task execution role
resource "aws_iam_role_policy_attachment" "iam-policy-att" {
  role = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = var.ecs-policy-arn
}


#####################################
# IAM role for ecs agent
#####################################
resource "aws_iam_role" "ecs_agent" {
  name = "${var.app_name}-ecs-agent-role"
 
  assume_role_policy = data.aws_iam_policy_document.agent-assume-role.json
}


# The policy resource itself.
resource "aws_iam_policy" "ecs_agent" {
  name = "${var.app_name}-ecs-agent-policy"
  path = "/"
  description = "Access policy for the EC2 instances backing the ECS cluster."

  policy = data.aws_iam_policy_document.ecs_agent.json
}

# Attaching policy to iam role for ecs agent
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = aws_iam_policy.ecs_agent.arn
}


# role profile for ec2 instance
resource "aws_iam_instance_profile" "ecs-agent-profile" {
  name = "${var.app_name}-ecs-agent-profile"
  role = aws_iam_role.ecs_agent.name
}


