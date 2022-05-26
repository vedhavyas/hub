# hetzner cloud token
variable "hcloud_token" {
  sensitive = true # Requires terraform >= 0.14
}

# ssh pub key fiel path
variable "ssh_pub_key_path" {
  type = string
  description = "Path to Admin's SSH public key"
}

# hetzner server type
variable "hetzner_server_type" {
  type = string
  default = "cx41"
}

# hetzner server location
variable "hetzner_server_location" {
  type = string
  default = "hel1"
}

# incoming open ports
variable "incoming_firewall_ports" {
  type = map(list(string))
  default = {
    "tcp": ["22", "25" ,"80", "143", "443", "465", "587", "993"]
    "udp": ["51820"]
  }
}

