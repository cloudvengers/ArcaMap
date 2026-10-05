resource "aws_iam_role" "ec2" {                # EC2 IAM 역할 정의
  for_each = {                                 # 대상 항목별로 블록 반복
    api           = "arcamap-api-ec2"          # API 항목 설정
    image_builder = "arcamap-imagebuilder-ec2" # 이미지 빌드 EC2 항목 설정
  }                                            # 설정 묶음 끝

  name = each.value                                 # AWS 리소스·규칙·작업 이름
  assume_role_policy = jsonencode({                 # EC2가 이 IAM 역할을 맡도록 하는 신뢰 정책
    Version = "2012-10-17"                          # IAM 정책 문서 버전
    Statement = [{                                  # IAM 정책의 권한 문장 목록
      Effect    = "Allow"                           # 권한 허용 또는 거부 동작
      Action    = "sts:AssumeRole"                  # 허용하거나 거부할 AWS 작업
      Principal = { Service = "ec2.amazonaws.com" } # 이 정책을 적용할 접근 주체
    }]                                              # 설정 묶음 끝
  })                                                # 설정 묶음 끝
}                                                   # 설정 묶음 끝

resource "aws_iam_role_policy_attachment" "ssm" { # IAM 관리형 정책 연결 정의
  for_each = aws_iam_role.ec2                     # 대상 항목별로 블록 반복

  role       = each.value.name                                        # 정책·프로파일에 연결할 IAM 역할 이름
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # 연결할 AWS 관리형 정책 ARN
}                                                                     # 설정 묶음 끝

resource "aws_iam_role_policy_attachment" "cloudwatch" { # IAM 관리형 정책 연결 정의
  for_each = aws_iam_role.ec2                            # 대상 항목별로 블록 반복

  role       = each.value.name                                       # 정책·프로파일에 연결할 IAM 역할 이름
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" # 연결할 AWS 관리형 정책 ARN
}                                                                    # 설정 묶음 끝

resource "aws_iam_role_policy_attachment" "image_builder" {                # IAM 관리형 정책 연결 정의
  role       = aws_iam_role.ec2["image_builder"].name                      # 정책·프로파일에 연결할 IAM 역할 이름
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder" # 연결할 AWS 관리형 정책 ARN
}                                                                          # 설정 묶음 끝

resource "aws_iam_role_policy" "imagebuilder_log_test" {              # IAM 인라인 정책 정의
  name = "arcamap-imagebuilder-log-test"                              # AWS 리소스·규칙·작업 이름
  role = aws_iam_role.ec2["image_builder"].name                       # 정책·프로파일에 연결할 IAM 역할 이름
  policy = jsonencode({                                               # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                                            # IAM 정책 문서 버전
    Statement = [{                                                    # IAM 정책의 권한 문장 목록
      Effect   = "Allow"                                              # 권한 허용 또는 거부 동작
      Action   = "logs:FilterLogEvents"                               # 허용하거나 거부할 AWS 작업
      Resource = "${module.log_groups["ec2_system"].log_group.arn}:*" # 권한을 적용할 리소스 ARN
    }]                                                                # 설정 묶음 끝
  })                                                                  # 설정 묶음 끝
}                                                                     # 설정 묶음 끝

resource "aws_iam_instance_profile" "ec2" {                 # EC2 인스턴스 프로파일 정의
  for_each = {                                              # 대상 항목별로 블록 반복
    api           = var.ec2_instance_profile_name           # API 항목 설정
    image_builder = var.image_builder_instance_profile_name # 이미지 빌드 EC2 항목 설정
  }                                                         # 설정 묶음 끝

  name = each.value                      # AWS 리소스·규칙·작업 이름
  role = aws_iam_role.ec2[each.key].name # 정책·프로파일에 연결할 IAM 역할 이름

  # 프로파일을 사용하는 이미지 빌드·EC2 시작 전에 권한 연결을 완료합니다.
  depends_on = [                                  # 참조만으로 표현되지 않는 선행 작업 지정
    aws_iam_role_policy_attachment.ssm,           # EC2 프로파일 사용 전에 완료할 권한 연결
    aws_iam_role_policy_attachment.cloudwatch,    # EC2 프로파일 사용 전에 완료할 권한 연결
    aws_iam_role_policy_attachment.image_builder, # EC2 프로파일 사용 전에 완료할 권한 연결
    aws_iam_role_policy.imagebuilder_log_test,    # EC2 프로파일 사용 전에 완료할 권한 연결
    aws_iam_role_policy.dsql,                     # EC2 프로파일 사용 전에 완료할 DSQL 연결 권한
    aws_iam_role_policy.imagebuilder_artifact,    # EC2 프로파일 사용 전에 완료할 권한 연결
  ]                                               # 설정 묶음 끝
}                                                 # 설정 묶음 끝

resource "aws_iam_role_policy" "dsql" { # IAM 인라인 정책 정의
  for_each = aws_iam_role.ec2           # 대상 항목별로 블록 반복

  name = "arcamap-dsql-connect"           # AWS 리소스·규칙·작업 이름
  role = each.value.name                  # 정책·프로파일에 연결할 IAM 역할 이름
  policy = jsonencode({                   # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                # IAM 정책 문서 버전
    Statement = [{                        # IAM 정책의 권한 문장 목록
      Effect   = "Allow"                  # 권한 허용 또는 거부 동작
      Action   = "dsql:DbConnect"         # 허용하거나 거부할 AWS 작업
      Resource = var.database.cluster_arn # 권한을 적용할 리소스 ARN
    }]                                    # 설정 묶음 끝
  })                                      # 설정 묶음 끝
}                                         # 설정 묶음 끝

resource "aws_iam_role_policy" "imagebuilder_artifact" {
  count = var.enable_image_builder ? 1 : 0
  # IAM 인라인 정책 정의
  name = "arcamap-imagebuilder-artifact"                                            # AWS 리소스·규칙·작업 이름
  role = aws_iam_role.ec2["image_builder"].name                                     # 정책·프로파일에 연결할 IAM 역할 이름
  policy = jsonencode({                                                             # 접근 권한 정책을 JSON으로 변환
    Version = "2012-10-17"                                                          # IAM 정책 문서 버전
    Statement = [{                                                                  # IAM 정책의 권한 문장 목록
      Effect   = "Allow"                                                            # 권한 허용 또는 거부 동작
      Action   = "s3:GetObject"                                                     # 허용하거나 거부할 AWS 작업
      Resource = "${module.deployment_bucket.bucket.arn}/${local.api_artifact_key}" # 권한을 적용할 리소스 ARN
    }]                                                                              # 설정 묶음 끝
  })                                                                                # 설정 묶음 끝
}                                                                                   # 설정 묶음 끝
