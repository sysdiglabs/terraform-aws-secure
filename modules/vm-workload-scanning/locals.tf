// generate a random suffix for the config-posture role name

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  ecr_role_name = "sysdig-vm-workload-scanning-${random_id.suffix.hex}"
}
