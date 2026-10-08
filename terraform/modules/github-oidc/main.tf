variable "name_prefix" { type = string }
variable "github_repo" {
  type        = string
  description = "owner/repo"
}
variable "ecr_repository_arns" { type = list(string) }
variable "app_bucket_arn" { type = string }

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main", "repo:${var.github_repo}:pull_request"]
    }
  }
}

# Role 1: app deploy (least privilege)
resource "aws_iam_role" "app_deploy" {
  name               = "${var.name_prefix}-gha-app-deploy"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "app_deploy" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage"]
    resources = var.ecr_repository_arns
  }
  statement {
    actions   = ["ssm:PutParameter"]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.name_prefix}/image-tag"]
  }
  statement {
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:*::document/AWS-RunShellScript",
      "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }
  statement {
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${var.app_bucket_arn}/db/*"]
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  role   = aws_iam_role.app_deploy.id
  policy = data.aws_iam_policy_document.app_deploy.json
}

# Role 2: terraform (broad for the assessment; scope down in production)
resource "aws_iam_role" "terraform" {
  name               = "${var.name_prefix}-gha-terraform"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "terraform" {
  role       = aws_iam_role.terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "app_deploy_role_arn" { value = aws_iam_role.app_deploy.arn }
output "terraform_role_arn" { value = aws_iam_role.terraform.arn }
