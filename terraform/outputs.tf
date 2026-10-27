
output "iot_endpoint" { value = data.aws_iot_endpoint.e.endpoint_address }

output "cert_pem" {
  value     = aws_iot_certificate.cert.certificate_pem
  sensitive = true
}

output "private_key" {
  value     = aws_iot_certificate.cert.private_key
  sensitive = true
}

output "bucket" { value = aws_s3_bucket.lake.bucket }