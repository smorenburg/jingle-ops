output "resource_group_id" {
  description = "The identifier of the resource group."
  value       = azurerm_resource_group.default.id
}

output "container_registry_id" {
  description = "The identifier of the container registry."
  value       = azurerm_container_registry.default.id
}

output "log_analytics_workspace_id" {
  description = "The identifier of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.default.id
}

output "azurerm_public_ip_ingress_nginx_stage_ip_address" {
  description = "The public IP address for the staging NGINX ingress controller."
  value       = azurerm_public_ip.ingress_nginx_stage.ip_address
}

output "azurerm_public_ip_ingress_nginx_prod_ip_address" {
  description = "The public IP address for the production NGINX ingress controller."
  value       = azurerm_public_ip.ingress_nginx_prod.ip_address
}
