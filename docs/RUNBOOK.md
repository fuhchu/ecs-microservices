# Operations Runbook — ECS Microservices

Troubleshooting guide for the 3-service ECS Fargate platform. Organized by **plane** — when something breaks, first identify which plane it's in, then run that plane's first-line command.

**Conventions**
- Cluster: `ecs-msvc-dev-cluster` · Region: `us-west-2` · Services: `api-gateway`, `users`, `items`
- Replace `dev` with the target environment where applicable.
- Set once per session: `$CLUSTER = "ecs-msvc-dev-cluster"; $REGION = "us-west-2"`

## Triage: which plane is it?

```
Symptom first appears at...                  → Plane            → Jump to
ALB returns 5xx to the client                → Compute          → §2
A service can't talk to another service      → Network/Compute  → §1, §2
Task dies at startup before any app log      → Secrets/IAM      → §3
App logs appear, then a DB error             → Data/Network     → §1, §3
Failure started right after a deploy         → Delivery         → §4
```

**The golden distinction:**
- **"connection timed out"** = packet black-holed → security group or route table (§1)
- **"connection refused"** = reached host, nothing listening → app/container (§2)
- **error *before* app logs** = execution-role / secret injection (§3)
- **error *after* app logs** = app, credentials, or DB reachability (§1/§3)

---

## §1 — Network Plane

**Dependency chain**
```
VPC
 ├── Internet Gateway (attached to VPC)
 ├── Public subnets   → route table → IGW (0.0.0.0/0)
 ├── Private subnets  → route table → NAT Gateway (0.0.0.0/0)
 ├── NAT Gateway (in public subnet, needs EIP)
 └── Security groups: alb-sg → ecs-tasks-sg → rds-sg
```
A subnet is "private" **only** because its route table points `0.0.0.0/0` at a NAT instead of the IGW.

| Symptom | Likely cause | Diagnostic |
|---|---|---|
| Tasks stuck PENDING, never pull image | NAT down / EIP detached / private route missing | `aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc>` |
| `items` can't reach `users` (timeout) | ecs-tasks-sg missing 8000 from VPC CIDR | `aws ec2 describe-security-groups --group-ids <ecs-sg>` |
| App → RDS "connection timed out" | rds-sg ingress not referencing ecs-tasks-sg | confirm rds-sg source is the **SG ID**, not a CIDR |
| Whole AZ unreachable | single NAT (dev) and that AZ failed | check `single_nat_gateway` value |

**First-line commands**
```powershell
# Find the VPC
aws ec2 describe-vpcs --filters Name=tag:Project,Values=ecs-microservices --query "Vpcs[0].VpcId" --output text

# Are private subnets routed through a NAT?
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<vpc> `
  --query "RouteTables[].Routes[?DestinationCidrBlock=='0.0.0.0/0']"

# Inspect the RDS security group ingress (must reference ecs-tasks-sg)
aws ec2 describe-security-groups --filters Name=group-name,Values=ecs-msvc-dev-rds-sg `
  --query "SecurityGroups[0].IpPermissions"
```

---

## §2 — Compute Plane (Request Path)

**Dependency chain**
```
Internet → ALB (alb-sg) → listener :80 → gateway target group (health /health)
  → api-gateway task (registered target IP)
    → Cloud Map DNS (users.ecs-msvc.local / items.ecs-msvc.local)
      → users / items tasks   (items → users to validate)
```
Two independent registration systems: **ALB target group** (api-gateway only) and **Cloud Map** (all three). A task can be healthy in one and not the other.

| Symptom | Likely cause | Diagnostic |
|---|---|---|
| ALB 503 | no healthy targets | `describe-target-health` |
| ALB 504 | target reachable, app hangs | task CloudWatch logs |
| gateway up, `/users` 503 | Cloud Map not resolving users | users task RUNNING + registered |
| service keeps cycling | failing health check → circuit-breaker rollback | `describe-services` → `events[]` |
| `items` 503 on POST | users service down (sync validation) | check users task independently |

**The diagnostic ladder — stop at the first broken link**
```powershell
# 1. Healthy targets behind the ALB?
$TG = aws elbv2 describe-target-groups --names ecs-msvc-dev-gw-tg --query "TargetGroups[0].TargetGroupArn" --output text
aws elbv2 describe-target-health --target-group-arn $TG --query "TargetHealthDescriptions[].TargetHealth.State"

# 2. Service running count vs desired + recent events
aws ecs describe-services --cluster $CLUSTER --services api-gateway users items `
  --query "services[].{name:serviceName,running:runningCount,desired:desiredCount,rollout:deployments[0].rolloutState}" --output table

# 3. Why did a deploy fail? (last 10 events)
aws ecs describe-services --cluster $CLUSTER --services users --query "services[0].events[:10].message" --output text

# 4. App logs for a service
aws logs tail /ecs/ecs-msvc-dev/users --since 15m --follow
```

---

## §3 — Data & Secrets Plane

**Dependency chain**
```
random_password → RDS master password
              → Secrets Manager secret (JSON incl. database_url, built from RDS endpoint)
              → task def `secrets` block (valueFrom = secret ARN)
                 ↑ requires task EXECUTION role: secretsmanager:GetSecretValue
              → injected as DATABASE_URL at container start
              → app connects to RDS via rds-sg :5432
```
The secret **depends on RDS** (embeds the endpoint); the task **depends on the secret** (reads at boot). A partial apply can leave a task pointing at a **stale** secret.

| Symptom | Likely cause | Diagnostic |
|---|---|---|
| `ResourceInitializationError ... secrets` at startup | execution role lacks GetSecretValue, or wrong ARN | check iam policy + task def valueFrom |
| Task starts, app crashes on DB connect | database_url points at old RDS endpoint | compare secret `host` to live endpoint |
| "password authentication failed" | secret password ≠ RDS password (drift) | RDS recreated without secret update? |
| "connection timed out" to RDS | network, not secrets | see §1 |
| works in dev, fails in prod | prod secret never populated | confirm prod secret has a version |

**The key command — read what's actually in the secret and compare to live RDS**
```powershell
# What the app will receive
aws secretsmanager get-secret-value --secret-id ecs-msvc-dev-db-credentials --query SecretString --output text

# The live RDS endpoint
aws rds describe-db-instances --db-instance-identifier ecs-msvc-dev-db --query "DBInstances[0].Endpoint.Address" --output text
```
If the secret's `host` ≠ the live endpoint, the secret is **stale** (RDS was recreated, secret wasn't). Re-apply the `secrets` module or force a new secret version.

**Timing tells you the plane:** secrets error *before* any app log → execution role / secret. App log *then* DB error → network or credentials.

---

## §4 — Delivery Plane (Images & CI/CD)

**Dependency chain**
```
git push (services/<svc>/**)
  → GitHub Actions (path-filtered workflow)
    → OIDC assume ecs-msvc-dev-github-actions (trust scoped to repo + main)
    → docker build → push to ECR (tagged with git SHA)
    → register new task def revision (image = SHA)   [needs iam:PassRole]
    → update service → rolling deploy                [needs ecs:UpdateService, TagResource]
    → wait-for-service-stability (circuit breaker guards rollback)
```

| Symptom | Likely cause | Diagnostic |
|---|---|---|
| fails at AWS auth | OIDC trust mismatch (repo/branch in `sub`) | error names assumed-role; check oidc condition |
| "not authorized to perform ecs:X" | missing permission on GH Actions role | add the exact action to oidc policy |
| pipeline green, old code running | deployed `latest`, or ECS didn't pull | check task def image tag = new SHA |
| deploy succeeds then rolls back | new image fails health check | `describe-services` events + new task logs |
| wrong service deployed | path filter mismatch | check workflow `paths:` vs. changed files |

**Forensic command — what's actually running right now?**
```powershell
# Image the live task definition is using
$TD = aws ecs describe-services --cluster $CLUSTER --services users --query "services[0].taskDefinition" --output text
aws ecs describe-task-definition --task-definition $TD --query "taskDefinition.containerDefinitions[0].image" --output text
# → the tag is a git SHA → `git show <sha>` reveals the exact deployed code
```

---

## Emergency actions

```powershell
# Force a fresh deployment (re-pull image, replace tasks)
aws ecs update-service --cluster $CLUSTER --service <svc> --force-new-deployment --region $REGION

# Roll back to a previous task definition revision
aws ecs update-service --cluster $CLUSTER --service <svc> --task-definition ecs-msvc-dev-<svc>:<N> --region $REGION

# Scale a service to 0 (stop it) then back
aws ecs update-service --cluster $CLUSTER --service <svc> --desired-count 0 --region $REGION

# Tail logs across a service during an incident
aws logs tail /ecs/ecs-msvc-dev/<svc> --since 30m --follow
```

## Mental model summary

```
Delivery plane  ──deploys──>  Compute plane
     │                            │
     │ reads                      │ runs in
     ▼                            ▼
Secrets plane  <──endpoint──  Network plane  (foundation — everything sits on this)
```
Identify the plane first; each has a different first command. Walk the dependency chain and stop at the first link that doesn't connect.
