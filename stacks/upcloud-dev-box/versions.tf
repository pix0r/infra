terraform {
  required_version = ">= 1.6.0"

  required_providers {
    upcloud = {
      source  = "UpCloudLtd/upcloud"
      version = "= 5.45.0" # Migration lifecycle verified against this exact version.
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
