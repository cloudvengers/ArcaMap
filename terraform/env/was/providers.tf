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
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "dns"
  region = "ap-northeast-2"

  assume_role {
    role_arn = var.route53_role_arn
  }
}
