variable whitelisted_ips {
    type = list(string)
    default = []
}

variable airbyte_key_pair_name {
    type = string
    default = "jumpbox"
}

variable project_name {
    type = string
    default = "dip"
}

variable stack_id {
    type = string
    default = "int"
}

variable env_name {
    type = string
    default = "sandbox"
}

variable certificate_arn {
    type = string
}

variable nginx_username {
    type = string
}

variable nginx_password {
    type = string
}
