
variable "libvirt_uri" {
  description = "libvirt connection (system instance, as in the course examples)"
  type        = string
  default     = "qemu:///system"
}

variable "pool" {
  description = "libvirt storage pool for the disks (created by the course script 00-setup.sh)"
  type        = string
  default     = "default"
}

variable "base_image" {
  description = "Ubuntu 24.04 cloud image on the admin machine (downloaded once, DO-4)"
  type        = string
  default     = "~/.cache/ruo/noble-server-cloudimg-amd64.img"
}

variable "network_name" {
  description = "Name of the project's own libvirt network"
  type        = string
  default     = "ruo-net"
}

variable "network_cidr" {
  description = "Subnet of the VM network (DO-3); the host (WSL) acts as gateway/NAT"
  type        = string
  default     = "10.20.0.0/24"
}

variable "admin_user" {
  description = "Admin user created by cloud-init; Ansible logs in as this user"
  type        = string
  default     = "ruoadmin"
}

variable "ssh_public_key" {
  description = "Public key that may log in as admin_user"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vms" {
  description = "The VMs: name => role, fixed address and size."
  type = map(object({
    role    = string
    ip      = string
    memory  = number # MiB
    vcpu    = number
    disk_gb = number
  }))
  default = {
    vm-app = { role = "app", ip = "10.20.0.10", memory = 2048, vcpu = 2, disk_gb = 15 }
    vm-dns = { role = "dns", ip = "10.20.0.11", memory = 1024, vcpu = 1, disk_gb = 10 }
  }
}