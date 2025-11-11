output "rds_primary" {
  value = {
    endpoint = aws_db_instance.come2us_rds.endpoint
    port     = aws_db_instance.come2us_rds.port
  }
}

output "rds_replica" {
  value = {
    endpoint = aws_db_instance.come2us_rds_replica.endpoint
    port     = aws_db_instance.come2us_rds_replica.port
  }
}
