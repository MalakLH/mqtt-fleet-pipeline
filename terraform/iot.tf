
resource "aws_iot_thing" "sim" { name = "fleet-simulator" }

resource "aws_iot_certificate" "cert" { active = true }

resource "aws_iot_policy" "sim" {
  name = "fleet-simulator-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "iot:Connect", Resource = "arn:aws:iot:*:*:client/fleet-simulator" },
      { Effect = "Allow", Action = "iot:Publish", Resource = "arn:aws:iot:*:*:topic/fleet/*/telemetry" }
    ]
  })
}

resource "aws_iot_policy_attachment" "att" {
  policy = aws_iot_policy.sim.name
  target = aws_iot_certificate.cert.arn
}

resource "aws_iot_thing_principal_attachment" "tp" {
  thing     = aws_iot_thing.sim.name
  principal = aws_iot_certificate.cert.arn
}

resource "aws_iam_role" "iot_rule" {
  name = "iot-rule-to-sqs"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "iot.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy" "iot_rule" {
  role = aws_iam_role.iot_rule.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sqs:SendMessage", Resource = aws_sqs_queue.ingest.arn }]
  })
}

resource "aws_iot_topic_rule" "telemetry" {
  name        = "fleet_telemetry"
  enabled     = true
  sql         = "SELECT *, topic(2) AS vehicle_id, timestamp() AS ingest_ts FROM 'fleet/+/telemetry'"
  sql_version = "2016-03-23"
  sqs {
    queue_url  = aws_sqs_queue.ingest.id
    role_arn   = aws_iam_role.iot_rule.arn
    use_base64 = false
  }
}

data "aws_iot_endpoint" "e" { endpoint_type = "iot:Data-ATS" }