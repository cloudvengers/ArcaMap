terraform {
  required_version = "= 1.16.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.63.0"
    }
  }
}

provider "aws" {
  region              = "ap-northeast-2"
  allowed_account_ids = ["565725315772"]
}

data "aws_vpc" "main" {
  tags = { Name = "arcamap-vpc" }
}

data "aws_subnet" "api" {
  vpc_id            = data.aws_vpc.main.id
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "arcamap-api-ap-northeast-2a" }

  lifecycle {
    postcondition {
      condition     = !self.map_public_ip_on_launch
      error_message = "bootstrap은 공인 IP 자동 할당이 없는 사설 서브넷만 사용합니다."
    }
  }
}

data "aws_security_group" "bootstrap" {
  name   = "arcamap-imagebuilder"
  vpc_id = data.aws_vpc.main.id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_s3_object" "bundle" {
  bucket      = var.deployment_bucket
  key         = "bootstrap/${filesha256(var.bundle_path)}.tar.gz"
  source      = var.bundle_path
  source_hash = filesha256(var.bundle_path)
}

resource "aws_iam_role" "bootstrap" {
  name = "arcamap-bootstrap-ec2"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "database" {
  for_each = toset(["admin", "writer"])
  name     = "arcamap-bootstrap-${each.key}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { AWS = aws_iam_role.bootstrap.arn } }]
  })
}

resource "aws_iam_role_policy" "database" {
  for_each = aws_iam_role.database
  name     = "arcamap-bootstrap-dsql"
  role     = each.value.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = each.key == "admin" ? "dsql:DbConnectAdmin" : "dsql:DbConnect"
      Resource = var.cluster_arn
    }]
  })
}

resource "aws_iam_role_policy" "bootstrap" {
  name = "arcamap-bootstrap-execution"
  role = aws_iam_role.bootstrap.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "s3:GetObject", Resource = "arn:aws:s3:::${var.deployment_bucket}/${aws_s3_object.bundle.key}" },
      { Effect = "Allow", Action = "sts:AssumeRole", Resource = [for role in aws_iam_role.database : role.arn] }
    ]
  })
}

resource "aws_iam_instance_profile" "bootstrap" {
  name       = "arcamap-bootstrap-instance-profile"
  role       = aws_iam_role.bootstrap.name
  depends_on = [aws_iam_role_policy_attachment.ssm, aws_iam_role_policy.bootstrap, aws_iam_role_policy.database]
}

resource "aws_instance" "bootstrap" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = data.aws_subnet.api.id
  vpc_security_group_ids      = [data.aws_security_group.bootstrap.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.bootstrap.name
  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    bucket = aws_s3_object.bundle.bucket
    key    = aws_s3_object.bundle.key
    sha256 = filesha256(var.bundle_path)
  })

  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }
  tags = { Name = "arcamap-bootstrap", ArcaMapTemporary = "true" }
}

output "instance_id" {
  description = "승인된 SSM 명령을 실행하고 운영 검증 후 제거할 임시 EC2 ID."
  value       = aws_instance.bootstrap.id
}

output "database_roles" {
  description = "bootstrap 전용 admin/writer IAM role ARN. 운영 API에는 이 권한을 부여하지 않습니다."
  value       = { for name, role in aws_iam_role.database : name => role.arn }
}
