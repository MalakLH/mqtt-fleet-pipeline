variable "aws_region" {
  description = "AWS region for the fleet pipeline"
  type        = string
  default     = "eu-north-1"
}

variable "alert_email" {
  description = "Email address for pipeline alerts"
  type        = string
}

variable "vehicle_table_name" {
  description = "DynamoDB table for vehicle state"
  type        = string
  default     = "vehicle_state"
}

variable "pandas_layer_arn" {
  type = string
}
