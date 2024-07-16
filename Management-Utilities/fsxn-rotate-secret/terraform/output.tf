output "secret-ARN" {
  description = "The ARN of the secret that was created."
  value = aws_secretsmanager_secret.secret.arn
}

output "Rotate-Secret-Lamnda-Function-ARN" {
  description = "The ARN of the Lambda function that was created."
  value = aws_lambda_function.rotateLambdaFunction.arn
}

output "Rotate-Secret-Lamnda-Function-Name" {
  description = "The name of the Lambda function that was created."
  value = local.lambdaName
}
