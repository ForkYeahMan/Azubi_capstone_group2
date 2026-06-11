# Security Groups

## Group-2-SG

| Field | Value |
|-------|-------|
| Name | `Group-2-SG` |
| Group ID | `sg-0ae5aec8d1bc6cb09` |
| VPC | `vpc-0d296b2612e167872` (group-2-vpc) |
| Description | Allow SSH, HTTP and HTTPS |

This single security group is shared by both the **ALB** and the **EC2 instances**. All inbound internet traffic to port 80 must originate from CloudFront's edge network.

---

## Inbound Rules

| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 80 | TCP | `pl-3b927c52` (AWS-managed prefix list) | CloudFront IPv4 origin-facing IPs |
| 80 | TCP | `sg-0ae5aec8d1bc6cb09` (self) | ALB → EC2 internal health checks |

### Why only CloudFront's prefix list?

AWS publishes and automatically maintains the managed prefix list `com.amazonaws.global.cloudfront.origin-facing` (`pl-3b927c52`). It contains the IP ranges that CloudFront uses to contact origin servers. By restricting port 80 to this list:

- Direct browser access to the ALB URL is blocked
- Scanners and attackers cannot bypass CloudFront (and its TLS enforcement, caching, and future WAF)
- AWS keeps the IP list current — no manual maintenance needed

The self-referencing rule (`sg-0ae5aec8d1bc6cb09 → sg-0ae5aec8d1bc6cb09`) allows the ALB to forward requests to EC2 instances on the same security group without opening a public CIDR.

### Removed rules (hardened during setup)

| Port | Was | Reason removed |
|------|-----|----------------|
| 22 (SSH) | `0.0.0.0/0` | Replaced by SSM Session Manager — no public SSH needed |
| 443 | `0.0.0.0/0` | CloudFront connects via HTTP port 80; public 443 on EC2 is unnecessary |
| 80 | `0.0.0.0/0` | Replaced by CloudFront prefix list |

---

## Outbound Rules

| Port | Protocol | Destination | Description |
|------|----------|-------------|-------------|
| All | All | `0.0.0.0/0` | Unrestricted egress |

Outbound is left open so EC2 instances can reach AWS services (S3, SSM Agent endpoints, package repos) without needing individual rules per service.

---

## Security Design Notes

- **No port 22 open** — instances are accessed via AWS Systems Manager Session Manager, which tunnels through the SSM Agent over HTTPS. This eliminates the attack surface of an exposed SSH port entirely.
- **Shared ALB + EC2 SG** — the self-referencing rule replaces the need for a separate ALB security group. This works because the ALB and instances are in the same group; the ALB's source IP is treated as a group member.
- **IPv6 CloudFront prefix** (`pl-02d12e369a4312e03`) was not added because the security group hit the per-SG rule quota when trying. CloudFront's origin traffic is primarily IPv4; this can be added if a quota increase is requested.
