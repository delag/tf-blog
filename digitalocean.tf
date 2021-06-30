# Random sting to append to instances' name
resource "random_id" "namespace" {
  byte_length = 2
}

resource "digitalocean_project" "ghost_terraform" {
  name        = "ghost_terraform"
  description = "A ghost blog that is deployed via terraform and docker-compose"
  purpose     = "Web Application"
  environment = "Production"
  resources   = [digitalocean_droplet.web.urn]
}

data "digitalocean_ssh_key" "default" {
  name = var.do_key_name
}

resource "digitalocean_droplet" "web" {
  image    = "docker-18-04"
  name     = "terraform-${random_id.namespace.hex}"
  region   = "nyc3"
  size     = "s-1vcpu-1gb"
  ssh_keys = [ 
      data.digitalocean_ssh_key.default.id
  ]

  connection {
    host        = self.ipv4address
    user        = "root"
    type        = "ssh"
    private_key = file(var.do_key_path)
    timeout     = "10m"
  }

  user_data = templatefile("./cloud-init/web.yaml", {
    "PWD"                 = "$${PWD}",
    "cloudflare_zone"     = var.cloudflare_zone,
    "mysql_user_password" = var.mysql_user_password,
    "mysql_password"      = var.mysql_password
  })
}

data "cloudflare_ip_ranges" "cloudflare" {}

resource "digitalocean_firewall" "web" {
  name = "terraform-ghost-fw"
  
  droplet_ids = [digitalocean_droplet.web.id]

  inbound_rule {
    protocol    = "tcp"
    port_range  = "80"
    source_addresses = data.cloudflare_ip_ranges.cloudflare.cidr_blocks
  }

  inbound_rule {
    protocol    = "tcp"
    port_range  = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol    = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol    = "tcp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol    = "udp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol    = "icmp"
    port_range = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}