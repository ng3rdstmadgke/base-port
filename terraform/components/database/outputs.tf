output "db_host" {
  value = aws_db_instance.app_db.address
}

output "db_port" {
  value = aws_db_instance.app_db.port
}
