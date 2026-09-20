resource "aws_wafv2_web_acl_logging_configuration" "site" {
  log_destination_configs = ["${aws_cloudwatch_log_group.waf.arn}:*"]
  region                  = "us-east-1"
  resource_arn            = aws_wafv2_web_acl.site.arn
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
  redacted_fields {
    single_header {
      name = "proxy-authorization"
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  log_group_class   = "STANDARD"
  name              = "aws-waf-logs-CloudFrontDistribution-${aws_cloudfront_distribution.site.id}"
  region            = "us-east-1"
  retention_in_days = 14
}

resource "aws_wafv2_web_acl" "site" {
  name   = "CreatedByCloudFront-609132c8"
  region = "us-east-1"
  scope  = "CLOUDFRONT"
  default_action {
    allow {
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 1
    override_action {
      count {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesAntiDDoSRuleSet"
    priority = 0
    override_action {
      count {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAntiDDoSRuleSet"
        vendor_name = "AWS"
        managed_rule_group_configs {
          aws_managed_rules_anti_ddos_rule_set {
            sensitivity_to_block = "LOW"
            client_side_action_config {
              challenge {
                sensitivity     = "HIGH"
                usage_of_action = "ENABLED"
                exempt_uri_regular_expression {
                  regex_string = "\\/api\\/|\\.(acc|avi|css|gif|ico|jpe?g|js|json|mp[34]|ogg|otf|pdf|png|tiff?|ttf|webm|webp|woff2?|xml)$"
                }
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAntiDDoSRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 2
    override_action {
      count {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    override_action {
      count {
      }
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CreatedByCloudFront-609132c8"
    sampled_requests_enabled   = true
  }
}
