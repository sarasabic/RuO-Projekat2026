variable "zone" {
  description = "Project zone, without the trailing dot"
  type        = string
  default     = "sarasabicdns.lab"
}

variable "ttl" {
  description = "TTL of all records in seconds"
  type        = number
  default     = 300
}

variable "tsig_key_name" {
  description = "Name of the TSIG key that may update the project zone"
  type        = string
  default     = "tf-key"
}

variable "tsig_secret" {
  description = "TSIG secret. Generated on vm-dns, fetched by Ansible to .secrets/ (not in Git); passed as TF_VAR_tsig_secret"
  type        = string
  sensitive   = true # never printed in plan/apply output
}

variable "services" {
  description = "Container name => fixed address. MUST match ipv4_address in app/compose.yaml (checked by a test in Milestone 5)"
  type        = map(string)
  default = {
    frontend = "10.30.1.10"
    backend  = "10.30.2.10"
    db       = "10.30.3.10"
  }
}