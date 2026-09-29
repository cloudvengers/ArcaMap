output "database" {                                  # database 정보를 호출자에게 반환
  description = "RDS 식별자와 DB 호스트 주소·포트·DB 이름."       # 반환하는 값의 의미
  value = {                                          # 호출자에게 전달할 값
    identifier = aws_db_instance.postgres.identifier # RDS 인스턴스 식별자
    address    = aws_db_instance.postgres.address    # DB 접속 주소
    port       = aws_db_instance.postgres.port       # 연결을 받을 포트
    name       = aws_db_instance.postgres.db_name    # 호출자에게 전달할 리소스 이름
  }                                                  # 설정 묶음 끝
}                                                    # 설정 묶음 끝
