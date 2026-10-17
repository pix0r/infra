# Mock only the provider boundary; evaluate the real stack's expressions.
# These plan-only tests never contact APIs or create infrastructure.
mock_provider "upcloud" {}
mock_provider "aws" {}
mock_provider "http" {
  mock_data "http" {
    defaults = {
      response_body = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestFixture test@example.invalid\n"
    }
  }
}
mock_provider "tls" {}
mock_provider "local" {}

variables {
  route53_zone_id = "ZTEST"
}

run "replacement_defaults_do_not_mutate_original_disk" {
  command = plan
  variables {
    data_size = 50
    data_tier = "standard"
  }
  assert {
    condition     = upcloud_storage.data.size == 20 && upcloud_storage.data.tier == "maxiops"
    error_message = "Replacement settings must never resize or replace the retained original disk."
  }
  assert {
    condition     = upcloud_storage.data.backup_rule[0].retention == 7
    error_message = "Keep the original disk's rollback backups until recovery is tested."
  }
}
