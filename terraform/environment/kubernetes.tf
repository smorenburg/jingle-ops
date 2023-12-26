# Create the Kubernetes cluster, including the system node pool.
resource "azurerm_kubernetes_cluster" "default" {
  name                      = "aks-${local.suffix}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.default.name
  node_resource_group       = "rg-aks-${local.suffix}"
  dns_prefix                = "aks-${local.suffix}"
  sku_tier                  = var.kubernetes_cluster_sku_tier
  disk_encryption_set_id    = azurerm_disk_encryption_set.default.id
  azure_policy_enabled      = true
  local_account_disabled    = true
  automatic_channel_upgrade = "patch"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.kubernetes_cluster_node_pool_system_vm_size
    os_disk_size_gb              = var.kubernetes_cluster_node_pool_system_os_disk_size_gb
    os_disk_type                 = "Ephemeral"
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "temp"
    vnet_subnet_id               = azurerm_subnet.aks.id
    zones                        = ["1", "2", "3"]
    enable_auto_scaling          = true
    min_count                    = 3
    max_count                    = 9

    upgrade_settings {
      max_surge = "1"
    }
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.kubernetes_cluster.id]
  }

  api_server_access_profile {
    authorized_ip_ranges = local.authorized_ip_ranges
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  oms_agent {
    log_analytics_workspace_id = data.terraform_remote_state.shared.outputs.log_analytics_workspace_id
  }

  microsoft_defender {
    log_analytics_workspace_id = data.terraform_remote_state.shared.outputs.log_analytics_workspace_id
  }
}

# Create the standard node pool.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.default.id
  vm_size               = var.kubernetes_cluster_node_pool_user_vm_size
  os_disk_size_gb       = var.kubernetes_cluster_node_pool_user_os_disk_size_gb
  os_disk_type          = "Ephemeral"
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = ["1", "2", "3"]
  enable_auto_scaling   = true
  min_count             = 3
  max_count             = 9

  upgrade_settings {
    max_surge = "1"
  }
}

# Assign the cluster admin role to the current user.
resource "azurerm_role_assignment" "cluster_admin_current_user" {
  scope                = azurerm_kubernetes_cluster.default.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Assign the cluster admin role to the tf-runner managed identity.
resource "azurerm_role_assignment" "cluster_admin_tf_runner" {
  scope                = azurerm_kubernetes_cluster.default.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.tf_runner.principal_id
}

# Assign the 'AcrPull' role to the Kubernetes cluster managed identity to the container registry.
resource "azurerm_role_assignment" "container_registry" {
  scope                = data.terraform_remote_state.shared.outputs.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.kubernetes_cluster.principal_id
}

# Install the Flux cluster extension.
resource "azurerm_kubernetes_cluster_extension" "flux" {
  count          = var.install_flux ? 1 : 0
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.default.id
  extension_type = "microsoft.flux"

  configuration_settings = {
    "toleration-keys" = "CriticalAddonsOnly=true:NoSchedule"
  }

  depends_on = [
    azurerm_kubernetes_cluster_node_pool.user
  ]
}
