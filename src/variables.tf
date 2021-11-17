variable whitelisted_ips {
  type        = list(string)
  default     = []
  description = "IP's that should be able to access the domain"
}

variable domain {
  type        = string
  description = "domain associated with the DNS that will point to your ALB, for example www.airbytepoc.com"
}

variable nginx_username {
  type        = string
  description = "username for basic http auth"
}

variable nginx_password {
  type        = string
  description = "password for basic http auth"
}

# variable airbyte_key_pair_name {
#   type    = string
#   default = "jumpbox"
# }

variable project_name {
  type        = string
  default     = "dip"
  description = "arbitrary prefix for resources"
}

variable stack_id {
  type        = string
  default     = "int"
  description = "arbitrary suffix for resources"
}

variable env_name {
  type        = string
  default     = "sandbox"
  description = "arbitrary aws environment name"
}
