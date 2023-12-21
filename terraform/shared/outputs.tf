output "container_registry_id" {
  description = "The identifier of the container registry."
  value       = azurerm_container_registry.default.id
}

output "log_analytics_workspace_id" {
  description = "The identifier of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.default.id
}
