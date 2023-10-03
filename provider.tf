terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.75.0"
    }
    /*
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 0.5.0"
    }
    */
  }
}

provider "azurerm" {
    features {}
}

/*
provider "azuredevops" {
  # version = ">= 0.5.0"
  org_service_url       = var.git_service_url
  personal_access_token = var.git_pat
}
*/
