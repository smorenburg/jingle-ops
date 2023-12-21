output "oidc_issuer_url" {
  description = "The OpenID Connect issuer URL."
  value       = azurerm_kubernetes_cluster.default.oidc_issuer_url
}
