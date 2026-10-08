variable "name_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  repos = ["backend", "frontend"]
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(local.repos)
  name                 = "${var.name_prefix}-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # assessment only

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

output "repository_arns" { value = [for r in aws_ecr_repository.this : r.arn] }
output "repository_urls" { value = { for k, r in aws_ecr_repository.this : k => r.repository_url } }
