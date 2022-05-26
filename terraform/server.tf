# Load ssh key
resource "hcloud_ssh_key" "admin" {
  name       = "Admin key"
  public_key = file(var.ssh_pub_key_path)
}

resource "hcloud_firewall" "hub" {
  name = "Firewall"

  dynamic "rule" {
    for_each = flatten([
      for protocol, ports in var.incoming_firewall_ports: [
        for port in ports: {
          protocol = protocol
          port = port
        }
      ]
    ])

    content {
      direction = "in"
      protocol  = rule.value.protocol
      port      = rule.value.port
      source_ips = [
        "0.0.0.0/0"
      ]
    }
  }
}

resource "hcloud_server" "hub" {
  image       = "ubuntu-20.04"
  name        = "hub"
  server_type = var.hetzner_server_type
  ssh_keys = [hcloud_ssh_key.admin.id]
  location = var.hetzner_server_location
  backups = true
  firewall_ids = [hcloud_firewall.hub.id]
  delete_protection = true
  rebuild_protection = true
}

# since automount is enabled
# it is mounted at /mnt/HC_Volume_{hcloud_volume.cache.id}
# df -h | grep HC_Volume | awk '{print $6}'
resource "hcloud_volume" "cache" {
  name      = "cache"
  size      = 300
  server_id = hcloud_server.hub.id
  automount = true
  format    = "xfs"
}

# TODO reverse dns
#resource "hcloud_rdns" "master" {
#  server_id  = hcloud_server.node1.id
#  ip_address = hcloud_server.node1.ipv4_address
#  dns_ptr    = "example.com"
#}
