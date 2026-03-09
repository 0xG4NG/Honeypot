locals {
  name_prefix = "${var.project_name}-${var.environment}"
  server_private_ip = cidrhost(var.subnet_cidr, 10)
}

resource "hcloud_ssh_key" "admin" {
  name       = "${local.name_prefix}-ssh"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_network" "main" {
  name     = "${local.name_prefix}-net"
  ip_range = var.network_cidr
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = var.private_network_zone
  ip_range     = var.subnet_cidr
}

resource "hcloud_firewall" "base" {
  name = "${local.name_prefix}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = tostring(var.admin_ssh_port)
    source_ips = var.ssh_allowed_cidrs
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "3000"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "9090"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "out"
    protocol   = "tcp"
    port       = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
  }

  apply_to {
    label_selector = "stack=${local.name_prefix}"
  }
}

resource "hcloud_server" "main" {
  name        = "${local.name_prefix}-stack"
  image       = var.debian_image
  server_type = var.server_type
  location    = var.location

  ssh_keys = [hcloud_ssh_key.admin.id]

  labels = {
    role  = "stack"
    stack = local.name_prefix
  }

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    admin_user       = var.admin_user
    admin_user_shell = var.admin_user_shell
    admin_ssh_port   = var.admin_ssh_port
    ssh_public_key   = trimspace(file(pathexpand(var.ssh_public_key_path)))
  })

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.main.id
    ip         = local.server_private_ip
  }

  depends_on = [hcloud_network_subnet.main]
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOT
    [honeypot_host]
    stack ansible_host=${hcloud_server.main.ipv4_address} ansible_port=${var.admin_ssh_port} private_ip=${local.server_private_ip} role=stack

    [all:vars]
    ansible_user=${var.admin_user}
    ansible_become=true
    grafana_admin_password=${var.grafana_admin_password}
    postgres_cowrie_password=${var.postgres_password}
  EOT
}
