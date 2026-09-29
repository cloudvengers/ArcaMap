moved {                               # 이전 인덱스 주소를 현재 주소로 연결
  from = aws_autoscaling_group.api[0] # 이동 전 Terraform 상태 주소
  to   = aws_autoscaling_group.api    # 이동 후 Terraform 상태 주소
}                                     # 설정 묶음 끝

moved {                                    # 이전 인덱스 주소를 현재 주소로 연결
  from = aws_autoscaling_policy.api_cpu[0] # 이동 전 Terraform 상태 주소
  to   = aws_autoscaling_policy.api_cpu    # 이동 후 Terraform 상태 주소
}                                          # 설정 묶음 끝

moved {                                       # 이전 인덱스 주소를 현재 주소로 연결
  from = aws_autoscaling_policy.api_memory[0] # 이동 전 Terraform 상태 주소
  to   = aws_autoscaling_policy.api_memory    # 이동 후 Terraform 상태 주소
}                                             # 설정 묶음 끝
