# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "HubandSpoke" {
  name     = var.resourcegroup_name
  location = var.location
}

resource "azurerm_virtual_network" "Hub" {
  name                = var.HubNetwork_Name
  location            = azurerm_resource_group.HubandSpoke.location
  resource_group_name = azurerm_resource_group.HubandSpoke.name
  address_space       = ["10.0.0.0/16"]
  subnet  {
    name           = "subnet1"
    address_prefix = "10.0.1.0/24"
  }
}

resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.HubandSpoke.name
  virtual_network_name = azurerm_virtual_network.Hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "vpngwip" {
  name                = "vpngwip"
  location            = azurerm_resource_group.HubandSpoke.location
  resource_group_name = azurerm_resource_group.HubandSpoke.name
  allocation_method = "Dynamic"
}


resource "azurerm_virtual_network" "Spoke01" {
  name                = var.Spoke01Network_Name
  location            = azurerm_resource_group.HubandSpoke.location
  resource_group_name = azurerm_resource_group.HubandSpoke.name
  address_space       = ["10.1.0.0/16"]
}
resource "azurerm_subnet" "spoke01defaultgateway" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.HubandSpoke.name
  virtual_network_name = azurerm_virtual_network.Spoke01.name
  address_prefixes     = ["10.1.1.0/24"]
  depends_on = [
    azurerm_virtual_network.Spoke01
  ]
}


resource "azurerm_virtual_network" "Spoke02" {
  name                = var.Spoke02Network_Name
  location            = azurerm_resource_group.HubandSpoke.location
  resource_group_name = azurerm_resource_group.HubandSpoke.name
  address_space       = ["10.2.0.0/16"]
}
resource "azurerm_subnet" "spoke02defaultgateway" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.HubandSpoke.name
  virtual_network_name = azurerm_virtual_network.Spoke02.name
  address_prefixes     = ["10.2.1.0/24"]
  depends_on = [
    azurerm_virtual_network.Spoke02
  ]
}

resource "azurerm_virtual_network_gateway" "vpngw" {
  name                = var.vpn_name
  location            = azurerm_resource_group.HubandSpoke.location
  resource_group_name = azurerm_resource_group.HubandSpoke.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpngwip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.GatewaySubnet.id
  }
  timeouts {
    create = "60m"
  }
}

resource "azurerm_virtual_network_peering" "Spoke01-Hub" {
    name                         = "Spoke01-Hub"
    resource_group_name          = azurerm_resource_group.HubandSpoke.name
    virtual_network_name         = azurerm_virtual_network.Spoke01.name
    remote_virtual_network_id    = azurerm_virtual_network.Hub.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
    use_remote_gateways = true
    depends_on = [
      azurerm_virtual_network.Hub, azurerm_virtual_network.Spoke01, azurerm_virtual_network.Spoke02, azurerm_virtual_network_gateway.vpngw
    ]
}
resource "azurerm_virtual_network_peering" "Spoke02-Hub" {
    name                         = "Spoke02-Hub"
    resource_group_name          = azurerm_resource_group.HubandSpoke.name
    virtual_network_name         = azurerm_virtual_network.Spoke02.name
    remote_virtual_network_id    = azurerm_virtual_network.Hub.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
    use_remote_gateways = true
    depends_on = [
      azurerm_virtual_network.Hub, azurerm_virtual_network.Spoke01, azurerm_virtual_network.Spoke02, azurerm_virtual_network_gateway.vpngw
    ]
}
resource "azurerm_virtual_network_peering" "Hub-Spoke01" {
    name                         = "Hub-Spoke01"
    resource_group_name          = azurerm_resource_group.HubandSpoke.name
    virtual_network_name         = azurerm_virtual_network.Hub.name
    remote_virtual_network_id    = azurerm_virtual_network.Spoke01.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
    allow_gateway_transit = true
    depends_on = [
      azurerm_virtual_network.Hub, azurerm_virtual_network.Spoke01, azurerm_virtual_network.Spoke02, azurerm_virtual_network_gateway.vpngw
    ]
}
resource "azurerm_virtual_network_peering" "Hub-Spoke02" {
    name                         = "Hub-Spoke02"
    resource_group_name          = azurerm_resource_group.HubandSpoke.name
    virtual_network_name         = azurerm_virtual_network.Hub.name
    remote_virtual_network_id    = azurerm_virtual_network.Spoke02.id
    allow_virtual_network_access = true
    allow_forwarded_traffic      = true
    allow_gateway_transit = true
    depends_on = [
      azurerm_virtual_network.Hub, azurerm_virtual_network.Spoke01, azurerm_virtual_network.Spoke02, azurerm_virtual_network_gateway.vpngw
    ]
}

resource "azurerm_route_table" "spoke01-Hub" {
  name                          = "spoke01-hub"
  location                      = azurerm_resource_group.HubandSpoke.location
  resource_group_name           = azurerm_resource_group.HubandSpoke.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.2.0.0/16"
    next_hop_type  = "VirtualNetworkGateway"
  }
}

resource "azurerm_route_table" "spoke02-Hub" {
  name                          = "spoke02-hub"
  location                      = azurerm_resource_group.HubandSpoke.location
  resource_group_name           = azurerm_resource_group.HubandSpoke.name
  disable_bgp_route_propagation = false

  route {
    name           = "route1"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "VirtualNetworkGateway"
  }
}

resource "azurerm_subnet_route_table_association" "spoke01-hub-ass-to-spoke01" {
  subnet_id      = azurerm_subnet.spoke01defaultgateway.id
  route_table_id = azurerm_route_table.spoke01-Hub.id
  depends_on = [
    azurerm_subnet.spoke01defaultgateway
  ]
}
resource "azurerm_subnet_route_table_association" "spoke02-hub-ass-to-spoke02" {
  subnet_id      = azurerm_subnet.spoke02defaultgateway.id
  route_table_id = azurerm_route_table.spoke02-Hub.id
  depends_on = [
    azurerm_subnet.spoke02defaultgateway
  ]
}