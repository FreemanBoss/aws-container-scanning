output "inspector_status" {
  description = "Status of Inspector v2"
  value       = var.enable_inspector ? "enabled" : "disabled"
}
