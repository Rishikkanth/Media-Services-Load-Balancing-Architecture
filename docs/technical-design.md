# Technical Design Document – Media Services Load Balancing Architecture

## 1. Overview

This document describes the **AWS-based infrastructure design** for routing **WebSocket traffic** to dynamically scaling media service nodes.  
The goal is to provide secure, resilient, and transparent routing of long-lived connections, without requiring the main application to know about the load balancing internals.

The design addresses **Load Balancing Strategy, Dynamic Registration, Scaling Operations, and High Availability**, per assignment requirements.

---

## 2. Load Balancing Strategy

### Path-based Routing
- Each node owns a **path namespace** (e.g., `/media/1/*`, `/media/2/*`, …).
- **Application Load Balancer (ALB)** routes requests based on these path patterns.
- Each path is associated with a **Target Group (TG)**, and ECS tasks register with the correct TG.

### SSL/TLS Termination
- **ACM Certificates** (`media.example.com`, `*.stg.example.com`, `*.dev.example.com`) attached to the ALB listener.
- TLS 1.2+ enforced, ensuring all external traffic is encrypted.
- Internal traffic (ALB → ECS tasks) runs over private VPC networking.

### Security
- **AWS WAF** filters inbound traffic (SQLi/XSS, rate limiting).
- **CloudFront** provides global edge delivery and shields ALB.
- ECS tasks run in **private subnets** with no public IPs.
- Outbound internet access via **NAT Gateway** for pulling images/updates.

---

## 3. Dynamic Registration

### New Node Startup
1. ECS task starts in private subnet.
2. Lifecycle script `register_on_start.sh` runs:
   - Writes node ID, assigned path, and status (`ACTIVE`) to **DynamoDB registry**.
   - Optionally triggers a **Lambda webhook** to ensure ALB listener rules/weights are updated.
3. Task reports `/status` endpoint for health and active connections.

### Routing Update
- ALB Target Group health checks `/status`.
- Once healthy, ALB begins routing new WebSocket connections to the node’s path.

### Node Shutdown
1. Task lifecycle hook (`deregister_on_stop.sh`) sets node status to `DRAINING` in DynamoDB.
2. **Drain Controller Lambda**:
   - Sets ALB weight to 0 (no new connections).
   - Waits until `active_connections=0`.
   - Deregisters task and stops it gracefully.
   - If timeout exceeds (e.g., 2h), calls `/admin/force-close`.

---

## 4. Scaling Operations

### Scale-Up
- Triggered by **CloudWatch alarm** (e.g., high `ActiveConnections`).
- ECS Desired Count increases.
- New task registers via startup script, added to registry, and starts accepting connections.

### Scale-Down
- Triggered by low usage.
- ECS Desired Count decreases.
- Drain Controller initiates graceful WebSocket draining for the retiring task.
- Ensures **no existing connections are dropped**.

### Zero Downtime
- ALB listener rules updated only after nodes pass health checks.
- **Connection draining logic** ensures sockets close gracefully before node removal.

---

## 5. High Availability

### Failure Detection
- **CloudWatch Alarms** monitor:
  - ECS task health
  - ALB target health
  - Registry consistency
- If a node fails health checks:
  - ALB stops routing to it.
  - Registry status updated to `FAILED`.

### Traffic Reassignment
- When a node fails:
  - Registry reassigns the path to a healthy node (or spawns a replacement).
  - ALB updates its listener rule accordingly.

### Multi-Environment Support
- Separate ALBs, ACM certs, and DNS records for:
  - **Prod** (`media.example.com`)
  - **Staging** (`media-stg.example.com`)
  - **Dev** (`media-dev.example.com`)
- Isolated ECS clusters/services per environment.

---

## 6. Beyond 10 Node Limitation

- The system supports **up to 10 paths per shard** (due to assignment constraint).
- To scale beyond 10 nodes:
  - Introduce **multiple shards** (`Shard A`, `Shard B`, …).
  - Each shard has its own ALB, TGs, and ECS service (up to 10 nodes).
  - Registry allocates sessions to shards using **consistent hashing** or **load-aware assignment**.
  - URLs remain consistent (`media.example.com`), with shard selection handled internally (via path rewrite or routing hint).

---

## 7. Security Considerations

- All ECS tasks run in **private subnets**.
- **IAM roles** scoped to least privilege (ECS task role only allows DynamoDB table access).
- **CloudFront + WAF** provide DDoS protection and request filtering.
- **Logging & Audit**:
  - ALB access logs to S3.
  - ECS task logs to CloudWatch.
  - DynamoDB table streams for registry changes.

---

## 8. Monitoring & Observability

- **CloudWatch Metrics**
  - `ActiveConnections` (from `/status`)
  - `TargetGroupHealthyHostCount`
  - `ECSServiceRunningTaskCount`
- **Alarms**
  - Scale-out when `ActiveConnections > threshold`.
  - Scale-in when usage drops below threshold.
  - Alert on unhealthy tasks or high 5xx errors.
- **Notifications**
  - Alarms publish to **SNS topics** (alerts to ops team).

---

## 9. Summary of AWS Services Used

- **Networking**: VPC, NAT Gateway, Internet Gateway, Private/Public Subnets
- **Compute**: ECS Fargate
- **Load Balancing**: ALB (path-based), Route 53
- **Security**: AWS WAF, ACM, Security Groups
- **Scalability**: CloudWatch, Application Auto Scaling, EventBridge
- **Registry**: DynamoDB
- **Automation**: Lambda (Drain Controller, Registry Webhook)
- **Monitoring**: CloudWatch Logs, Metrics, Alarms, SNS

---

## 10. Assumptions & Constraints

- Maximum 10 nodes per shard (assignment constraint).
- WebSocket connections are long-lived (hours).
- Clients handle reconnect logic when receiving `503` (node draining) or WS Close frame.
- IaC samples provided via Terraform and CloudFormation (not exhaustive, but demonstrate key resources).

---

## 11. Appendix – Flow Summary

1. Client requests session → application allocates path `/media/X`.
2. Client connects `wss://media.example.com/media/X/ws/{session-id}`.
3. Route 53 → CloudFront → WAF → ALB → TG → ECS task.
4. On scale-in:
   - Task marked `DRAINING` → stops accepting new sockets.
   - Existing connections allowed to drain.
   - ECS stops task after drain or timeout.
5. On scale-out:
   - New ECS task starts, registers path, joins routing.
6. On failure:
   - ALB deregisters unhealthy task.
   - Registry reassigns path to healthy task.

---
