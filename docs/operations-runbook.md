# Operations Runbook – Media Services Load Balancing Architecture

This runbook provides the standard operational procedures for deploying, scaling, draining, and validating the **Media Services Load Balancing Architecture** on AWS.

---

## 1. Deployment Process

### 1.1 Prerequisites
- AWS account access with IAM permissions for ECS, ALB, DynamoDB, CloudWatch, Lambda.
- ACM certificate issued for `media.example.com` (and `*.stg`, `*.dev`).
- VPC with:
  - Private subnets (ECS tasks)
  - Public subnets (ALB, NAT Gateway)

### 1.2 Deployment Steps
1. **Build & Push Application Image**
   ```bash
   docker build -t <ecr_repo>:<tag> .
   docker push <ecr_repo>:<tag>

