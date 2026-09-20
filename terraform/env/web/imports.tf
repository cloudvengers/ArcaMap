# 콘솔에서 생성한 CloudFront WAF와 로그 리소스의 가져오기 이력입니다.
# 기본 제공자 리전이 서울이므로 가져오기 ID에 us-east-1을 명시합니다.
import {
  to = module.cloudfront.aws_wafv2_web_acl.site
  id = "e41dd9fc-b545-4b89-be77-8187f556c9e8/CreatedByCloudFront-609132c8/CLOUDFRONT@us-east-1"
}

import {
  to = module.cloudfront.aws_cloudwatch_log_group.waf
  id = "aws-waf-logs-CloudFrontDistribution-E39UQTOCMBVZB3@us-east-1"
}

import {
  to = module.cloudfront.aws_wafv2_web_acl_logging_configuration.site
  id = "arn:aws:wafv2:us-east-1:565725315772:global/webacl/CreatedByCloudFront-609132c8/e41dd9fc-b545-4b89-be77-8187f556c9e8@us-east-1"
}
