
resource "aws_s3_bucket" "lake" {
  bucket        = "fleet-lake-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration { days = 7 }
  }
}

resource "aws_dynamodb_table" "state" {
  name           = "vehicle_state"
  billing_mode   = "PROVISIONED" # always-free covers 25 RCU/WCU
  read_capacity  = 5
  write_capacity = 20
  hash_key       = "vehicle_id"
  attribute {
    name = "vehicle_id"
    type = "S"
  }
}