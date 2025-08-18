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


