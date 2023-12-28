terraform {
  required_providers {
    azurerm = {
      version = ">= 3.84"
    }

    random = {
      version = ">= 3.6"
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

locals {
  # Lookup and set the location abbreviation, defaults to na (not available).
  location_abbreviation = try(var.location_abbreviation[var.location], "na")

  # Construct the name suffix.
  suffix = "${var.app}-${local.location_abbreviation}"
}

# Generate a random suffix for the logs storage account.
resource "random_id" "storage_account" {
  byte_length = 3
}

# Generate a random suffix for the key vault.
resource "random_id" "key_vault" {
  byte_length = 3
}

# Generate a random suffix for the container registry.
resource "random_id" "container_registry" {
  byte_length = 3
}

# Create the resource group.
resource "azurerm_resource_group" "default" {
  name     = "rg-${local.suffix}"
  location = var.location
}

# Create the storage account for the logs.
resource "azurerm_storage_account" "logs" {
  name                     = "st${var.app}${random_id.storage_account.hex}"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.default.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create the Log Analytics workspace.
resource "azurerm_log_analytics_workspace" "default" {
  name                = "log-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  retention_in_days   = 30
}

# Create the container registry.
resource "azurerm_container_registry" "default" {
  name                = "cr${var.app}${random_id.container_registry.hex}"
  resource_group_name = azurerm_resource_group.default.name
  location            = var.location
  sku                 = "Premium"
}

# Create the public IP address for the staging NGINX ingress controller.
resource "azurerm_public_ip" "ingress_nginx_stage" {
  name                = "pip-nginx-${var.app}-stage-${local.location_abbreviation}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.app}-stage-${local.location_abbreviation}"
}

# Create the public IP address for the production NGINX ingress controller.
resource "azurerm_public_ip" "ingress_nginx_prod" {
  name                = "pip-nginx-${var.app}-prod-${local.location_abbreviation}"
  location            = var.location
  resource_group_name = azurerm_resource_group.default.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.app}-prod-${local.location_abbreviation}"
}
