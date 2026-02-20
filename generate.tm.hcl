# Generate backend config in all stacks (except tfstate-backend which bootstraps itself)
# Uses S3 backend for remote state (required for CI/CD)
generate_hcl "_terramate_generated_backend.tf" {
  condition = terramate.stack.id != "b2c3d4e5-f6a7-8901-bcde-f23456789012"

  content {
    terraform {
      backend "s3" {
        bucket = global.tfstate_bucket
        key            = "stacks/${terramate.stack.id}/terraform.tfstate"
        region         = global.aws_region
        dynamodb_table = "${global.tfstate_bucket}-lock"
      }
    }
  }
}
