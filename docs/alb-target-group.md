# Application Load Balancer & Target Group

## ALB

| Field | Value |
|-------|-------|
| Name | `group-2-alb` |
| ARN | `arn:aws:elasticloadbalancing:us-east-1:286664220957:loadbalancer/app/group-2-alb/4d3c213ef930c0aa` |
| DNS Name | `group-2-alb-1333830676.us-east-1.elb.amazonaws.com` |
| Scheme | `internet-facing` |
| Type | Application (Layer 7) |
| VPC | `vpc-0d296b2612e167872` |
| AZs | `us-east-1a` (`subnet-07424cf01d4ab25fb`), `us-east-1b` (`subnet-09a9816aff07475ff`) |
| Security Group | `sg-0ae5aec8d1bc6cb09` (Group-2-SG) |
| IP Address Type | IPv4 |
| Cross-zone LB | Enabled |
| HTTP/2 | Enabled |
| Idle Timeout | 60 seconds |
| Deletion Protection | Disabled |

---

## Listeners

### Port 80 — HTTP

| Field | Value |
|-------|-------|
| Listener ARN | `...b4cc9746679652f4` |
| Protocol | HTTP |
| Port | 80 |
| Default Action | **Forward** to `group-2-tg-http` |

> Port 80 forwards directly to EC2. There is **no HTTP → HTTPS redirect** on the ALB because CloudFront handles TLS termination and enforces HTTPS for all end users. The CloudFront → ALB leg travels over HTTP inside AWS's network, which is acceptable given the security group restricts port 80 to CloudFront's prefix list only.

### Port 443 — HTTPS

| Field | Value |
|-------|-------|
| Listener ARN | `...e9cf76a508c4a970` |
| Protocol | HTTPS |
| Port | 443 |
| SSL Certificate | `arn:aws:acm:us-east-1:286664220957:certificate/3f82af42-4019-4f87-a67d-cceca2b9b4bb` |
| SSL Policy | `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` (TLS 1.3 + PQ-safe) |
| Default Action | **Forward** to `group-2-tg-http` |

The HTTPS listener is available for direct ALB access when needed (e.g., internal tooling), backed by the same ACM certificate used by CloudFront.

---

## Target Group: `group-2-tg-http`

| Field | Value |
|-------|-------|
| ARN | `arn:aws:elasticloadbalancing:us-east-1:286664220957:targetgroup/group-2-tg-http/5e6c602d1ca1d365` |
| Protocol | HTTP |
| Port | 80 |
| Target Type | `instance` |
| VPC | `vpc-0d296b2612e167872` |

### Health Check Configuration

| Setting | Value |
|---------|-------|
| Protocol | HTTP |
| Path | `/` |
| Port | traffic-port (80) |
| Healthy threshold | 2 consecutive successes |
| Unhealthy threshold | 3 consecutive failures |
| Interval | 30 seconds |
| Timeout | 5 seconds |
| Success codes | `200` |

### Registered Targets

| Instance | Port | Health |
|----------|------|--------|
| `i-0213095b44ff10b77` (group-2-2) | 80 | **Healthy** |
| `i-0bb2773ea9a6be95b` (group-2-1) | 80 | **Healthy** |

Both instances pass health checks by serving `index.html` from Apache with a 200 response.

---

## Request Routing Flow

```
CloudFront (port 443 from user)
    │
    │  HTTP port 80  (CloudFront prefix list only)
    ▼
ALB Listener :80  →  Forward
    │
    ▼
Target Group: group-2-tg-http
    │  Round-robin
    ├── i-0bb2773ea9a6be95b :80  (us-east-1a)
    └── i-0213095b44ff10b77 :80  (us-east-1b)
```
