terraform {
  required_version = ">= 1.6.0"

  # This stack uses local state — it bootstraps the remote backend
  backend "local" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_profile" {
  description = "AWS credentials profile name"
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "matz-infra-tfstate"
}

variable "project_name" {
  description = "Project name prefix for IAM resources"
  type        = string
  default     = "matz-infra"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

# --- S3 State Bucket ---

resource "aws_s3_bucket" "tfstate" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- IAM User for Tofu (CI + local) ---
# Single user with Route53 + S3 state permissions

resource "aws_iam_user" "tofu" {
  name = "${var.project_name}-tofu"
}

resource "aws_iam_user_policy" "tofu" {
  name = "${var.project_name}-tofu-policy"
  user = aws_iam_user.tofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Route53"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListHostedZones",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets",
        ]
        Resource = "*"
      },
      {
        Sid      = "S3StateBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Sid    = "S3StateObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging",
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      },
    ]
  })
}

resource "aws_iam_access_key" "tofu" {
  user = aws_iam_user.tofu.name
}

# --- Outputs ---

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "iam_user" {
  value = aws_iam_user.tofu.name
}

output "access_key_id" {
  value     = aws_iam_access_key.tofu.id
  sensitive = true
}

output "secret_access_key" {
  value     = aws_iam_access_key.tofu.secret
  sensitive = true
}

output "next_steps" {
  value = <<-EOT

    ✅ Bootstrap complete! Next steps:

    1. Get your new credentials:
       tofu output -raw access_key_id
       tofu output -raw secret_access_key

    2. Add to ~/.aws/credentials:
       [matz-infra]
       aws_access_key_id = <from above>
       aws_secret_access_key = <from above>

    3. Add GitHub repo secrets (Settings → Secrets → Actions):
       AWS_ACCESS_KEY_ID      = <from above>
       AWS_SECRET_ACCESS_KEY  = <from above>
       ROUTE53_ZONE_ID        = <your zone id>
       HCLOUD_TOKEN           = <your hetzner token>

    4. You can now delete your old tofu-route53 IAM user — this one replaces it.
  EOT
}
