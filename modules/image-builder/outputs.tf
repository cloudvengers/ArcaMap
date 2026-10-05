output "pipeline" {
  description = "수동 빌드 파이프라인과 AMI 7일 정리 정책. 시작 요청에 build_tags를, AVAILABLE/DB 테스트 완료 확인 후 validation_tags를 image 리소스에 적용합니다."
  value = {
    arn                  = aws_imagebuilder_image_pipeline.api.arn
    recipe_arn           = aws_imagebuilder_image_recipe.api.arn
    lifecycle_policy_arn = aws_imagebuilder_lifecycle_policy.api.arn
    build_tags = {
      ArcaMapProtected         = "true"
      ArcaMapEnvironmentSha256 = sha256(base64decode(var.api_installation.environment_base64))
    }
    validation_tags = { ArcaMapValidated = "true" }
  }
}
