
terraform {
  required_version = ">= 1.5"
  required_providers {
    libvirt = { source = "dmacvicar/libvirt", version = "~> 0.8.3" }
    local   = { source = "hashicorp/local", version = "~> 2.5" }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}
resource "libvirt_network" "ruo" {
  name      = var.network_name
  mode      = "nat"
  addresses = [var.network_cidr]
  autostart = true

  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}
resource "libvirt_volume" "base" {
  name   = "ruo-noble-base.qcow2"
  pool   = var.pool
  format = "qcow2"
  source = pathexpand(var.base_image)
}

resource "libvirt_volume" "disk" {
  for_each       = var.vms
  name           = "${each.key}.qcow2"
  pool           = var.pool
  base_volume_id = libvirt_volume.base.id
  size           = each.value.disk_gb * 1024 * 1024 * 1024
}
resource "libvirt_cloudinit_disk" "init" {
  for_each = var.vms
  name     = "${each.key}-init.iso"
  pool     = var.pool
  user_data = templatefile("${path.module}/../../cloud-init/user-data.tftpl", {
    hostname   = each.key
    admin_user = var.admin_user
    ssh_key    = trimspace(file(pathexpand(var.ssh_public_key)))
  })
}

resource "libvirt_domain" "vm" {
  for_each  = var.vms
  name      = each.key
  memory    = each.value.memory
  vcpu      = each.value.vcpu
  autostart = true
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  cpu {
    mode = "host-passthrough" # the VM sees the real CPU features (faster, recommended with nested KVM in WSL2)
  }

  disk {
    volume_id = libvirt_volume.disk[each.key].id
  }

  network_interface {
    network_id     = libvirt_network.ruo.id
    hostname       = each.key
    addresses      = [each.value.ip] # DHCP reservation = fixed address
    wait_for_lease = true            # apply waits until the VM really has its address
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

locals {
  # name => address, as reported by libvirt (the real address, not just the variable)
  vm_ips = { for name, vm in libvirt_domain.vm : name => vm.network_interface[0].addresses[0] }
  # role => address (one VM per role)
  ip_by_role = { for name, vm in var.vms : vm.role => local.vm_ips[name] }
}

# DO-6
# Grupe = role VMova; dns_server_ip govori svakom hostu gdje je DNS server
resource "local_file" "inventory" {
  filename        = "${path.module}/../../ansible/inventory.yml"
  file_permission = "0644"
  content = yamlencode({
    all = {
      vars = {
        ansible_user  = var.admin_user
        dns_server_ip = local.ip_by_role["dns"]
      }
      children = {
        for role in distinct([for vm in values(var.vms) : vm.role]) : role => {
          hosts = {
            for name, vm in var.vms : name => { ansible_host = local.vm_ips[name] } if vm.role == role
          }
        }
      }
    }
  })
}