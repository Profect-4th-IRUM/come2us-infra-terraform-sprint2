locals {
  project = var.project_name
  env     = var.environment
  region  = var.region
}

# S3 Bucket
resource "aws_s3_bucket" "tfstate" {
  bucket = "${local.project}-${local.env}-tfstate"

  tags = {
    Name        = "${local.project}-${local.env}-tfstate"
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  s3_policy_json = templatefile("${path.module}/policy/s3_tfstate_policy.json", {
    bucket_name        = "${local.project}-${local.env}-tfstate"
    terraform_role_arn = aws_iam_role.terraform_access_role.arn
    terraform_user_arn = aws_iam_user.terraform_access.arn
  })
}

resource "aws_s3_bucket_policy" "tfstate_policy" {
  bucket = aws_s3_bucket.tfstate.id
  policy = local.s3_policy_json
}

# DynamoDB Table
resource "aws_dynamodb_table" "tflock" {
  name         = "${local.project}-${local.env}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${local.project}-${local.env}-tflock"
    Environment = local.env
    ManagedBy   = "Terraform"
  }
}