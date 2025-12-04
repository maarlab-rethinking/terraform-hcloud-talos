# Retrieve the public IP address of the current machine if the firewall should be opened for the current IP
data "http" "personal_ipv4" {
  count = var.firewall_id == null && var.firewall_use_current_ip ? 1 : 0
  url   = "https://ipv4.icanhazip.com"

  retry {
    attempts     = 3
    min_delay_ms = 1000
    max_delay_ms = 2000
  }
}

data "http" "personal_ipv6" {
  count = var.firewall_id == null && var.firewall_use_current_ip && var.enable_ipv6 ? 1 : 0
  url   = "https://ipv6.icanhazip.com"

  retry {
    attempts     = 3
    min_delay_ms = 1000
    max_delay_ms = 2000
  }
}

locals {
  # Current IPs list - always includes IPv4, conditionally includes IPv6
  # Only computed when firewall is managed by this module
  current_ips = var.firewall_id == null && var.firewall_use_current_ip ? concat(
    [
      "${chomp(data.http.personal_ipv4[0].response_body)}/32",
    ],
    var.firewall_use_current_ip && var.enable_ipv6 ? [
      "${chomp(data.http.personal_ipv6[0].response_body)}/128",
    ] : []
  ) : []

  # Define API services configuration
  api_services = {
    kube = {
      port        = local.api_port_k8s
      source      = var.firewall_kube_api_source
      description = "Allow incoming requests to Kubernetes API Server"
    }
    talos = {
      port        = "50000"
      source      = var.firewall_talos_api_source
      description = "Allow incoming requests to Talos API Server"
    }
  }

  base_firewall_rules = [
    for key, service in local.api_services : {
      description = service.description
      direction   = "in"
      protocol    = "tcp"
      port        = service.port
      source_ips  = service.source != null ? concat(service.source, local.current_ips) : local.current_ips
    } if service.source != null || var.firewall_use_current_ip
  ]

  # Merge base and extra rules, ensuring extra rules take precedence for duplicates.
  firewall_rules_list = values({
    for rule in concat(local.base_firewall_rules, var.extra_firewall_rules) :
    format("%s-%s-%s",
      lookup(rule, "direction", "null"),
      lookup(rule, "protocol", "null"),
      lookup(rule, "port", "null")
    ) => rule
  })

  # Resolved firewall ID to use
  firewall_id = var.firewall_id != null ? var.firewall_id : try(hcloud_firewall.this[0].id, null)
}

resource "hcloud_firewall" "this" {
  count = var.firewall_id == null ? 1 : 0
  name  = var.cluster_name
  dynamic "rule" {
    for_each = local.firewall_rules_list
    //noinspection HILUnresolvedReference
    content {
      description     = rule.value.description
      direction       = rule.value.direction
      protocol        = rule.value.protocol
      port            = lookup(rule.value, "port", null)
      destination_ips = lookup(rule.value, "destination_ips", [])
      source_ips      = lookup(rule.value, "source_ips", [])
    }
  }
  labels = {
    "cluster" = var.cluster_name
  }
}
