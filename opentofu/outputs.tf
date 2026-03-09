output "public_ip" {
  description = "IP pública del host principal."
  value       = hcloud_server.main.ipv4_address
}

output "private_ip" {
  description = "IP privada del host principal."
  value       = local.server_private_ip
}

output "inventory_file" {
  description = "Ruta del inventario generado."
  value       = local_file.ansible_inventory.filename
}
