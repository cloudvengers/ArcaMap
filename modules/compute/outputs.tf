output "autoscaling_group" {                   # autoscaling_group 정보를 호출자에게 반환
  description = "API Auto Scaling 그룹 이름과 ARN." # 반환하는 값의 의미
  value = {                                    # 호출자에게 전달할 값
    name = aws_autoscaling_group.api.name      # 호출자에게 전달할 리소스 이름
    arn  = aws_autoscaling_group.api.arn       # 리소스 ARN
  }                                            # 설정 묶음 끝
}                                              # 설정 묶음 끝

output "launch_template" {                           # launch_template 정보를 호출자에게 반환
  description = "API 시작 템플릿 ID와 최신 버전 및 연결한 AMI ID." # 반환하는 값의 의미
  value = {                                          # 호출자에게 전달할 값
    id      = aws_launch_template.api.id             # 호출자에게 전달할 리소스 ID
    version = aws_launch_template.api.latest_version # Image Builder 구성요소·레시피 버전
    ami_id  = aws_launch_template.api.image_id       # 시작 템플릿의 AMI ID
  }                                                  # 설정 묶음 끝
}                                                    # 설정 묶음 끝
