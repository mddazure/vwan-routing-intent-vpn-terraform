terraform {
  required_providers {
    azapi = {
      source = "azure/azapi"
    }
  }
}

provider "azurerm" {
features {}
}

provider "azapi" {
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "vwan-terraform-rg"
  location = "West Europe"
}
#Create a virtual wan
resource "azurerm_virtual_wan" "demo-vwan" {
  name                = "demo-vwan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}
#Create a virtual hub & gateway in West Europe
resource "azurerm_virtual_hub" "demo-we-hub" {
  name                = "demo-we-hub"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westeurope"
  virtual_wan_id      = azurerm_virtual_wan.demo-vwan.id
  address_prefix      = "192.168.0.0/24"
}
resource "azurerm_firewall" "we-fw" {
  name                = "we-fw"
  location = azurerm_virtual_hub.demo-we-hub.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name = "AZFW_Hub"
  sku_tier = "Premium"
  firewall_policy_id = azurerm_firewall_policy.fw-pol.id
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.demo-we-hub.id
  }
}
resource "azurerm_firewall_policy" "fw-pol"{
  name = "fw-pol"
  location = azurerm_virtual_hub.demo-we-hub.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Premium"
}
resource "azurerm_firewall_policy_rule_collection_group" "rule-col-grp" {
  name               = "rule-col-grp"
  firewall_policy_id = azurerm_firewall_policy.fw-pol.id
  priority           = 500

    network_rule_collection {
    name     = "network_rule_collection1"
    priority = 400
    action   = "Allow"
    rule {
      name                  = "network_rule_collection1_rule1"
      protocols             = ["TCP", "UDP"]
      source_addresses      = ["172.16.1.0/24"]
      destination_addresses = ["172.16.2.0/24"]
      destination_ports     = ["80", "443"]
    }
  }
}
#Enable routing intent
resource "azapi_resource" "we_routeintent" {
  type = "Microsoft.Network/virtualHubs/routingIntent@2022-01-01"
  name = "we_routeintent"
  parent_id = azurerm_virtual_hub.demo-we-hub.id
  body = jsonencode({
    properties = {
      routingPolicies = [
        {
          destinations = [
            "PrivateTraffic"
          ]
          name = "PrivateTraffic"
          nextHop = "${azurerm_firewall.we-fw.id}"
        }
      ]
    }
  })
}
/*
resource "azurerm_vpn_gateway" "demo-we-hub-vpngw" {
  name                = "demo-we-hub-vpngw"
  location            = azurerm_virtual_hub.demo-we-hub.location
  resource_group_name = azurerm_resource_group.rg.name
  virtual_hub_id      = azurerm_virtual_hub.demo-we-hub.id
  #public ip address of vpn gateway is not exposed, can only be retrieved from exported site configuration file after creation of gateway
  #it is therefore not possible to automate vpn-gateway to vnet-gateway s2s vpn connection
}*/
#Create a virtual hub in East US (West Europe)
resource "azurerm_virtual_hub" "demo-eastus-hub" {
  name                = "demo-eastus-hub"
  resource_group_name = azurerm_resource_group.rg.name
  #location            = "eastus"
  location            = "westeurope"
  virtual_wan_id      = azurerm_virtual_wan.demo-vwan.id
  address_prefix      = "192.168.1.0/24"
}
resource "azurerm_firewall" "eastus-fw" {
  name                = "eastus-fw"
  location = azurerm_virtual_hub.demo-eastus-hub.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name = "AZFW_Hub"
  sku_tier = "Premium"
  firewall_policy_id = azurerm_firewall_policy.fw-pol.id
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.demo-eastus-hub.id
  }
}
resource "azapi_resource" "eastus_routeintent" {
  type = "Microsoft.Network/virtualHubs/routingIntent@2022-01-01"
  name = "eastus_routeintent"
  parent_id = azurerm_virtual_hub.demo-eastus-hub.id
  body = jsonencode({
    properties = {
      routingPolicies = [
        {
          destinations = [
            "PrivateTraffic"
          ]
          name = "PrivateTraffic"
          nextHop = "${azurerm_firewall.eastus-fw.id}"
        }
      ]
    }
  })
}

/*
resource "azurerm_vpn_gateway" "demo-eastus-hub-vpngw" {
  name                = "demo-eastus-hub-vpngw"
  location            = azurerm_virtual_hub.demo-eastus-hub.location
  resource_group_name = azurerm_resource_group.rg.name
  virtual_hub_id      = azurerm_virtual_hub.demo-eastus-hub.id
  #public ip address of vpn gateway is not exposed, can only be retrieved from exported site configuration file after creation of gateway
  #it is therefore not possible to automate vpn-gateway to vnet-gateway s2s vpn connection
}*/
#Create spoke vnet connections
resource "azurerm_virtual_hub_connection" "spoke1-conn" {
  name                = "spoke1-conn"
  virtual_hub_id      = azurerm_virtual_hub.demo-we-hub.id
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id
}
resource "azurerm_virtual_hub_connection" "spoke2-conn" {
  name                = "spoke2-conn"
  virtual_hub_id      = azurerm_virtual_hub.demo-we-hub.id
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id
}
resource "azurerm_virtual_hub_connection" "spoke3-conn" {
  name                = "spoke3-conn"
  virtual_hub_id      = azurerm_virtual_hub.demo-we-hub.id
  remote_virtual_network_id = azurerm_virtual_network.spoke3.id
}
resource "azurerm_virtual_hub_connection" "spoke4-conn" {
  name                = "spoke4-conn"
  virtual_hub_id      = azurerm_virtual_hub.demo-eastus-hub.id
  remote_virtual_network_id = azurerm_virtual_network.spoke4.id
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "spoke1" {
  name                = "spoke1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westeurope"
  address_space       = ["172.16.1.0/24"]
  
}
resource "azurerm_subnet" "spoke1-subnet1"{
      name = "subnet1"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke1.name
      address_prefixes = ["172.16.1.0/26"]
  }
  resource "azurerm_subnet" "spoke1-subnet2"{
      name = "subnet2"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke1.name
      address_prefixes = ["172.16.1.64/26"]
  }
 
  resource "azurerm_subnet" "spoke1-bastionsubnet"{
      name = "AzureBastionSubnet"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke1.name
            address_prefixes = ["172.16.1.224/28"]
  }

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "spoke2" {
  name                = "spoke2"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westeurope"
  address_space       = ["172.16.2.0/24"]
  
}
resource "azurerm_subnet" "spoke2-subnet1"{
      name = "subnet1"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke2.name
      address_prefixes = ["172.16.2.0/26"]
  }
  resource "azurerm_subnet" "spoke2-subnet2"{
      name = "subnet2"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke2.name
      address_prefixes = ["172.16.2.64/26"]
  }
  resource "azurerm_subnet" "spoke2-bastionsubnet"{
      name = "AzureBastionSubnet"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke2.name
      address_prefixes = ["172.16.2.224/28"]
  }

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "spoke3" {
  name                = "spoke3"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "westeurope"
  address_space       = ["172.16.3.0/24"]
  
}
resource "azurerm_subnet" "spoke3-subnet1"{
      name = "subnet1"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke3.name
      address_prefixes = ["172.16.3.0/26"]
  }
  resource "azurerm_subnet" "spoke3-subnet2"{
      name = "subnet2"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke3.name
      address_prefixes = ["172.16.3.64/26"]
  }
# Create a virtual network within the resource group
resource "azurerm_virtual_network" "spoke4" {
  name                = "spoke4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus"
  address_space       = ["172.16.4.0/24"]
  
}
resource "azurerm_subnet" "spoke4-subnet1"{
      name = "subnet1"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke4.name
      address_prefixes = ["172.16.4.0/26"]
  }
resource "azurerm_subnet" "spoke4-subnet2"{
      name = "subnet2"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke4.name
      address_prefixes = ["172.16.4.64/26"]
  }
resource "azurerm_subnet" "spoke4-bastionsubnet"{
      name = "AzureBastionSubnet"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.spoke4.name
      address_prefixes = ["172.16.4.224/28"]
  }

/*
# Create a virtual network within the resource group
resource "azurerm_virtual_network" "onprem" {
  name                = "onprem"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "northeurope"
  address_space       = ["10.0.1.0/24"]
  
}
resource "azurerm_subnet" "onprem-subnet1"{
      name = "subnet1"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.onprem.name
      address_prefix = "10.0.1.0/26"
  }
resource "azurerm_subnet" "onprem-subnet2"{
      name = "subnet2"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.onprem.name
      address_prefix = "10.0.1.64/26"
  }
resource "azurerm_subnet" "onprem-GatewaySubnet"{
      name = "GatewaySubnet"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.onprem.name
            address_prefix = "10.0.1.240/28"
}
resource "azurerm_subnet" "onprem-bastionsubnet"{
      name = "AzureBastionSubnet"
      resource_group_name = azurerm_resource_group.rg.name
      virtual_network_name = azurerm_virtual_network.onprem.name
      address_prefix = "10.0.1.224/28"
  }

#Create virtual network gateway
resource "azurerm_public_ip" "onprem-gw-pubip" {
  name                = "onprem-gw-pubip"
  location            = azurerm_virtual_network.onprem.location
  resource_group_name = azurerm_resource_group.rg.name

  allocation_method = "Dynamic"
}
resource "azurerm_virtual_network_gateway" "qonprem-gw" {
  name                = "qonprem-gw"
  location            = azurerm_virtual_network.onprem.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "onprem-gwGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.onprem-gw-pubip.id
    subnet_id                     = azurerm_subnet.onprem-GatewaySubnet.id
  }
  bgp_settings {
      asn                         = 65514     
  }
}
*/


#create network interfaces
resource "azurerm_network_interface" "vwan1-nic" {
  name                = "vwan1-nic"
  location            = azurerm_virtual_network.spoke1.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke1-subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_interface" "vwan4-nic" {
  name                = "vwan4-nic"
  location            = azurerm_virtual_network.spoke4.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.spoke4-subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}
/*
resource "azurerm_network_interface" "onprem-nic" {
  name                = "onprem-nic"
  location            = azurerm_virtual_network.onprem.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.onprem-subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}
*/
#create vms
resource "azurerm_windows_virtual_machine" "vwan1" {
  name                = "vwan1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.spoke1.location
  size                = "Standard_D2s_v3"
  admin_username      = "marc"
  admin_password = "Nienke040598"
  network_interface_ids = [
    azurerm_network_interface.vwan1-nic.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  #source_image_id = "/subscriptions/0245be41-c89b-4b46-a3cc-a705c90cd1e8/resourceGroups/image-gallery-rg/providers/Microsoft.Compute/galleries/mddimagegallery/images/windows2019-networktools/versions/2.0.0"

  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "install-iis-vwan1" {
    
  name                 = "install-iis-vwan1"
  virtual_machine_id   = azurerm_windows_virtual_machine.vwan1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

   settings = <<SETTINGS
    {
        "commandToExecute":"powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server; powershell -ExecutionPolicy Unrestricted Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"
    }
SETTINGS
}


resource "azurerm_windows_virtual_machine" "vwan4" {
  name                = "vwan4"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.spoke1.location
  size                = "Standard_D2s_v3"
  admin_username      = "marc"
  admin_password = "Nienke040598"
  network_interface_ids = [
    azurerm_network_interface.vwan4-nic.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  #source_image_id = "/subscriptions/0245be41-c89b-4b46-a3cc-a705c90cd1e8/resourceGroups/image-gallery-rg/providers/Microsoft.Compute/galleries/mddimagegallery/images/windows2019-networktools/versions/2.0.0"
  
  source_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "install-iis-vwan4" {
    
  name                 = "install-iis-vwan4"
  virtual_machine_id   = azurerm_windows_virtual_machine.vwan4.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

   settings = <<SETTINGS
    {
        "commandToExecute":"powershell -ExecutionPolicy Unrestricted Add-WindowsFeature Web-Server; powershell -ExecutionPolicy Unrestricted Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"
    }
SETTINGS
}


/*
resource "azurerm_windows_virtual_machine" "onprem" {
  name                = "onprem"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_virtual_network.onprem.location
  size                = "Standard_D2s_v3"
  admin_username      = "marc"
  disable_password_authentication = false
   admin_password = "Nienke040598"
  network_interface_ids = [
    azurerm_network_interface.onprem-nic.id,
  ]
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_id = "/subscriptions/0245be41-c89b-4b46-a3cc-a705c90cd1e8/resourceGroups/image-gallery-rg/providers/Microsoft.Compute/galleries/mddimagegallery/images/windows2019-networktools/versions/2.0.0"
}
#create bastion
resource "azurerm_public_ip" "onprem-bastion-pubip" {
  name                = "onprem-bastion-pubip"
  location            = azurerm_virtual_network.onprem.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  allocation_method = "Static"
}*/

resource "azurerm_public_ip" "spoke1-bastion-pubip" {
  name                = "spoke1-bastion-pubip"
  location            = azurerm_virtual_network.spoke1.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Standard"
  allocation_method = "Static"
}
resource "azurerm_bastion_host" "spoke1-bastion" {
  name                = "spoke1-bastion"
  location            = azurerm_virtual_network.spoke1.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.spoke1-bastionsubnet.id
    public_ip_address_id = azurerm_public_ip.spoke1-bastion-pubip.id
  }
}
/*
resource "azurerm_bastion_host" "qremote-bastion" {
  name                = "qremote-bastion"
  location            = azurerm_virtual_network.onprem.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.onprem-bastionsubnet.id
    public_ip_address_id = azurerm_public_ip.onprem-bastion-pubip.id
  }
}*/