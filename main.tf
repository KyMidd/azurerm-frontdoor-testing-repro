##
# Main.tf files are called directly by terraform
# They import modules which build resources using the variables passed to them from this file
# In the same local folder, they import .tfvars files to populate variables
##

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

# Define azurerm backend, Azure DevOps will fill in other required details
terraform {
  required_providers {
    azurerm = {
      version = "2.40.0"
      source  = "terraform.example.com/local/azurerm"
    }
  }
}

resource "azurerm_resource_group" "testing_kyler" {
  name     = "TestingKyler"
  location = "East US"
}

resource "azurerm_frontdoor_firewall_policy" "frontdoor" {
  name                              = "KylerTestingWafPolicy"
  resource_group_name               = azurerm_resource_group.testing_kyler.name
  enabled                           = true
  mode                              = "Prevention"
  redirect_url                      = "https://www.google.com"
  custom_block_response_status_code = 403
  custom_block_response_body        = "PGh0bWw+DQo8aGVhZGVyPjx0aXRsZT5Gb3JiaWRkZW4gQWNjZXNzPC90aXRsZT48L2hlYWRlcj4NCjxib2R5Pg0KRm9yYmlkZGVuDQo8L2JvZHk+DQo8L2h0bWw+"

  custom_rule {
    name                           = "AllowTrafficFromUSCanada"
    enabled                        = true
    priority                       = 1
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Allow"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = false
      match_values       = ["US", "CA"]
    }
  }

  custom_rule {
    name                           = "DenyTrafficFromOutsideUSCanada"
    enabled                        = true
    priority                       = 2
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "GeoMatch"
      negation_condition = true
      match_values       = ["US", "CA"]
    }
  }

  custom_rule {
    name                           = "DenyTrafficFromIndividualIPs"
    enabled                        = true
    priority                       = 3
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 10
    type                           = "MatchRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["1.1.1.1/32"]
    }
  }
  managed_rule {
    type    = "DefaultRuleSet"
    version = "preview-0.1"
  }

  managed_rule {
    type    = "BotProtection"
    version = "preview-0.1"
  }

  lifecycle {
    ignore_changes = [
      custom_rule
    ]
  }
}

resource "azurerm_frontdoor" "example" {
  name                                         = "kyler-testing-frontdoor"
  location                                     = "EastUS"
  resource_group_name                          = azurerm_resource_group.testing_kyler.name
  enforce_backend_pools_certificate_name_check = false

  routing_rule {
    name               = "exampleRoutingRule1"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["TestingEndPoint"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "exampleBackendBing"
    }
  }

  backend_pool_load_balancing {
    name = "exampleLoadBalancingSettings1"
  }

  backend_pool_health_probe {
    name = "exampleHealthProbeSetting1"
  }

  backend_pool {
    name = "exampleBackendBing"
    backend {
      host_header = "www.bing.com"
      address     = "www.bing.com"
      http_port   = 80
      https_port  = 443
    }

    load_balancing_name = "exampleLoadBalancingSettings1"
    health_probe_name   = "exampleHealthProbeSetting1"
  }

  frontend_endpoint {
    custom_https_provisioning_enabled       = false
    host_name                               = "kyler-testing-frontdoor.azurefd.net"
    name                                    = "TestingEndPoint"
    session_affinity_enabled                = false
    session_affinity_ttl_seconds            = 0
    web_application_firewall_policy_link_id = azurerm_frontdoor_firewall_policy.frontdoor.id
  }
}
