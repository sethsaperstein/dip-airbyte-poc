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
