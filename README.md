# Media Services Load Balancing Architecture

This repository contains the deliverables for the **DevOps Interview Assignment – Enhanced Media Services Load Balancing Architecture**.  
It demonstrates how to design and implement an AWS-based infrastructure that routes **WebSocket traffic** to dynamically scaling media service nodes, while maintaining security, availability, and zero downtime.

---

## 🎯 Objectives

- Route long-lived **WebSocket connections** (`wss://media.example.com/media/X/ws/{session-id}`) to the correct ECS task.
- Support **dynamic scaling** (1–10 nodes per shard).
- Achieve **zero downtime** during deployments and scaling.
- Provide **graceful connection draining** for WebSocket sessions.
- Ensure all traffic is **encrypted (TLS/ACM)** and nodes run in **private subnets**.
- Support **multiple environments** (Prod, Staging, Dev).

---

## 📂 Repository Structure

media-load-balancing/
├─ README.md # Overview (this file)
├─ docs/
│ ├─ architecture-diagram.pdf # AWS architecture diagram
│ ├─ technical-design.md # Detailed technical design (Part 1 deliverables)
│ └─ operations-runbook.md # Deployment, rollback, scaling, and health procedures
├─ Iac/
│ ├─ Terraform/ # Terraform IaC (primary implementation)
│ │ ├─ main.tf
│ │ ├─ variables.tf
│ │ ├─ outputs.tf
│ │ └─ modules/...
│ └─ cloudformation/ # Optional CloudFormation templates
│ ├─ alb.yml
│ ├─ ecs.yml
│ └─ dynamodb.yml
├─ automation/
│ ├─ lambda_drain_controller.py # Graceful WebSocket drain controller (Lambda)
│ ├─ lambda_registry_webhook.py # Optional: registry-driven ALB updater
│ ├─ register_on_start.sh # ECS task registration script
│ └─ deregister_on_stop.sh # ECS task deregistration script
└─ app/
├─ status_endpoint_stub.md # Contract for /status endpoint
└─ admin_force_close_stub.md # Contract for /admin/force-close endpoint
