# resource "aws_sqs_queue" "circleci_graceful_termination_autoscale" {
#   name = "circleci_graceful_termination_autoscale"
# }
resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.circleci_graceful_shutdown.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.circleci_graceful_termination_autoscale.arn
}

resource "aws_sns_topic" "circleci_graceful_termination_autoscale" {
  name = "circleci_graceful_termination_autoscale"
}

resource "aws_iam_role" "circleci_autoscaling_role" {
  name = "circleci_autoscaling_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": ["autoscaling.amazonaws.com","lambda.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lifecycle_hook_autoscaling_policy" {
  name = "lifecycle_hook_autoscaling_policy"
  role = aws_iam_role.circleci_autoscaling_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1436380187000",
            "Effect": "Allow",
            "Action": [
                "sns:Publish"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_autoscaling_lifecycle_hook" "graceful_shutdown_asg_hook" {
  name = "graceful_shutdown_asg"
  autoscaling_group_name = aws_autoscaling_group.clients_asg[0].name
  default_result = "CONTINUE"
  heartbeat_timeout = 3600
  lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
  notification_target_arn = aws_sns_topic.circleci_graceful_termination_autoscale.arn
  role_arn = aws_iam_role.circleci_autoscaling_role.arn
}

// Schedule Lifecycle Action
resource "aws_autoscaling_schedule" "graceful_shutdown_action" {
  scheduled_action_name  = "Nomad Graceful Shutdown Action"
  min_size               = 0
  max_size               = 1
  desired_capacity       = 0
//  start_time             = "2020-07-28T18:00:00Z"
//  end_time               = "2025-07-28T18:00:00Z"
  recurrence             = "0 0 * * Fri"
  autoscaling_group_name = aws_autoscaling_group.clients_asg[0].name
}


resource "aws_lambda_function" "circleci_graceful_shutdown" {
  filename      = "${path.module}/files/circleci-nomad-autoscaling.zip"
  function_name = "circleci-graceful-shutdown"
  role          = aws_iam_role.circleci_autoscaling_role.arn
  handler       = "index.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("circleci-nomad-autoscaling.zip"))}"
  source_code_hash = filebase64sha256("${path.module}/files/circleci-nomad-autoscaling.zip")
  runtime = "nodejs12.x"

  environment {
    variables = {
        s3_bucket = "cxe-devops-data-circleci"
        s3_key = "CircleCiDrainNodes"
        region = var.aws_region
    }
  }
}

resource "aws_sns_topic_subscription" "circleci_graceful_termination_subscription" {
  topic_arn = aws_sns_topic.circleci_graceful_termination_autoscale.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.circleci_graceful_shutdown.arn
}

output "sns_topic_arn" {
  value = aws_sns_topic.circleci_graceful_termination_autoscale.arn
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "cxe-devops-data-usw2-circleci"
}

resource "aws_s3_bucket_object" "scalein" {
  bucket = aws_s3_bucket.my_bucket.id
  key = "CircleCiDrainNodes"
  source = "${path.module}/files/aws-ssm-drain-document.json"
}