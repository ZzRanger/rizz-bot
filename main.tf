# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0



variable "openai_api_key" {
  type        = string
  description = "An API key or authentication token used to access and authenticate with OpenAI"
}

variable "twilio_account_sid" {
  type        = string
  description = "Unique identifier associated with a Twilio account for authentication and association of API requests"
}

variable "twilio_auth_token" {
  type        = string
  description = "Authentication token or secret associated with a Twilio account for secure access to account resources"
}

variable "twilio_from_phone_number" {
  type        = string
  description = "Phone number associated with a Twilio account used as the sender or from number for SMS messages or phone calls"
}

variable "twilio_to_phone_number_one" {
  type        = string
  description = "Phone number of the first recipient or to number for SMS messages or phone calls with Twilio"
}

variable "twilio_to_phone_number_two" {
  type        = string
  description = "Phone number of the second recipient or to number for SMS messages or phone calls with Twilio"
}


provider "aws" {
  region = "us-east-2"
}


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}



provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  source_file = "lambda-hilly-rizz/dist/index.js"
  output_path = "welcome.zip"
}



resource "aws_lambda_function" "lambda" {
  function_name    = "lambda-hilly-rizz"
  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs16.x"
  timeout          = 60

  environment {
    variables = {
      OPENAI_API_KEY             = var.openai_api_key
      TWILIO_ACCOUNT_SID         = var.twilio_account_sid
      TWILIO_AUTH_TOKEN          = var.twilio_auth_token
      TWILIO_FROM_PHONE_NUMBER   = var.twilio_from_phone_number
      TWILIO_TO_PHONE_NUMBER_ONE = var.twilio_to_phone_number_one
      TWILIO_TO_PHONE_NUMBER_TWO = var.twilio_to_phone_number_two
    }
  }
}

resource "aws_cloudwatch_log_group" "function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iam_policy" "function_logging_policy" {
  name = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role       = aws_iam_role.iam_for_lambda.id
  policy_arn = aws_iam_policy.function_logging_policy.arn
}


data "aws_iam_policy_document" "policy_schedule" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["scheduler.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "iam_for_scheduler" {
  name               = "iam_for_scheduler"
  assume_role_policy = data.aws_iam_policy_document.policy_schedule.json

  inline_policy {
    name   = "policy-8675309"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_scheduler_schedule" "scheduler" {
  name       = "rizz-scheduler"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(1 days)"

  target {
    arn      = aws_lambda_function.lambda.arn
    role_arn = aws_iam_role.iam_for_scheduler.arn
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.scheduler.arn
}
