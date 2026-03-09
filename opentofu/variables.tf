variable "project_name" {
  description = "Prefijo para todos los recursos."
  type        = string
  default     = "honeypot"
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string
  default     = "dev"
}

variable "hcloud_token" {
  description = "Token API de Hetzner Cloud."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Localización de las instancias."
  type        = string
  default     = "fsn1"
}

variable "private_network_zone" {
  description = "Zona de red privada."
  type        = string
  default     = "eu-central"
}

variable "network_cidr" {
  description = "CIDR de la red privada."
  type        = string
  default     = "10.42.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR de la subred principal."
  type        = string
  default     = "10.42.10.0/24"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave publica SSH."
  type        = string
}

variable "admin_user" {
  description = "Usuario administrativo para Ansible."
  type        = string
  default     = "adminops"
}

variable "admin_user_shell" {
  description = "Shell del usuario administrativo."
  type        = string
  default     = "/bin/bash"
}

variable "admin_ssh_port" {
  description = "Puerto SSH administrativo del host."
  type        = number
  default     = 22222
}

variable "server_type" {
  description = "Flavor de la VM principal."
  type        = string
  default     = "cx22"
}

variable "debian_image" {
  description = "Imagen Debian de Hetzner."
  type        = string
  default     = "debian-12"
}

variable "grafana_admin_password" {
  description = "Password inicial de Grafana."
  type        = string
  default     = "change-me-now"
  sensitive   = true
}

variable "postgres_password" {
  description = "Password para el usuario cowrie en PostgreSQL."
  type        = string
  default     = "change-me-db"
  sensitive   = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs permitidos para acceso SSH administrativo."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
