
output "vm_ips" {
  description = "VM name => IP address"
  value       = local.vm_ips
}

output "app_ip" {
  description = "Address of the application VM (the only public entry: http://<app_ip>/)"
  value       = local.ip_by_role["app"]
}

output "dns_ip" {
  description = "Address of the DNS server VM"
  value       = local.ip_by_role["dns"]
}

output "admin_user" {
  value = var.admin_user
}