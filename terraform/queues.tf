
resource "aws_sqs_queue" "dlq" { name = "fleet-dlq" }

resource "aws_sqs_queue" "ingest" {
  name                       = "fleet-ingest"
  visibility_timeout_seconds = 180 # >= 6x Lambda timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}