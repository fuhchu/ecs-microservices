output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "ecs_tasks_sg_id" {
  description = "Security group shared by all ECS tasks — also used by the RDS module to scope DB ingress."
  value       = aws_security_group.ecs_tasks.id
}
