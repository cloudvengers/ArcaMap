data "aws_vpc" "main" {
  tags = { Name = "arcamap-vpc" }
}

data "aws_subnet" "public" {
  for_each = toset(["ap-northeast-2a", "ap-northeast-2c"])

  vpc_id            = data.aws_vpc.main.id
  availability_zone = each.key
  tags              = { Name = "arcamap-public-${each.key}" }
}

data "aws_subnet" "api" {
  vpc_id            = data.aws_vpc.main.id
  availability_zone = "ap-northeast-2a"
  tags              = { Name = "arcamap-api-ap-northeast-2a" }

  lifecycle {
    postcondition {
      condition     = !self.map_public_ip_on_launch
      error_message = "API와 빌드 서브넷에는 공인 IP 자동 할당을 허용하지 않습니다."
    }
  }
}

data "aws_security_group" "alb" {
  name   = "arcamap-alb"
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "api" {
  name   = "arcamap-api"
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "image_builder" {
  name   = "arcamap-imagebuilder"
  vpc_id = data.aws_vpc.main.id
}

# 완전한 build ARN을 선택합니다. 최신 이미지나 ASG 참조를 자동 판단하지 않습니다.
data "aws_imagebuilder_image" "api" {
  count = var.api_image == null ? 0 : 1
  arn   = var.api_image

  lifecycle {
    postcondition {
      condition = (
        lookup(self.tags, "ArcaMapProtected", "") == "true" &&
        lookup(self.tags, "ArcaMapValidated", "") == "true" &&
        lookup(self.tags, "ArcaMapEnvironmentSha256", "") == sha256(local.api_environment) &&
        one(self.image_tests_configuration).image_tests_enabled
      )
      error_message = "선택 image에는 Protected=true·AVAILABLE/DB 테스트 완료 확인 후 Validated=true·현재 DSQL 환경 SHA256 태그가 필요합니다."
    }
  }
}

data "aws_ami" "api" {
  count  = var.api_image == null ? 0 : 1
  owners = ["self"]

  filter {
    name = "image-id"
    values = [one([
      for ami in one(data.aws_imagebuilder_image.api[0].output_resources).amis : ami.image
      if ami.region == "ap-northeast-2"
    ])]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
