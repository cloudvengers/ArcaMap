output "alb" {                                                   # alb 정보를 호출자에게 반환
  description = "ALB DNS 연결·ASG 연결·경보 차원에 사용할 식별 정보."            # 반환하는 값의 의미
  value = {                                                      # 호출자에게 전달할 값
    arn                     = aws_lb.api.arn                     # 리소스 ARN
    arn_suffix              = aws_lb.api.arn_suffix              # CloudWatch 지표 차원에 사용할 ARN 접미사
    dns_name                = aws_lb.api.dns_name                # 로드 밸런서의 DNS 이름
    zone_id                 = aws_lb.api.zone_id                 # DNS 레코드를 만들 호스팅 영역 ID
    target_group_arn        = aws_lb_target_group.api.arn        # API 요청을 전달할 대상 그룹 ARN
    target_group_arn_suffix = aws_lb_target_group.api.arn_suffix # 대상 그룹 지표 차원의 ARN 접미사
  }                                                              # 설정 묶음 끝

  # ASG가 대상 그룹을 사용하기 전에 HTTPS 리스너의 전달 연결이 완료되어야 합니다.
  depends_on = [aws_lb_listener.api_https] # 참조만으로 표현되지 않는 선행 작업 지정
}                                          # 설정 묶음 끝
