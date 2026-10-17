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

run "replacement_is_independent_unbacked_standard_storage" {
  command = plan
  assert {
    condition     = var.data_size == 50 && var.data_tier == "standard"
    error_message = "The desired replacement must default to 50 GB Standard."
  }
  assert {
    condition     = upcloud_storage.data_standard.size == 50 && upcloud_storage.data_standard.tier == "standard"
    error_message = "Adopt the detached replacement as its own normal storage resource."
  }
  assert {
    condition     = length(upcloud_storage.data_standard.backup_rule) == 0 && length(upcloud_storage.data_standard.clone) == 0
    error_message = "Use normal imported storage without per-disk backup rules or replacement-triggering clone provenance."
  }
}

override_resource {
  target = upcloud_storage.data
  values = {
    id = "012ff8f3-fd54-42d5-9634-3eea56db0ca8"
  }
}
override_resource {
  target = upcloud_storage.data_standard
  values = {
    id = "01000000-0000-4000-8000-000000000050"
  }
}

run "cutover_attaches_only_replacement_and_preserves_rollback_output" {
  command = plan
  assert {
    condition     = length(upcloud_server.dev_box[0].storage_devices) == 1 && one(upcloud_server.dev_box[0].storage_devices).storage == upcloud_storage.data_standard.id
    error_message = "Attach exactly the prepared replacement; never both same-label clones."
  }
  assert {
    condition     = output.data_storage_id == upcloud_storage.data_standard.id && output.legacy_data_storage_id == upcloud_storage.data.id
    error_message = "Recovery outputs must distinguish the active and detached original disk."
  }
  assert {
    condition     = length(upcloud_server.dev_box[0].simple_backup) == 0
    error_message = "Simple Backup must be a later completed apply after detaching the Flexible-backed disk."
  }
}
