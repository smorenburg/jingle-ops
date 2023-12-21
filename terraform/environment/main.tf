terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }
    random = {
      version = ">= 3.6"
    }
    http = {
      version = ">= 3.4"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Configure the Terraform remote state backend.
data "terraform_remote_state" "shared" {
  backend = "azurerm"

  config = {
    storage_account_name = var.storage_account
    resource_group_name  = var.resource_group
    container_name       = "tfstate"
    key                  = "${var.location}.tfstate"
  }
}

# Get the public IP address
data "http" "public_ip" {
  url = "https://ifconfig.co/ip"
}

locals {
  # Lookup and set the location abbreviation, defaults to na (not available).
  location_abbreviation = try(var.location_abbreviation[var.location], "na")

  # Lookup and set the environment abbreviation, defaults to na (not available).
  environment_abbreviation = try(var.environment_abbreviation[var.environment], "na")

  # Construct the name suffix.
  suffix = "${var.app}-${local.environment_abbreviation}-${local.location_abbreviation}"

  # Clean and set the public IP address
  public_ip = chomp(data.http.public_ip.response_body)

  # Set the authorized IP ranges for the Kubernetes cluster.
  authorized_ip_ranges = ["${local.public_ip}/32"]
}

# Generate a random suffix for the key vault.
resource "random_id" "key_vault" {
  byte_length = 3
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}

# Create the managed identity for the Kubernetes cluster.
resource "azurerm_user_assigned_identity" "kubernetes_cluster" {
  name                = "id-aks-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

# Create the managed identity for the disk encryption set.
resource "azurerm_user_assigned_identity" "disk_encryption_set" {
  name                = "id-des-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

# Create the managed identity for the tf-runner, part of the tf-controller.
resource "azurerm_user_assigned_identity" "tf_runner" {
  name                = "id-tf-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_federated_identity_credential" "tf_runner" {
  name                = "fc-tf-${local.suffix}"
  resource_group_name = azurerm_resource_group.default.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.default.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.tf_runner.id
  subject             = "system:serviceaccount:flux-system:tf-runner"
}

# Create the disk encryption set.
resource "azurerm_disk_encryption_set" "default" {
  name                      = "des-${local.suffix}"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.default.name
  key_vault_key_id          = azurerm_key_vault_key.disk_encryption_set.versionless_id
  auto_key_rotation_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.disk_encryption_set.id]
  }

  depends_on = [azurerm_key_vault_access_policy.disk_encryption_set]
}

# Assign the contributor role to tf-runner managed identity.
resource "azurerm_role_assignment" "contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.tf_runner.principal_id
}