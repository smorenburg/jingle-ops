# Create the key vault.
resource "azurerm_key_vault" "default" {
  name                       = "kv-${var.app}-${random_id.key_vault.hex}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.default.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

# Create the key vault policy for the current user.
resource "azurerm_key_vault_access_policy" "default" {
  key_vault_id = azurerm_key_vault.default.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Update",
    "Sign",
    "GetRotationPolicy",
    "SetRotationPolicy"
  ]

  secret_permissions = [
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Set"
  ]
}
