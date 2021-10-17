variable vpc_id {
    type = string
}

variable whitelisted_ips {
    type = list(string)
    default = []
}

variable subnets {
    type = list(string)
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
