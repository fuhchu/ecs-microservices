# ECS Microservices

Three-service microservices architecture on AWS ECS Fargate with RDS PostgreSQL, Secrets Manager, and multi-environment Terraform.

## Services

| Service | Port | Responsibility |
|---|---|---|
| api-gateway | 8000 | Public entry point; proxies to users and items |
| users | 8000 | User CRUD; owns the `users` table in RDS |
| items | 8000 | Item CRUD; owns the `items` table; validates users via service call |

## Architecture

> Diagram coming after Terraform infra milestone.

## Local Development

```bash
# Each service
cd services/<name>
pip install -r requirements.txt
DATABASE_URL=postgresql://... USERS_SERVICE_URL=http://localhost:8001 uvicorn app.main:app --reload
```

## Infrastructure

See `infra/` for Terraform — VPC, RDS, Secrets Manager, ECR, ECS, ALB.
