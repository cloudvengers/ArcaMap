output "alb" {
  description = "ALB DNS 연결·ASG 연결·경보 차원에 사용할 식별 정보."
  value = {
    arn                     = aws_lb.api.arn
    arn_suffix              = aws_lb.api.arn_suffix
    dns_name                = aws_lb.api.dns_name
    zone_id                 = aws_lb.api.zone_id
    target_group_arn        = aws_lb_target_group.api.arn
    target_group_arn_suffix = aws_lb_target_group.api.arn_suffix
  }

  # ASG가 대상 그룹을 사용하기 전에 HTTPS 리스너의 전달 연결이 완료되어야 합니다.
  depends_on = [aws_lb_listener.api_https]
}
