# Status Endpoint Stub (`/status`)

The media node exposes a lightweight HTTP endpoint `/status` on port `4001`.  
This endpoint is used by:

- **ALB health checks** – to determine whether the node is healthy.
- **Drain Controller** – to monitor the number of active WebSocket connections.
- **Operators** – to validate node health manually during troubleshooting.

---

## Example Response

```json
{
  "node_id": "ip-10-0-3-42",
  "path": "/media/1",
  "status": "ACTIVE",
  "active_connections": 14,
  "uptime_seconds": 3921,
  "timestamp": "2025-08-18T14:21:00Z"
}

