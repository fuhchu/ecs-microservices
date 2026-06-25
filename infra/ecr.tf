resource "aws_ecr_repository" "service" {
  for_each = toset(local.services)

  name                 = "ecs-microservices/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # dev: allow destroy even with images present

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "ecs-microservices-${each.key}" }
}

# Keep only the last 10 images per repo to control storage cost.
resource "aws_ecr_lifecycle_policy" "service" {
  for_each   = aws_ecr_repository.service
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
