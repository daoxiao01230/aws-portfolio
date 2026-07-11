terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
      # archive プロバイダ: Lambda関数コードをzip化するために使用
      # 理由: aws_lambda_function は zip ファイルのアップロードを要求するため、
      #       Terraform apply時にPythonコードを自動でzip化する
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# CloudFrontで使うACM証明書はus-east-1でのみ発行可能という制約への対応
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
