provider "aws" {
  region = "ap-south-1"
}

#####################
# S3 BUCKETS
#####################

resource "aws_s3_bucket" "raw" {
  bucket = "free-raw-data-bucket-12345"
  force_destroy = true
}

resource "aws_s3_bucket" "processed" {
  bucket = "free-processed-data-bucket-12345"
  force_destroy = true
}

resource "aws_s3_bucket" "reports" {
  bucket = "free-reports-data-bucket-12345"
  force_destroy = true
}

#####################
# IAM ROLE
#####################

resource "aws_iam_role" "lambda_role" {
  name = "free-tier-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "lambda:GetPolicy",
          "lambda:RemovePermission",
          "lambda:DeleteFunction",
          "s3:DeleteBucket",
          "s3:DeleteObject",
          "iam:DeleteRole",
          "iam:DeleteRolePolicy",
          "events:DeleteRule",
          "events:RemoveTargets"

        ]
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*",
          aws_s3_bucket.reports.arn,
          "${aws_s3_bucket.reports.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}


#####################
# LAMBDA FUNCTIONS
#####################

resource "aws_lambda_function" "processor" {
  function_name = "free-data-processor"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "processor.handler"
  filename      = "../lambda/processor.zip"
}

resource "aws_lambda_function" "report" {
  function_name = "free-daily-report"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  handler       = "report.handler"
  filename      = "../lambda/report.zip"
}

#####################
# S3 → LAMBDA TRIGGER
#####################

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

resource "aws_s3_bucket_notification" "s3_trigger" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3]
}

#####################
# EVENTBRIDGE (DAILY)
#####################

resource "aws_cloudwatch_event_rule" "daily_rule" {
  name                = "free-daily-report-rule"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "daily_target" {
  rule = aws_cloudwatch_event_rule.daily_rule.name
  arn  = aws_lambda_function.report.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal     = "events.amazonaws.com"
}
