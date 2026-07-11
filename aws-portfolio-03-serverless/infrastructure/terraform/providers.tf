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
