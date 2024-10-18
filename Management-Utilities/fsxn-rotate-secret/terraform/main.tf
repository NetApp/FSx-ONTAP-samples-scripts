#
# To allow support for secrets to be stored in a separate region than the FSxN file system,
# create a provider just for the Secrets Manager.
provider "aws" {
  alias = "secrets_provider"
  region = var.secret_region
}
#
# Create a random id to ensure no conflicts.
resource "random_id" "id" {
  byte_length = 4
}
#
# Create a local variable for the Lambda function name, so it can be used in two places without causing a cycle.
locals {
  lambdaName = "fsxn_rotate_secret-${random_id.id.hex}"
}
#
# Create the policy document for the assume role policy for the Lambda function role.
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
# Create a policy document for the policy for the Lambda function role.
data "aws_iam_policy_document" "lambda_permissions" {
    #
    # The frist two statements are required for the lambda function to write logs to CloudWatch.
    # While not required, are useful for debugging.
    statement {
        sid       = "Sid0"
        effect    = "Allow"
        actions   = ["logs:CreateLogGroup"]
        resources = ["arn:aws:logs:${var.secret_region}:${var.aws_account_id}:*"]
    }
    statement {
        sid       = "Sid1"
        effect    = "Allow"
        actions   = [
            "logs:PutLogEvents",
            "logs:CreateLogStream"
        ]
        resources = ["arn:aws:logs:${var.secret_region}:${var.aws_account_id}:log-group:/aws/lambda/${local.lambdaName}:*"]
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
            "fsx:UpdateFileSystem",
            "fsx:UpdateStorageVirtualMachine"
        ]
        resources = [
            aws_secretsmanager_secret.secret.arn,
            "arn:aws:fsx:${var.fsx_region}:${var.aws_account_id}:storage-virtual-machine/*/${var.svm_id}",
            "arn:aws:fsx:${var.fsx_region}:${var.aws_account_id}:file-system/${var.fsx_id}"
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
# Create the IAM role for the Lambda function.
resource "aws_iam_role" "role_for_lambda" {
  name               = "rotate_fsxn_secret_role_${random_id.id.hex}"
  description        = "IAM role for the Rotate FSxN Secret Lambda function."
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
#
# Create the policy based on the policy document.
resource "aws_iam_role_policy" "lambda_permissions" {
  name   = "rotate_fsxn_secret_policy_${random_id.id.hex}"
  role   = aws_iam_role.role_for_lambda.name
  policy = data.aws_iam_policy_document.lambda_permissions.json
}
#
# Create the archive file for the Lambda function.
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/fsxn_rotate_secret.py"
  output_path = "fsxn_rotate_secret.zip"
}
#
# Create the Lambda function.
resource "aws_lambda_function" "rotateLambdaFunction" {
  provider         = aws.secrets_provider
  function_name    = local.lambdaName
  description      = var.svm_id != "" ? "Lambda function to rotate the secret for SVM (${var.svm_id})." : "Lambda function to rotate the secret for FSxN File System (${var.fsx_id})."
  role             = aws_iam_role.role_for_lambda.arn
  runtime          = "python3.12"
  handler          = "fsxn_rotate_secret.lambda_handler"
  filename         = "fsxn_rotate_secret.zip"
  timeout          = 10
  source_code_hash = data.archive_file.lambda.output_base64sha256
}
#
# Allow Secrets Manager to invoke the Lambda function.
resource "aws_lambda_permission" "allowSecretsManager" {
  provider      = aws.secrets_provider
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotateLambdaFunction.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.secret.arn
}
#
# Create the secret with the required tags.
resource "aws_secretsmanager_secret" "secret" {
  provider     = aws.secrets_provider
  name         = "${var.secret_name_prefix}-${random_id.id.hex}"
  description  = var.svm_id != "" ? "Secret for the storage virtual machine (${var.svm_id})." : "Secret for the FSxN file system (${var.fsx_id})."

  tags = {
    fsx_id  = var.fsx_id
    region = var.fsx_region
    svm_id  = var.svm_id
  }
}
#
# Add the rotation Lambda function and rule to the secret.
resource "aws_secretsmanager_secret_rotation" "secretRotation" {
  provider            = aws.secrets_provider
  secret_id           = aws_secretsmanager_secret.secret.id
  rotation_lambda_arn = aws_lambda_function.rotateLambdaFunction.arn

  rotation_rules {
    schedule_expression = var.rotation_frequency
  }
}
