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
