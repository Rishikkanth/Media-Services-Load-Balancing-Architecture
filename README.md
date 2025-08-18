# Admin Force Close Endpoint (`/admin/force-close`)

The **Admin Force Close** endpoint is used by the **Drain Controller** or an operator to gracefully close all active WebSocket sessions on a node when it is being decommissioned.  
It ensures that long-lived connections do not block scale-in or shutdown operations.

---

## Endpoint

- **Method:** `POST`  
- **Path:** `/admin/force-close`  
- **Port:** `4001` (same as WebSocket server)  
- **Authentication:** Must require a secure token (e.g., signed JWT or IAM-auth header).  
- **Scope:** Accessible only inside the VPC; not exposed to the public internet.

---

## Example Request

```http
POST /admin/force-close HTTP/1.1
Host: media-node.internal:4001
Authorization: Bearer <signed_token>
Content-Type: application/json

