output "secret_arn" {
  description = "The ARN of the secret that was created."
  value = aws_secretsmanager_secret.secret.arn
}

output "secret_name" {
  description = "The name of the secret that was created."
  value = aws_secretsmanager_secret.secret.name
}

output "lambda_arn" {
  description = "The ARN of the Lambda function that was created."
  value = aws_lambda_function.rotateLambdaFunction.arn
}

output "lambda_name" {
  description = "The name of the Lambda function that was created."
  value = aws_lambda_function.rotateLambdaFunction.function_name
}

output "role_arn" {
  description = "The ARN of the role that was created that allows the Lambda function to rotate the secret."
  value = aws_iam_role.role_for_lambda.arn
}

output "role_name" {
  description = "The name of the role that was created that allows the Lambda function to rotate the secret."
  value = aws_iam_role.role_for_lambda.name
}
