
terraform {
  required_version = ">= 1.5"
  required_providers {
    dns = { source = "hashicorp/dns", version = "~> 3.6" }
  }
}

data "terraform_remote_state" "vm" {
  backend = "local"
  config = {
    path = "${path.module}/../vm/terraform.tfstate"
  }
}

locals {
  zone   = "${var.zone}." # DNS zones are written with a trailing dot (fully qualified)
  vm_ips = data.terraform_remote_state.vm.outputs.vm_ips
}

provider "dns" {
  update {
    server        = data.terraform_remote_state.vm.outputs.dns_ip
    key_name      = "${var.tsig_key_name}."
    key_algorithm = "hmac-sha256"
    key_secret    = var.tsig_secret
  }
}

resource "dns_a_record_set" "vm" {
  for_each  = local.vm_ips
  zone      = local.zone
  name      = each.key
  addresses = [each.value]
  ttl       = var.ttl
}

resource "dns_a_record_set" "service" {
  for_each  = var.services
  zone      = local.zone
  name      = each.key
  addresses = [each.value]
  ttl       = var.ttl
}

resource "dns_cname_record" "www" {
  zone  = local.zone
  name  = "www"
  cname = "vm-app.${local.zone}"
  ttl   = var.ttl
}