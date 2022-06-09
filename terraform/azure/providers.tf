terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00000000-0000000-00000000-000000000"
  client_id       = "00000000-0000000-00000000-000000000"
  tenant_id       = "00000000-0000000-00000000-000000000"
  client_secret   = "CHANGE_ME"
}

