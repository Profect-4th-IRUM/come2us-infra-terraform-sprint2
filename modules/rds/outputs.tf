output "rds_primary" {
  value = {
    address = aws_db_instance.come2us_rds.address
    port    = aws_db_instance.come2us_rds.port
  }
}

output "rds_replica" {
  value = {
    address = aws_db_instance.come2us_rds_replica.address
    port    = aws_db_instance.come2us_rds_replica.port
  }
}
