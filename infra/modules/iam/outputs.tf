output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_execution_role_id" {
  value = aws_iam_role.task_execution.id
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
