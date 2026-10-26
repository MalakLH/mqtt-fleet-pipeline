resource "aws_athena_workgroup" "wg" {
  name          = "fleet"
  force_destroy = true
  configuration {
    enforce_workgroup_configuration = true
    bytes_scanned_cutoff_per_query  = 104857600 # 100 MB
    result_configuration { output_location = "s3://${aws_s3_bucket.lake.bucket}/athena-results/" }
  }
}

