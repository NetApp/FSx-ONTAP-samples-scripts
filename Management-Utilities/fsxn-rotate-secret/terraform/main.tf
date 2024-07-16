#
# Create a random id to ensure no conflicts.
resource "random_id" "id" {
  byte_length = 4
}
#
# Create the assume role policy document for the Lambda function.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
#
# Create the inline policy document for the Lambda function role.
data "aws_iam_policy_document" "inline_permissions" {
    #
    # The frist two statements are required for the lambda function to write logs to CloudWatch.
    # While not required, are useful for debugging.
    statement {
        sid       = "Sid0"
        effect    = "Allow"
        actions   = ["logs:CreateLogGroup"]
        resources = ["arn:aws:logs:${var.region}:${var.awsAccountId}:*"]
    }
    statement {
        sid       = "Sid1"
        effect    = "Allow"
        actions   = [
            "logs:PutLogEvents",
            "logs:CreateLogStream"
        ]
        resources = ["arn:aws:logs:${var.region}:${var.awsAccountId}:log-group:/aws/lambda/${local.lambdaName}:*"]
    }
    #
    # The third statement is required for the lambda function to rotate the secret.
    # Both within the Secrets Manager and the FSx file system.
    statement {
        sid       = "Sid2"
        effect    = "Allow"
        actions   = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:PutSecretValue",
            "secretsmanager:UpdateSecretVersionStage",
            "fsx:UpdateFileSystem"
        ]
        resources = [
            aws_secretsmanager_secret.secret.arn,
            "arn:aws:fsx:${var.region}:${var.awsAccountId}:file-system/${var.fsxId}"
        ]
    }
    #
    # The fourth statement is required for the lambda function to generate a random password.
    statement {
        sid       = "sid3"
        effect    = "Allow"
        actions   = ["secretsmanager:GetRandomPassword"]
        resources = ["*"]
    }
}
#
# Create a local variable for the Lambda function name, so it can be used in two places without causing a cycle.
locals {
  lambdaName = "fsxn_rotate_secret-${random_id.id.hex}"
}
#
# Create the IAM role for the Lambda function.
resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda-${random_id.id.hex}"
  decription         = "IAM role for the Rotate FSxN Secret Lambda function."
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  inline_policy {
    name   = "required_policy"
    policy = data.aws_iam_policy_document.inline_permissions.json
  }
}
#
# Create the archive file for the Lambda function.
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../fsxn_rotate_secret.py"
  output_path = "fsxn_rotate_secret.zip"
}
#
# Create the Lambda function.
resource "aws_lambda_function" "rotateLambdaFunction" {
  function_name    = local.lambdaName
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "python3.12"
  handler          = "fsxn_rotate_secret.lambda_handler"
  filename         = "fsxn_rotate_secret.zip"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
#
# Allow Secrets Manager to invoke the Lambda function.
resource "aws_lambda_permission" "allowSecretsManager" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotateLambdaFunction.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.secret.arn
}
#
# Create the secret with the required tags.
resource "aws_secretsmanager_secret" "secret" {
  name = "${var.secretNamePrefix}-${random_id.id.hex}"

  tags = {
    fsxId  = var.fsxId
    region = var.region
  }
}
#
# Add the rotation Lambda function and rule to the secret.
resource "aws_secretsmanager_secret_rotation" "secretRotation" {
  secret_id           = aws_secretsmanager_secret.secret.id
  rotation_lambda_arn = aws_lambda_function.rotateLambdaFunction.arn

  rotation_rules {
    schedule_expression = var.rotationFrequency
  }
}
