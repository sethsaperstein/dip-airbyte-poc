output "this_lb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "DNS to access Airbyte"
}
