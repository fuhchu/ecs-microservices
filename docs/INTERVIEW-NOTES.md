# Interview Notes — ECS Microservices

Target roles: DevOps Engineer, Cloud Engineer

---

## Containers & ECS

**Q: Walk me through how a request gets from the internet to your database.**

The client hits the ALB's public DNS on port 80. The ALB forwards to the api-gateway Fargate task in a private subnet. The gateway resolves `items.ecs-msvc.local` via Cloud Map DNS and proxies the request to the items service. Items calls the users service the same way to validate the user exists, then opens a PostgreSQL connection to RDS — also in a private subnet — using a connection string injected from Secrets Manager at task start. Nothing in that chain is publicly reachable except the ALB.

---

**Q: Why Fargate instead of EC2-backed ECS?**

Fargate removes the EC2 layer entirely — no AMI management, no patching, no capacity planning for the underlying hosts. You define CPU and memory per task and AWS handles placement. The tradeoff is cost: Fargate is more expensive per vCPU-hour than a right-sized EC2 instance. At scale, teams often mix: Fargate for bursty/low-volume workloads, EC2 Auto Scaling groups with Savings Plans for steady-state high-volume services.

---

**Q: What happens when you deploy a new version of the users service?**

GitHub Actions builds a new image tagged with the git SHA, pushes it to ECR, registers a new task definition revision with the updated image URI, then calls `UpdateService` pointing at the new revision. ECS performs a rolling deployment: it starts a new task, waits for it to pass the `/health` check and register healthy with Cloud Map, then stops the old task. `wait-for-service-stability: true` in the pipeline blocks until this completes. If the new task fails health checks, the deployment circuit breaker triggers an automatic rollback to the previous task definition revision — and the pipeline job fails, giving a clear signal.

---

**Q: How does the deployment circuit breaker work?**

It's configured with `enable = true, rollback = true` on the ECS service. ECS monitors the rolling deployment — if a configurable threshold of tasks fail to reach a steady state (fail health checks or crash), it automatically rolls back to the last stable task definition revision. You don't have to detect the failure and trigger a rollback manually. In Project 1 I validated this by deliberately deploying a broken image and confirming the service rolled back automatically with zero downtime.

---

**Q: Your tasks are in private subnets with no public IP. How do they pull images from ECR?**

Via the NAT gateway. Private subnet tasks route outbound traffic through the NAT gateway in the public subnet, which has an Elastic IP and can reach the internet. ECR is an AWS-managed registry accessible over HTTPS — the task pulls the image through NAT. An alternative is VPC endpoints for ECR, which keeps the traffic on the AWS private network entirely and removes the NAT dependency for image pulls — better for security posture and eliminates NAT data processing charges for large images.

---

## Secrets & Security

**Q: How do you keep database credentials out of your codebase?**

Terraform generates the password using the `random` provider — no human ever types it. RDS is provisioned with that password, and the full connection string is stored as JSON in Secrets Manager. The ECS task definition references the secret's ARN with a JSON key selector (`database_url`). At task start, the ECS agent — using the execution role's scoped `secretsmanager:GetSecretValue` permission — fetches the value and injects it as the `DATABASE_URL` environment variable. The app reads it via `os.environ`. The credential never appears in source control, container images, task definition plaintext, or logs.

---

**Q: What's the difference between the ECS execution role and the task role?**

The execution role is the ECS agent's identity — it's used before your code runs to pull the container image from ECR, write logs to CloudWatch, and fetch secrets from Secrets Manager. The task role is your application's identity at runtime — what your code can do against AWS APIs (S3, DynamoDB, SQS, etc.). Separating them enforces least privilege: a vulnerability in the application can't necessarily read secrets or push to ECR, because those permissions live on the execution role, not the task role.

---

**Q: Why does your IAM policy for GitHub Actions use `"*"` for `ecr:GetAuthorizationToken`?**

`GetAuthorizationToken` is an account-level API — it doesn't operate on a specific repository resource, it returns a short-lived token for the entire registry. AWS doesn't support resource-level restrictions for it, so `"*"` is the only valid option. All the actual image operations (push, pull, list layers) are scoped to the specific ECR repository ARNs. This is a known AWS limitation documented in the ECR IAM reference.

---

**Q: How is your OIDC setup scoped to prevent other repos from assuming the role?**

The trust policy has two conditions: `aud` must equal `sts.amazonaws.com` (GitHub's required audience), and `sub` must match `repo:fuhchu/ecs-microservices:ref:refs/heads/main`. The `sub` condition means only workflows running on the `main` branch of this specific repo can assume the role. A workflow in a different repo, or a PR branch in this repo, gets denied. This prevents lateral movement in a shared AWS account where multiple repos use OIDC.

---

## Networking

**Q: Why do you have separate security groups for the ALB and the ECS tasks?**

Defense in depth. The ALB SG allows inbound 80/443 from `0.0.0.0/0` — it's public-facing. The ECS tasks SG allows inbound 8000 only from the VPC CIDR — not from the internet. Even if someone bypassed the ALB, they couldn't reach the tasks directly from outside the VPC. The RDS SG goes further: it allows 5432 only from the ECS tasks SG ID (not a CIDR range), meaning only the app tasks can reach the database — not other resources that might exist in the same VPC.

---

**Q: Why does dev use one NAT gateway and prod use two?**

Cost vs. availability. Each NAT gateway costs ~$32/month plus data processing. One NAT in dev cuts that cost in half, with the accepted tradeoff that if the NAT's AZ goes down, private subnet tasks in both AZs lose outbound connectivity. In prod, each private subnet routes through a NAT in its own AZ — an AZ failure only affects tasks in that AZ, not the whole service. There's also a cost efficiency angle: cross-AZ data transfer is billed; with one NAT, tasks in the other AZ pay cross-AZ charges on every ECR pull and AWS API call.

---

## Service Discovery

**Q: How do your services find each other?**

AWS Cloud Map with a private DNS namespace `ecs-msvc.local`. Each ECS service is configured with a `service_registries` block pointing at a Cloud Map service. When ECS starts a task, it registers the task's private IP as an A record — e.g. `users.ecs-msvc.local`. When tasks are replaced during deploys, ECS updates the DNS records automatically. The items service calls `http://users.ecs-msvc.local:8000` — it always resolves to healthy task IPs regardless of how many times tasks have been cycled.

---

**Q: Cloud Map vs. an internal ALB for service-to-service traffic — when would you choose each?**

Cloud Map is DNS-based and cheap — no extra infrastructure, just a registry and DNS records. It's right for direct service-to-service calls where you want simple resolution and client-side load balancing. An internal ALB adds L7 features: path-based routing, connection draining on deploys (in-flight requests complete gracefully before the old task stops), sticky sessions, and centralized health-check visibility. If you have a service with long-lived connections or complex routing needs, an internal ALB is worth the ~$16/month. For straightforward REST calls between services at this scale, Cloud Map is sufficient and costs nothing beyond the namespace.

---

## Terraform & Infrastructure as Code

**Q: How do you manage dev and prod with the same Terraform?**

One root module, two `.tfvars` files. Every cost/HA lever — NAT count, RDS instance class, Multi-AZ, task count — is a typed variable with a safe (cheap) default. `dev.tfvars` accepts most defaults; `prod.tfvars` overrides the HA-sensitive ones. You apply with `-var-file=dev.tfvars` or `-var-file=prod.tfvars`. The benefit over separate `environments/` directories is zero config drift — both environments are provably running the same logic.

---

**Q: Why store Terraform state in S3?**

Local state breaks in any team or CI/CD context — two people applying simultaneously corrupt the state file. S3 remote state is shared, versioned (S3 versioning recovers from accidental corruption), and encrypted at rest. I use S3-native locking (`use_lockfile = true`) instead of a DynamoDB table — it achieves the same mutual exclusion with one less resource to manage, and it's available since Terraform 1.9.

---

**Q: Your Terraform state contains the database password. Is that a problem?**

It's a known limitation of Terraform with generated secrets — any `random_password` result ends up in state. The mitigation is treating state as sensitive: the S3 bucket has encryption enabled, access is restricted to the IAM role used for Terraform operations, and S3 versioning is on for recovery. The password itself is never in source control or the application image. In a stricter environment you'd use a separate secrets bootstrap process (e.g. generate the password outside Terraform, store it in Secrets Manager, and reference the ARN in Terraform without the value ever touching state).

---

## CI/CD

**Q: Why does each service have its own pipeline instead of one shared pipeline?**

Path filtering. Each pipeline triggers only on changes to its own `services/<name>/` directory. Pushing a change to the users service doesn't rebuild or redeploy items and api-gateway — they're unaffected. A shared pipeline would either rebuild all three on every push (wasteful, slower, higher blast radius for a deploy failure) or need complex conditional logic to determine what changed. Separate files are explicit and independently configurable.

---

**Q: Why SHA-tag images instead of using `latest`?**

Traceability and safety. If a deploy causes a production incident, you can look at the running ECS task definition, see the image tag (a git SHA), run `git show <sha>` and know exactly what code is running. With `latest` you have no idea which version is deployed without checking ECR metadata. SHA tags are also immutable by convention — you can't accidentally overwrite a deployed image. `latest` is a mutable pointer that can drift, which makes rollbacks ambiguous.

---

**Q: How does the Terraform infra pipeline avoid applying unreviewed changes?**

The pipeline triggers on both push and pull_request events for `infra/**`. On a PR it runs `terraform plan` and posts the output as a PR comment — reviewers see exactly what will be created, changed, or destroyed before approving. The `apply` step has a condition: `if: github.event_name == 'push' && github.ref == 'refs/heads/main'` — it only runs after the PR is merged. Plan on review, apply on merge. This is the standard GitOps pattern for infrastructure.

---

## What's Missing / What I'd Add Next

Being able to articulate gaps shows production maturity:

- **HTTPS** — The ALB listener is wired to redirect to 443 when `acm_certificate_arn` is set. Blocked on owning a domain to issue an ACM cert.
- **ALB access logs** — Every request logged to S3 for audit and forensics. One `access_logs` block away.
- **AWS WAF** — Rate limiting and OWASP managed rules in front of the ALB.
- **RDS deletion protection + final snapshot** — Flipped off for dev teardown convenience; prod tfvars would enable both.
- **Secrets Manager rotation** — A Lambda rotation function on a schedule so the DB password rotates without app downtime.
- **One DB per service** — True microservice isolation; currently users and items share one RDS instance. Separate instances or at minimum separate schemas would reduce blast radius.
- **Async inter-service communication** — Items currently calls users synchronously. SQS/SNS would decouple them so a users outage doesn't cascade to items.
- **Observability** — CloudWatch Container Insights is on. Next layer: structured logging, custom metrics, and distributed tracing (X-Ray) to correlate requests across services.
