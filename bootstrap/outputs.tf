output "s3_bucket_name" {
  value       = aws_s3_bucket.tfstate.bucket
  description = "S3 bucket used for Terraform remote backend"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.tflock.name
  description = "DynamoDB table used for Terraform state locking"
}