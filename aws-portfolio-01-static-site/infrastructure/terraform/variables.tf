variable "bucket_name" {
  description = "S3 bucket name for static website hosting"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}
