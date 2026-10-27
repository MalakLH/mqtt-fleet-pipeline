
resource "aws_iam_role" "lambda" {
  name = "fleet-consumer-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy" "lambda" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.state.arn },
      { Effect = "Allow", Action = ["s3:PutObject", "s3:GetObject"], Resource = "${aws_s3_bucket.lake.arn}/curated/*" },
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.lake.arn }
    ]
  })
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/consumer"
  output_path = "${path.module}/consumer.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/fleet-consumer"
  retention_in_days = 3
}

resource "aws_lambda_function" "consumer" {
  function_name    = "fleet-consumer"
  runtime          = "python3.12"
  handler          = "handler.handler"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.consumer.output_path
  source_code_hash = data.archive_file.consumer.output_base64sha256
  timeout          = 30
  memory_size      = 512
  layers           = [var.pandas_layer_arn]
  environment {
    variables = {
      TABLE  = aws_dynamodb_table.state.name
      BUCKET = aws_s3_bucket.lake.bucket
    }
  }
  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn                   = aws_sqs_queue.ingest.arn
  function_name                      = aws_lambda_function.consumer.arn
  batch_size                         = 100
  maximum_batching_window_in_seconds = 10
  function_response_types            = ["ReportBatchItemFailures"]
  scaling_config { maximum_concurrency = 2 } # protects DynamoDB write capacity
}