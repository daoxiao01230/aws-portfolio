variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "プロジェクト識別子。リソース名のプレフィックスとして使用"
  type        = string
  default     = "aws-portfolio-03-serverless"
}

variable "github_actions_iam_user_name" {
  description = "Phase 1で作成済みのGitHub Actions用IAMユーザー名。新規作成せず既存ユーザーに権限を追加する"
  type        = string
  default     = "github-actions-portfolio-01"
}
