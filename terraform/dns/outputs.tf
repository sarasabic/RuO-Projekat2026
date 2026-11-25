output "records" {
  description = "All names managed by Terraform"
  value = concat(
    [for name in keys(dns_a_record_set.vm) : "${name}.${var.zone}"],
    [for name in keys(dns_a_record_set.service) : "${name}.${var.zone}"],
    ["www.${var.zone}"],
  )
}