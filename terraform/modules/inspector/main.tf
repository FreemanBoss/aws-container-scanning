# Amazon Inspector v2 Configuration
# Note: Inspector v2 is enabled via AWS CLI or Console
# This resource creates the configuration but requires manual enablement first

resource "null_resource" "inspector_enable" {
  count = var.enable_inspector ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws inspector2 enable \
        --resource-types ${join(" ", var.resource_types)} || true
    EOT
  }

  triggers = {
    resource_types = join(",", var.resource_types)
  }
}

# Inspector Delegated Admin Configuration (for Organizations)
# Uncomment if using AWS Organizations
# resource "aws_inspector2_delegated_admin_account" "this" {
#   count = var.enable_inspector ? 1 : 0
#   account_id = data.aws_caller_identity.current.account_id
# }

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
