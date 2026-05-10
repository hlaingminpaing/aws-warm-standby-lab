variable "primary_region" {
  description = "The AWS region for the active production environment"
  type        = string
  default     = "ap-southeast-1"
}

variable "standby_region" {
  description = "The AWS region for the warm standby environment"
  type        = string
  default     = "ap-southeast-7"
}

variable "domain_name" {
  description = "The domain name for the Route 53 hosted zone (e.g., example.com)"
  type        = string
  default     = "myanmartechacademy.com"
}

variable "create_dns_records" {
  description = "Set to true if you have a valid Route 53 Hosted Zone for the domain_name and want to create the failover records."
  type        = bool
  default     = false
}

variable "db_master_password" {
  description = "Master password for the Aurora Global Database"
  type        = string
  sensitive   = true
  default     = "SuperSecret123!"
}
