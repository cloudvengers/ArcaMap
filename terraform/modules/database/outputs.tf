output "database" {
  description = "RDS 식별자와 DB 호스트 주소·포트·DB 이름."
  value = {
    identifier = aws_db_instance.postgres.identifier
    address    = aws_db_instance.postgres.address
    port       = aws_db_instance.postgres.port
    name       = aws_db_instance.postgres.db_name
  }
}
