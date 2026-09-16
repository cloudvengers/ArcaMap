output "autoscaling_group" {
  description = "API Auto Scaling 그룹 이름과 ARN."
  value = one([for group in aws_autoscaling_group.api : {
    name = group.name
    arn  = group.arn
  }])
}

output "launch_template" {
  description = "API 시작 템플릿 ID와 최신 버전 및 연결한 AMI ID."
  value = {
    id      = aws_launch_template.api.id
    version = aws_launch_template.api.latest_version
    ami_id  = aws_launch_template.api.image_id
  }
}
