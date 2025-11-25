output "session_redis" {
  value = {
    primary_address = aws_elasticache_replication_group.come2us_session_redis.primary_endpoint_address
    reader_address  = aws_elasticache_replication_group.come2us_session_redis.reader_endpoint_address
    port            = aws_elasticache_replication_group.come2us_session_redis.port
  }
}

output "cache_redis" {
  value = {
    address = aws_elasticache_cluster.come2us_cache_redis.cache_nodes[0].address
    port    = aws_elasticache_cluster.come2us_cache_redis.cache_nodes[0].port
  }
}
