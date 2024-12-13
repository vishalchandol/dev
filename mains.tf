provider "azurerm" {
  features {
    
  }
}
#new comit check
resource "azurerm_resource_group" "myrg" {
  name = "rg1"
  location = "East US"

}

resource "azurerm_virtual_network" "myvnet" {
  name = "vnet1"
  resource_group_name = azurerm_resource_group.myrg.name
  address_space = ["10.0.0.0/16"]
  location = azurerm_resource_group.myrg.location
}

resource "azurerm_subnet" "pubsub1" {
  name = "pubsub1"
  resource_group_name = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes = [ "10.0.1.0/24" ]

}

resource "azurerm_subnet" "privsub1" {
  name = "privsub1"
  resource_group_name = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes = ["10.0.10.0/24"]
}

resource "azurerm_route_table" "myroutepub" {
  name = "myroutepub"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
}

resource "azurerm_route_table" "myroutepriv" {
  name = "myprivroute"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
}

resource "azurerm_route" "mypubroute1" {
  name = "routeforpub"
  resource_group_name = azurerm_resource_group.myrg.name

 address_prefix = "0.0.0.0/0"
  route_table_name = azurerm_route_table.myroutepub.name
  next_hop_type = "Internet"
}

resource "azurerm_subnet_route_table_association" "sr1" {
  route_table_id = azurerm_route.mypubroute1.id
  subnet_id = azurerm_subnet.pubsub1.id
}

resource "azurerm_subnet_route_table_association" "sr2" {
  route_table_id = azurerm_route_table.myroutepriv.id
  subnet_id = azurerm_subnet.privsub1.id
}

resource "azurerm_public_ip" "pubIP" {
  name = "pubIP"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
  allocation_method = "Dynamic"
}
resource "azurerm_network_interface" "nic1" {
  name = "nic1"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
  ip_configuration {
    name = "pub-ip"
    subnet_id = azurerm_subnet.pubsub1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.pubIP.id

  }
}

resource "azurerm_network_security_group" "nsg1" {
  name = "allowSG"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
}

resource "azurerm_network_security_rule" "nsr1" {
  name = "nsr1"
  resource_group_name = azurerm_resource_group.myrg.name
  network_security_group_name = azurerm_network_security_group.nsg1.name

  access = "Allow"
  direction = "Inbound"
  protocol = "Tcp"
  priority =    1000
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "*"
  destination_address_prefix = "*"

}

resource "azurerm_network_interface_security_group_association" "nisg1" {
  network_interface_id = azurerm_network_interface.nic1.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

#  Virtual machine 

resource "azurerm_linux_virtual_machine" "lin1" {
  name = "mylinux"
 resource_group_name = azurerm_resource_group.myrg.name
 location = azurerm_resource_group.myrg.location
 admin_username = "admin"
 admin_password = "123root"
 size = "Standard_B2s"
 network_interface_ids = [ azurerm_network_interface.nic1.id ]

os_disk {
  caching = "ReadWrite"
  storage_account_type = "Standard_LRS"
}

source_image_reference {
  publisher = ""
  offer = ""
  sku = ""
  version = ""
}

}


// load balancer

resource "azurerm_public_ip" "lb_pubIP" {
  name = "lb-pub-ip"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
  allocation_method = "Static"

}

resource "azurerm_lb" "mylb" {
  name = "mylb"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
  
  frontend_ip_configuration {
    name = "PublicIPconfig"
    public_ip_address_id = azurerm_public_ip.lb_pubIP.id
    subnet_id = azurerm_subnet.pubsub1.id
  }

  }

  resource "azurerm_lb_backend_address_pool" "pool1" {
    name = "mylb-pool"
    loadbalancer_id = azurerm_lb.mylb.id

  }

resource "azurerm_lb_probe" "prob1" {
  name = "probe1"
  loadbalancer_id = azurerm_lb.mylb.id
  port = 80
  protocol = "Http"
  request_path = "/"
  interval_in_seconds = 4
  number_of_probes = 2
}

resource "azurerm_lb_rule" "lb-rule-1" {
  name = "http-rule"
  loadbalancer_id = azurerm_lb.mylb.id
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name ="PublicIPconfig"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.pool1.id ]
  probe_id = azurerm_lb_probe.prob1.id

}

resource "azurerm_network_interface_backend_address_pool_association" "niclbpool" {
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool1.id
  network_interface_id = azurerm_network_interface.nic1.id
  ip_configuration_name = "pub-ip"

}


// Mat Gateway

resource "azurerm_public_ip" "nat-ip" {
  name                = "nat-gateway-ip"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  allocation_method   = "Static"
}

resource "azurerm_nat_gateway" "ng1" {
  name = "ng1"
  resource_group_name = azurerm_resource_group.myrg.name
  location = azurerm_resource_group.myrg.location
  
}

resource "azurerm_nat_gateway_public_ip_association" "ngipass" {
  nat_gateway_id = azurerm_nat_gateway.ng1.id
  public_ip_address_id = azurerm_public_ip.nat-ip.id

}


resource "azurerm_route" "priv-route-add1" {
  name = "adding-route-for-priv-VMs"
  resource_group_name = azurerm_resource_group.myrg.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "Internet"
  next_hop_in_ip_address = azurerm_nat_gateway.ng1.id
  route_table_name = azurerm_route_table.myroutepriv.name
  
}



output "lbpubIP" {
  value = azurerm_public_ip.lb_pubIP.ip_address
}




output "public_ip" {
  value = azurerm_public_ip.pubIP.ip_address
}



/***resource "azurerm_linux_virtual_machine_scale_set" "vms1" {
  name = "vms1"
  location = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
  instances = 1
  sku = "Standard_DS1_v2"

upgrade_mode = {
  
}
  
network_interface {
  
}

  os_profile {
    
  }

network_profile {
  
}


}
***/