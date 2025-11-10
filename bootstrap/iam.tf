data "aws_caller_identity" "current" {}

resource "aws_iam_user" "terraform_access" {
  name = "terraform-access"

  tags = {
    Name        = "terraform-access"
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_access_key" "terraform_access_key" {
  user = aws_iam_user.terraform_access.name
}

resource "aws_iam_role" "terraform_access_role" {
  name = "terraform-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_user.terraform_access.arn
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "terraform-access-role"
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}

locals {
  policy_json = templatefile("${path.module}/policy/terraform_infra_policy.json", {
    bucket_name = "${local.project}-${local.env}-tfstate"
    table_name  = "${local.project}-${local.env}-tflock"
    region      = local.region
    account_id  = data.aws_caller_identity.current.account_id
  })
}

resource "aws_iam_policy" "terraform_infra_policy" {
  name        = "terraform-infra-policy"
  description = "Terraform-managed infrastructure access policy"
  policy      = local.policy_json
}

resource "aws_iam_role_policy_attachment" "terraform_role_attach" {
  role       = aws_iam_role.terraform_access_role.name
  policy_arn = aws_iam_policy.terraform_infra_policy.arn
}

resource "aws_iam_user_policy_attachment" "terraform_user_attach" {
  user       = aws_iam_user.terraform_access.name
  policy_arn = aws_iam_policy.terraform_infra_policy.arn
}

output "terraform_user_arn" {
  value       = aws_iam_user.terraform_access.arn
  description = "Terraform 전용 IAM User ARN"
}

output "terraform_user_access_key" {
  value       = aws_iam_access_key.terraform_access_key.id
  description = "Terraform User Access Key ID"
  sensitive   = true
}

output "terraform_user_secret_key" {
  value       = aws_iam_access_key.terraform_access_key.secret
  description = "Terraform User Secret Key"
  sensitive   = true
}

output "terraform_role_arn" {
  value       = aws_iam_role.terraform_access_role.arn
  description = "Terraform Role ARN"
}
