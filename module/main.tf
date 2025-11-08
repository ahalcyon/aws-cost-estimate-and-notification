data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/cost_notifier_lambda.py"
  output_path = "${path.module}/cost_notifier_lambda.zip"
}

# SNSトピック
resource "aws_sns_topic" "cost_notification" {
  name = "${var.project}-cost-notification"
}

# SNSサブスクリプション
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.cost_notification.arn
  protocol  = "email"
  endpoint  = var.recipient_email
}

# Lambda用のIAMロール
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project}-lambda-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambdaの実行ポリシー
resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "${var.project}-lambda-exec-policy"
  role = aws_iam_role.lambda_exec_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = "ce:GetCostAndUsage"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cost_notification.arn
      }
    ]
  })
}

# Lambda関数
resource "aws_lambda_function" "cost_notifier" {
  function_name = var.project
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "cost_notifier_lambda.handler"
  runtime       = "python3.9"
  timeout       = 30

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN      = aws_sns_topic.cost_notification.arn
    }
  }
}

# Scheduler用のIAMロール
resource "aws_iam_role" "scheduler" {
  name = "${var.project}-scheduler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

# SchedulerがLambdaを呼び出すためのポリシー
resource "aws_iam_role_policy" "scheduler_invoke_lambda" {
  name = "${var.project}-scheduler-invoke-lambda"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.cost_notifier.arn
      }
    ]
  })
}

# Scheduler
resource "aws_scheduler_schedule" "cost_watcher" {
  name                         = var.project
  description                  = "Invoke Lambda to check AWS costs and notify via SNS"
  schedule_expression          = var.batch_schedule
  schedule_expression_timezone = var.batch_timezone
  flexible_time_window {
    mode = "OFF"
  }
  state = "ENABLED"
  target {
    arn      = aws_lambda_function.cost_notifier.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
