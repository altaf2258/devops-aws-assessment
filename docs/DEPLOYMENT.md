# Deployment & Configuration Guide

Companion to the root [README](../README.md). This document covers how to configure, deploy, operate and tear down the stack.

- **Project:** `devops-assessment`  **Environment:** `dev`  **Region:** `ap-south-1`
- **Resource name prefix:** `devops-assessment-dev`

---

## 1. Prerequisites

| Tool / item | Version / note |
|---|---|
| AWS account | Admin-level access for the first apply |
| AWS CLI | v2, configured (`aws configure` or SSO) |
| Terraform | >= 1.5 (AWS provider >= 5.0, random provider >= 3.5) |
| Git + GitHub account | Repository: `altaf2258/devops-aws-assessment` |
| ACM certificate | In `ap-south-1`, for the HTTPS listener (DNS-validated for a real domain, or imported for testing) |
| Docker | Only for local testing; CI builds the images |

Verify:
```bash
aws sts get-caller-identity
terraform version
```

---

## 2. One-time bootstrap: Terraform state backend

The state bucket is created manually (it cannot be managed by the configuration that uses it).

```bash
aws s3api create-bucket --bucket devops-aws-assessment-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning --bucket devops-aws-assessment-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket devops-aws-assessment-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block --bucket devops-aws-assessment-terraform-state \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Backend configuration (`terraform/environments/dev/main.tf`):
```hcl
backend "s3" {
  bucket  = "devops-aws-assessment-terraform-state"
  key     = "dev/terraform.tfstate"
  region  = "ap-south-1"
  encrypt = true
}
```
State contains the generated DB password, so the bucket is encrypted, versioned, private and access-controlled.

---

## 3. Configuration reference

### 3.1 Root module inputs (`terraform/environments/dev/variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `ap-south-1` | AWS region |
| `environment` | `dev` | Environment name |
| `project_name` | `devops-assessment` | Used in names and tags |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR |
| `availability_zones` | `ap-south-1a`, `ap-south-1b` | AZs used by all tiers |
| `github_repo` | none (required) | `owner/repo`, trusted by the OIDC roles |
| `certificate_arn` | none (required) | ACM certificate for the ALB HTTPS listener |

Set them in `terraform.tfvars` (git-ignored; copy from `terraform.tfvars.example`).

### 3.2 Network layout

| Tier | Subnets | Route to internet |
|---|---|---|
| Public | `10.0.1.0/24`, `10.0.2.0/24` | Internet Gateway |
| Private app | `10.0.11.0/24`, `10.0.12.0/24` | NAT Gateway in the same AZ |
| Private DB | `10.0.21.0/24`, `10.0.22.0/24` | None |

### 3.3 Security groups

| SG | Inbound | Outbound |
|---|---|---|
| `alb-sg` | 443 and 80 from `0.0.0.0/0` | 80 and 3000 to `app-sg` |
| `app-sg` | 80 and 3000 from `alb-sg` | 443 to internet (via NAT), 3306 to `rds-sg` |
| `rds-sg` | 3306 from `app-sg` | none |

### 3.4 Module summary

| Module | Key resources | Notable settings |
|---|---|---|
| `vpc` | VPC, 6 subnets, IGW, 2 NAT GWs + EIPs, route tables | One NAT per AZ for HA |
| `security-groups` | 3 SGs, rules by SG reference | No SSH rule anywhere |
| `iam` | EC2 role, instance profile | SSM core, secret read, ECR pull, SSM parameter read, app bucket access |
| `s3` | App bucket, ALB logs bucket | Public access blocked, TLS-only, versioning (app), 90-day log expiry |
| `secrets-manager` | Secret + generated password | 24 chars, JSON with host/port/user/password/dbname |
| `rds` | MySQL 8.0, subnet group | Multi-AZ, encrypted, private, 7-day backups, CloudWatch log exports |
| `alb` | ALB, 2 target groups, 2 listeners, path rule | HTTP to HTTPS 301, TLS 1.3/1.2 policy, access logs to S3 |
| `asg` | Launch template, ASG, CPU scaling policy, SSM image-tag parameter | IMDSv2, encrypted gp3, min 2 / max 4, ELB health checks |
| `ecr` | `devops-assessment-dev-backend`, `-frontend` | Scan on push, keep last 10 images |
| `github-oidc` | OIDC provider, 2 IAM roles | Trust limited to this repository |

### 3.5 Load balancer routing

| Rule | Match | Target |
|---|---|---|
| Default (HTTPS) | everything else | frontend target group, port 80 (health check `/`) |
| Priority 10 | `/api/*`, `/health` | backend target group, port 3000 (health check `/health`) |
| HTTP :80 | all | 301 redirect to HTTPS |

### 3.6 Key resource names

| Item | Name |
|---|---|
| DB secret | `devops-assessment-dev/db-credentials` |
| Image tag parameter | `/devops-assessment-dev/image-tag` |
| App bucket | `devops-assessment-dev-app-<account-id>` |
| ALB log bucket | `devops-assessment-dev-alb-logs-<account-id>` |
| ASG | `devops-assessment-dev-asg` |
| CI roles | `devops-assessment-dev-gha-app-deploy`, `devops-assessment-dev-gha-terraform` |

---

## 4. Deployment procedure

### 4.1 Prepare
```bash
git clone https://github.com/altaf2258/devops-aws-assessment.git
cd devops-aws-assessment/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars`:
```hcl
github_repo     = "altaf2258/devops-aws-assessment"
certificate_arn = "arn:aws:acm:ap-south-1:<account-id>:certificate/<id>"
```

Certificate options:
- **Real domain:** request a public certificate in ACM and validate it by DNS.
- **Testing without a domain:** import a self-signed certificate (`aws acm import-certificate`). Browsers will show a warning.

### 4.2 Validate
```bash
terraform fmt -recursive ../../
terraform init
terraform validate
terraform plan -out=tfplan
```
Expected result: `Plan: 75 to add, 0 to change, 0 to destroy.`

### 4.3 Apply (first run is manual)
The CI roles are created by Terraform, so the first apply is run locally.
```bash
terraform apply tfplan
terraform output
```
Duration is about 15 to 20 minutes (RDS Multi-AZ and NAT Gateways take longest).

### 4.4 Configure GitHub
Repository, Settings, Secrets and variables, Actions, **Variables**:

| Variable | Source |
|---|---|
| `APP_DEPLOY_ROLE_ARN` | `terraform output app_deploy_role_arn` |
| `TERRAFORM_ROLE_ARN` | `terraform output terraform_role_arn` |
| `APP_BUCKET` | `terraform output app_bucket_name` |
| `CERTIFICATE_ARN` | ACM certificate ARN |
| `APP_URL` (optional) | `https://<domain-or-alb-dns>` for the post-deploy health check |

No AWS access keys are stored anywhere in GitHub. Optional notification secrets are listed in section 5.2.

### 4.5 Deploy the application
Push a change under `app/`, or run **Actions, App Build & Deploy, Run workflow**.

### 4.6 Verify
```bash
ALB=$(terraform output -raw alb_dns_name)
curl -k https://$ALB/health          # {"status":"ok"}
curl -k -I https://$ALB/             # HTTP 200
```
Also confirm in the console: both target groups show healthy targets, and ALB access logs appear under `s3://<logs-bucket>/alb/AWSLogs/...`.

---

## 5. CI/CD pipelines

### 5.1 `terraform.yml` (infrastructure)

| Event | Steps |
|---|---|
| Pull request touching `terraform/**` | Trivy IaC scan (report only), then `fmt -check`, `init`, `validate`, `plan` |
| Push to `main` touching `terraform/**` | the above, then `apply` of the saved plan |
| Manual | `workflow_dispatch` |

Authenticates by assuming `devops-assessment-dev-gha-terraform` through OIDC.

### 5.2 `app-deploy.yml` (application CI/CD)

| Stage | Job | What happens |
|---|---|---|
| 1. Checkout and secret scan | `secret-scan` | Full-history checkout, **Gitleaks** scan. Any leaked secret fails the pipeline. |
| 2. Build | `build-scan-push` | `docker build` for `backend` and `frontend` (matrix, run in parallel). |
| 3. Image scan | `build-scan-push` | **Trivy** scans each image. HIGH/CRITICAL vulnerabilities that have a fix fail the job, before anything is pushed. |
| 4. Push | `build-scan-push` | Assume `devops-assessment-dev-gha-app-deploy` via OIDC, push `<git-sha>` and `latest` tags to ECR. |
| 5. Deploy | `deploy` | Upload `init.sql` to S3, write the SHA to SSM `/devops-assessment-dev/image-tag`, run `/opt/deploy.sh` on instances tagged `Name=devops-assessment-dev-app` via SSM Run Command, **one at a time** (`--max-concurrency 1`, `--max-errors 0`), then an optional health check against `APP_URL`. |
| 6. Notify | `notify` | Runs always. Sends the overall result to **Microsoft Teams** (incoming webhook) and/or **email** (SMTP), with a link to the run. |

Pull requests run stages 1 to 3 only (no AWS credentials, no push, no deploy). Concurrent deployments are serialised with a `concurrency` group.

**Notification setup** (GitHub, Settings, Secrets and variables, Actions, **Secrets**; each channel is skipped if its secrets are absent):

| Secret | Purpose |
|---|---|
| `TEAMS_WEBHOOK_URL` | Teams channel, Workflows, "Post to a channel when a webhook request is received" |
| `SMTP_USERNAME` | Sender address (for Gmail, the account email) |
| `SMTP_PASSWORD` | SMTP password (for Gmail, an app password, which requires 2-step verification) |
| `NOTIFY_EMAIL` | Recipient address |

GitHub also emails the repository owner on failed workflow runs by default.

### 5.3 What `/opt/deploy.sh` does on each instance
1. Reads the image tag from SSM.
2. Logs in to ECR and pulls both images.
3. Reads DB credentials from Secrets Manager.
4. Applies `init.sql` from S3 (failures tolerated, so it is safe to re-run).
5. Restarts the `backend` (port 3000) and `frontend` (port 80) containers on a shared Docker network.

New instances created by Auto Scaling run the same script at boot (retrying while waiting for the first image), so scale-out always uses the current release.

### 5.4 Rollback
Set the image-tag parameter to a previous commit SHA and re-run the deploy command:
```bash
aws ssm put-parameter --name /devops-assessment-dev/image-tag \
  --type String --value <previous-sha> --overwrite
```
Then re-run the workflow, or send `/opt/deploy.sh` through SSM Run Command. The last 10 images are retained in ECR.

---

## 6. Operations

| Task | How |
|---|---|
| Shell access | `aws ssm start-session --target <instance-id>` (no SSH, no key pair) |
| App logs | `docker logs backend` / `docker logs frontend` on the instance |
| Boot log | `/var/log/cloud-init-output.log` |
| Scale manually | Change `min_size` / `max_size` / `desired_capacity` in the `asg` module |
| Rotate DB password | Change the secret, update RDS, then re-run the deploy |
| Infra changes | Open a pull request, review the plan, merge to apply |

---

## 7. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `Unsupported argument` / `Missing required argument` in a module call | Module `variables.tf` and the call in `environments/dev/main.tf` are out of sync |
| `vars map does not contain key ...` in `templatefile` | `user_data.sh.tpl` uses a variable not passed from `asg/main.tf` |
| Apply fails: OIDC provider already exists | The account already has a GitHub OIDC provider. Use a `data` source instead of creating one |
| Apply fails on the HTTPS listener | Certificate ARN invalid or in another region |
| Targets unhealthy right after apply | No image pushed yet. Run the app-deploy workflow |
| GitHub Action fails at "Configure AWS credentials" | Role ARN variable missing, or `github_repo` in tfvars does not match the repository exactly |
| SSM command finds no instances | Instances not yet registered with SSM, or the `Name` tag does not match `<prefix>-app` |
| Image pull fails on EC2 | Instance role lacks ECR access, or the NAT route is missing |
| `/health` returns 404 | Add the health route to `server.js` and redeploy |

---

## 8. Teardown
```bash
cd terraform/environments/dev
terraform destroy
```
S3 buckets and ECR repositories are configured with force-destroy for this assessment, and the DB secret has no recovery window. The state bucket is kept. Approximate running cost while deployed is a few US dollars per day (2 NAT Gateways, ALB, Multi-AZ RDS, 2 instances), so destroy after testing.

---

## 9. Known limitations and production hardening

- Images are tagged by commit SHA and scanned before push; consider ECR tag immutability, image signing, and pinning Trivy and action versions by digest.
- Scope the Terraform CI role down from `AdministratorAccess`.
- Replace the tolerated-failure `init.sql` step with a migration tool.
- Add VPC endpoints (ECR, S3, Secrets Manager, SSM) to remove NAT dependency and cost.
- Add WAF on the ALB, CloudWatch alarms and dashboards, and RDS-managed password rotation.
- Enable deletion protection and secret recovery windows for production.
- Split state per environment and add a staging/production promotion flow.
