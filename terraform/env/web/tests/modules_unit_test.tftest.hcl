mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }

  mock_data "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "aws_s3_bucket" {
    defaults = {
      id                          = "protomaps-565725315772-ap-northeast-2-an"
      arn                         = "arn:aws:s3:::protomaps-565725315772-ap-northeast-2-an"
      bucket_regional_domain_name = "protomaps-565725315772-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      id                          = "arcamap-unit-bucket"
      arn                         = "arn:aws:s3:::arcamap-unit-bucket"
      bucket_regional_domain_name = "arcamap-unit-bucket.s3.ap-northeast-2.amazonaws.com"
    }
  }

  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn = "arn:aws:cloudfront::123456789012:distribution/TESTDISTRIBUTION"
    }
  }

  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/unit/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:aws-waf-logs-unit"
    }
  }
}

mock_provider "aws" {
  alias           = "dns"
  override_during = plan
}

variables {
  frontend_domain_name            = "www.example.com"
  frontend_cache_ttl_seconds      = 300
  media_cache_ttl_seconds         = 86400
  cloudfront_price_class          = "PriceClass_200"
  log_retention_days              = 30
  photo_noncurrent_retention_days = 30
  route53_role_arn                = "arn:aws:iam::210987654321:role/Route53"
  route53_zone_id                 = "ZDNS123456789"

  # 공통 모듈을 직접 실행하는 테스트의 가상 입력입니다.
  account_id      = "123456789012"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  logs_bucket = {
    id  = "arcamap-unit-logs"
    arn = "arn:aws:s3:::arcamap-unit-logs"
  }
  origin_buckets = {
    static = {
      id                          = "arcamap-unit-static"
      arn                         = "arn:aws:s3:::arcamap-unit-static"
      bucket_regional_domain_name = "arcamap-unit-static.s3.ap-northeast-2.amazonaws.com"
    }
    photos = {
      id                          = "arcamap-unit-photos"
      arn                         = "arn:aws:s3:::arcamap-unit-photos"
      bucket_regional_domain_name = "arcamap-unit-photos.s3.ap-northeast-2.amazonaws.com"
    }
    maps = {
      id                          = "protomaps-565725315772-ap-northeast-2-an"
      arn                         = "arn:aws:s3:::protomaps-565725315772-ap-northeast-2-an"
      bucket_regional_domain_name = "protomaps-565725315772-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"
    }
  }
  bucket_prefix = "arcamap-unit-"
}

run "web_existing_bucket_lookup" {
  command = plan

  override_resource {
    target = module.cloudfront.aws_wafv2_web_acl.site
    values = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/unit/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.cloudfront.aws_cloudwatch_log_group.waf
    values = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:aws-waf-logs-unit"
    }
  }

  override_resource {
    target = module.cloudfront.aws_wafv2_web_acl_logging_configuration.site
  }

  assert {
    condition = (
      data.aws_s3_bucket.maps.bucket == "protomaps-565725315772-ap-northeast-2-an" &&
      toset(keys(module.buckets)) == toset(["static", "photos", "cloudfront_logs"]) &&
      output.frontend_url == "https://www.example.com"
    )
    error_message = "web은 신규 버킷 3개를 소유하고 지도 버킷은 기존 버킷을 조회해야 합니다."
  }

  assert {
    condition = (
      toset(keys(aws_route53_record.frontend)) == toset(["A", "AAAA"]) &&
      alltrue([for record in aws_route53_record.frontend :
        record.zone_id == var.route53_zone_id &&
        record.name == var.frontend_domain_name &&
        !record.allow_overwrite &&
        one(record.alias).name == module.cloudfront.cloudfront.domain_name &&
        one(record.alias).zone_id == module.cloudfront.cloudfront.hosted_zone_id &&
        !one(record.alias).evaluate_target_health
      ])
    )
    error_message = "웹은 기존 DNS 영역에 CloudFront를 가리키는 A·AAAA 별칭을 생성하고 기존 레코드를 덮어쓰지 않아야 합니다."
  }
}

run "existing_map_origin" {
  command = plan

  module {
    source = "../../modules/cloudfront"
  }

  assert {
    condition = one([
      for origin in aws_cloudfront_distribution.site.origin : origin.domain_name
      if origin.origin_id == "maps"
    ]) == "protomaps-565725315772-ap-northeast-2-an.s3.ap-northeast-2.amazonaws.com"
    error_message = "지도 오리진은 기존 지도 S3의 리전별 REST 엔드포인트여야 합니다."
  }

  assert {
    condition = one([
      for behavior in aws_cloudfront_distribution.site.ordered_cache_behavior :
      behavior.target_origin_id == "maps" && !behavior.compress
      if behavior.path_pattern == "/20260907.pmtiles"
    ]) == true
    error_message = "최상위 PMTiles 경로는 압축 없이 지도 오리진으로 전달해야 합니다."
  }

  assert {
    condition = (
      aws_s3_bucket_policy.origin["maps"].bucket == "protomaps-565725315772-ap-northeast-2-an" &&
      jsondecode(aws_s3_bucket_policy.origin["maps"].policy).Statement[0].Resource == "arn:aws:s3:::protomaps-565725315772-ap-northeast-2-an/20260907.pmtiles" &&
      jsondecode(aws_s3_bucket_policy.origin["maps"].policy).Statement[0].Principal.Service == "cloudfront.amazonaws.com" &&
      jsondecode(aws_s3_bucket_policy.origin["maps"].policy).Statement[0].Action == "s3:GetObject" &&
      jsondecode(aws_s3_bucket_policy.origin["maps"].policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.site.arn
    )
    error_message = "지도 읽기 정책은 지정 PMTiles 객체와 해당 CloudFront 배포로 제한해야 합니다."
  }
}

run "waf_preservation" {
  command = plan

  module {
    source = "../../modules/cloudfront"
  }

  assert {
    condition = (
      aws_cloudfront_distribution.site.web_acl_id == aws_wafv2_web_acl.site.arn &&
      aws_wafv2_web_acl.site.scope == "CLOUDFRONT" &&
      aws_wafv2_web_acl.site.region == "us-east-1" &&
      length(one(aws_wafv2_web_acl.site.default_action).allow) == 1 &&
      length(aws_wafv2_web_acl.site.rule) == 4 &&
      alltrue([for rule in aws_wafv2_web_acl.site.rule : length(one(rule.override_action).count) == 1]) &&
      aws_cloudwatch_log_group.waf.retention_in_days == 14 &&
      aws_wafv2_web_acl_logging_configuration.site.resource_arn == aws_wafv2_web_acl.site.arn &&
      aws_wafv2_web_acl_logging_configuration.site.log_destination_configs == toset(["${aws_cloudwatch_log_group.waf.arn}:*"]) &&
      toset([for field in aws_wafv2_web_acl_logging_configuration.site.redacted_fields : one(field.single_header).name]) == toset(["authorization", "cookie", "proxy-authorization"])
    )
    error_message = "기존 WAF 연결, 규칙 4개의 Count 모드, 14일 로그 보존 및 민감한 헤더 가림 설정을 유지해야 합니다."
  }
}

run "static_bucket_protection" {
  command = plan

  module {
    source = "../../modules/s3-bucket"
  }

  assert {
    condition = (
      !aws_s3_bucket.main.force_destroy &&
      aws_s3_bucket_public_access_block.main.block_public_acls &&
      aws_s3_bucket_public_access_block.main.block_public_policy &&
      one(aws_s3_bucket_ownership_controls.main.rule).object_ownership == "BucketOwnerEnforced" &&
      one(one(aws_s3_bucket_server_side_encryption_configuration.main.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
      length(aws_s3_bucket_versioning.main) == 0 &&
      length(aws_s3_bucket_lifecycle_configuration.main) == 0
    )
    error_message = "버킷 공개 차단·소유권 강제·암호화·삭제 보호를 유지하고 정적 버킷에 수명 주기를 추가하면 안 됩니다."
  }
}

run "photo_version_retention" {
  command = plan

  module {
    source = "../../modules/s3-bucket"
  }

  variables {
    noncurrent_retention_days = 30
  }

  assert {
    condition = (
      length(aws_s3_bucket_versioning.main) == 1 &&
      one(aws_s3_bucket_versioning.main[0].versioning_configuration).status == "Enabled" &&
      one(one(aws_s3_bucket_lifecycle_configuration.main[0].rule).noncurrent_version_expiration).noncurrent_days == 30 &&
      one(one(aws_s3_bucket_lifecycle_configuration.main[0].rule).expiration).expired_object_delete_marker
    )
    error_message = "사진 버킷은 버전 관리, 이전 버전 보존 및 삭제 마커 정리를 유지해야 합니다."
  }
}

run "log_expiration" {
  command = plan

  module {
    source = "../../modules/s3-bucket"
  }

  variables {
    expiration_days = 30
  }

  assert {
    condition = (
      length(aws_s3_bucket_versioning.main) == 0 &&
      one(aws_s3_bucket_lifecycle_configuration.main[0].rule).id == "expire-cloudfront-logs" &&
      one(one(aws_s3_bucket_lifecycle_configuration.main[0].rule).expiration).days == 30
    )
    error_message = "CloudFront 로그 버킷은 현재 객체를 보존 기간 후 만료시켜야 합니다."
  }
}
