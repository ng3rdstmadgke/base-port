output "ingress_prd_sg" {
  value = aws_security_group.ingress_prd.id
}

output "ingress_dev_sg" {
  value = aws_security_group.ingress_dev.id
}

output "ingress_internal_sg" {
  value = aws_security_group.ingress_internal.id
}