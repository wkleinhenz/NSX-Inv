


data "nsxt_policy_edge_cluster" "EGS-MAIN-Cluster" {
  display_name = "EGS-MAIN-Cluster"
}

data "nsxt_policy_edge_node" "ESG-NSXT-01" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.EGS-MAIN-Cluster.path
  display_name      = "ESG-NSXT-01"
}
data "nsxt_policy_edge_node" "ESG-NSXT-02" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.EGS-MAIN-Cluster.path
  display_name      = "ESG-NSXT-02"
}
data "nsxt_policy_transport_zone" "std-overlay-01" {
  display_name   = "nsx-overlay-transportzone"
  transport_type = "OVERLAY_STANDARD"
}
data "nsxt_policy_transport_zone" "std-vlan-01" {
  display_name   = "nsx-vlan-transportzone"
  transport_type = "VLAN_BACKED"

}
data "nsxt_policy_segment_security_profile" "dhcp_allow" {
  display_name = "DHCP Allow"
}
resource "nsxt_policy_ip_pool" "transport" {
  display_name = "Transport Nodes"
  nsx_id       = "Transport_Nodes"

}

resource "nsxt_policy_ip_pool_static_subnet" "transport_subnet-01" {
  display_name = "static-subnet1"
  pool_path    = nsxt_policy_ip_pool.transport.path
  cidr         = "10.0.0.0/24"
  gateway      = "10.0.0.1"


  allocation_range {
    start = "10.0.0.2"
    end   = "10.0.0.254"
  }
}


resource "nsxt_policy_ip_pool" "edge" {
  display_name = "Edge Nodes"
  nsx_id       = "Edge_Nodes"

}

resource "nsxt_policy_ip_pool_static_subnet" "edge_subnet-01" {
  display_name = "edge-static-subnet1"
  pool_path    = nsxt_policy_ip_pool.edge.path
  cidr         = "10.0.2.0/24"
  gateway      = "10.0.2.1"


  allocation_range {
    start = "10.0.2.2"
    end   = "10.0.2.254"
  }
}

resource "nsxt_policy_vlan_segment" "vlan-uplink" {
  display_name        = "VLAN-UPLINK"
  description         = "VLAN-UPLINK"
  transport_zone_path = data.nsxt_policy_transport_zone.std-vlan-01.path
  vlan_ids            = ["100"]
  subnet {
    cidr        = "10.0.1.1/24"
    dhcp_ranges = []
  }


}
# resource "nsxt_policy_tier0_gateway_interface" "Uplink-01" {
#   display_name           = "Uplink-01"
#   description            = "Uplink-01"
#   type                   = "EXTERNAL"
#   gateway_path           = nsxt_policy_tier0_gateway.Prod-T0-01.path
#   segment_path           = nsxt_policy_vlan_segment.vlan-uplink.path
#   edge_node_path         = data.nsxt_policy_edge_node.ESG-NSXT-03.path
#   subnets                = ["10.0.1.100/24"]
#   mtu                    = 9000
# }
# resource "nsxt_policy_tier0_gateway_interface" "Uplink-02" {
#   display_name           = "Uplink-02"
#   description            = "Uplink-02"
#   type                   = "EXTERNAL"
#   gateway_path           = nsxt_policy_tier0_gateway.Prod-T0-01.path
#   segment_path           = nsxt_policy_vlan_segment.vlan-uplink.path
#   edge_node_path         = data.nsxt_policy_edge_node.ESG-NSXT-04.path
#   subnets                = ["10.0.1.101/24"]
#   mtu                    = 9000
# }


resource "nsxt_policy_tier0_gateway" "Prod-T0-01" {
  display_name = "Prod-T0-01"

  default_rule_logging = false
  enable_firewall      = true
  force_whitelisting   = false
  ha_mode              = "ACTIVE_ACTIVE"

  edge_cluster_path = data.nsxt_policy_edge_cluster.EGS-MAIN-Cluster.path

  bgp_config {
    enabled         = true
    local_as_num    = "18"
    multipath_relax = true
    inter_sr_ibgp   = true

    ecmp                               = true
    graceful_restart_mode              = "GR_AND_HELPER"
    graceful_restart_timer             = 180
    graceful_restart_stale_route_timer = 600

  }
}






resource "nsxt_policy_bgp_neighbor" "SRX_Main" {
  display_name          = "SRX_Main"
  bgp_path              = nsxt_policy_tier0_gateway.Prod-T0-01.bgp_config.0.path
  allow_as_in           = false
  graceful_restart_mode = "GR_AND_HELPER"
  hold_down_time        = 180
  keep_alive_time       = 60
  neighbor_address      = "10.0.1.1"
  remote_as_num         = "17"
  depends_on            = [nsxt_policy_tier0_gateway.Prod-T0-01]

  bfd_config {
    enabled  = true
    interval = 500
    multiple = 3
  }

  route_filtering {
    address_family = "IPV4"
  }
}

resource "nsxt_policy_tier1_gateway" "Prod-T1-01" {
  description  = "Tier-1 provisioned by Terraform"
  display_name = "Prod-T1-01"

  edge_cluster_path         = data.nsxt_policy_edge_cluster.EGS-MAIN-Cluster.path
  failover_mode             = "PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  force_whitelisting        = "false"
  tier0_path                = nsxt_policy_tier0_gateway.Prod-T0-01.path
  dhcp_config_path          = nsxt_policy_dhcp_server.build.path
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED", "TIER1_NAT", "TIER1_LB_VIP", "TIER1_LB_SNAT", "TIER1_DNS_FORWARDER_IP", "TIER1_IPSEC_LOCAL_ENDPOINT"]
}
resource "nsxt_policy_segment" "Prod-01" {
  display_name        = "Prod-01"
  description         = "Prod-01"
  connectivity_path   = nsxt_policy_tier1_gateway.Prod-T1-01.path
  transport_zone_path = data.nsxt_policy_transport_zone.std-overlay-01.path

  subnet {
    cidr = "10.0.110.1/24"
  }
}
resource "nsxt_policy_segment" "Home" {
  display_name        = "Home"
  description         = "Home"
  connectivity_path   = nsxt_policy_tier1_gateway.Prod-T1-01.path
  transport_zone_path = data.nsxt_policy_transport_zone.std-overlay-01.path
  subnet {
    cidr = "10.0.100.1/24"
  }
}
resource "nsxt_policy_segment" "Pentest" {
  display_name        = "Pentest"
  description         = "Pentest"
  connectivity_path   = nsxt_policy_tier1_gateway.Prod-T1-01.path
  transport_zone_path = data.nsxt_policy_transport_zone.std-overlay-01.path
   subnet {
    cidr        = "10.1.101.1/24"
    dhcp_ranges = ["10.1.101.3-10.1.101.251"]
    dhcp_v4_config {
      server_address = "10.1.101.2/24"
      lease_time     = 36000
    }
  }
  security_profile {
    security_profile_path   = data.nsxt_policy_segment_security_profile.dhcp_allow.path
  }
}

resource "nsxt_policy_dhcp_server" "build" {
  display_name      = "build"
  description       = "Terraform provisioned DhcpServerConfig"
  edge_cluster_path = data.nsxt_policy_edge_cluster.EGS-MAIN-Cluster.path
  lease_time        = 200
}



resource "nsxt_policy_segment" "build" {
  display_name        = "build"
  description         = "build"
  connectivity_path   = nsxt_policy_tier1_gateway.Prod-T1-01.path
  transport_zone_path = data.nsxt_policy_transport_zone.std-overlay-01.path
  depends_on          = [nsxt_policy_tier1_gateway.Prod-T1-01]
  subnet {
    cidr        = "10.1.1.1/24"
    dhcp_ranges = ["10.1.1.3-10.1.1.100"]
    dhcp_v4_config {
      server_address = "10.1.1.2/24"
      lease_time     = 36000
    }
  }
  security_profile {
    security_profile_path   = data.nsxt_policy_segment_security_profile.dhcp_allow.path
  }
}

resource "nsxt_policy_segment" "k8s" {
  display_name        = "k8s"
  description         = "k8s"
  connectivity_path   = nsxt_policy_tier1_gateway.Prod-T1-01.path
  transport_zone_path = data.nsxt_policy_transport_zone.std-overlay-01.path
  depends_on          = [nsxt_policy_tier1_gateway.Prod-T1-01]
  subnet {
    cidr        = "10.2.1.1/24"
    dhcp_ranges = ["10.2.1.3-10.2.1.100"]
    dhcp_v4_config {
      server_address = "10.2.1.2/24"
      lease_time     = 36000
    }
  }

}


