terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "seth-saperstein"
    workspaces {
      name = "dip-airbyte-poc"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "airbyte_instance" {
  name        = "airbyte-sg"
  description = "Sg for hosting Airbyte"
  vpc_id      = var.vpc_id

  ingress = [
    {
      description      = "allow alb traffic"
      from_port        = 8000
      to_port          = 8000
      protocol         = "tcp"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = [aws_security_group.airbyte_lb.id]
      self             = false
    }
  ]

  egress = [
    {
      description      = "All traffic out"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

data "template_file" "airbyte" {
  template = file("scripts/startup.sh")
  vars     = {}
}

resource "aws_instance" "this" {
  ami                         = "ami-02e136e904f3da870"
  instance_type               = "t2.medium"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.airbyte_instance.id]
  user_data                   = data.template_file.airbyte.rendered
  key_name                    = var.airbyte_key_pair_name
  tags = {
    Name = "airbyte"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "airbyte-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.this.id
  port             = 8000
}

resource "aws_security_group" "airbyte_lb" {
  name        = "airbyte-tg-sg"
  description = "Sg for Airbyte ALB"
  vpc_id      = var.vpc_id

  ingress = [
    {
      description      = "allow whitelisted IPs"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = var.whitelisted_ips
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
    {
      description      = "allow whitelisted IPs"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = var.whitelisted_ips
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "All traffic out"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

resource "aws_lb" "this" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.airbyte_lb.id]
  subnets            = var.subnets
}

resource "aws_lb_listener" "airbyte" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
