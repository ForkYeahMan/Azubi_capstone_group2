# ACM — AWS Certificate Manager

## Certificate

| Field | Value |
|-------|-------|
| ARN | `arn:aws:acm:us-east-1:286664220957:certificate/3f82af42-4019-4f87-a67d-cceca2b9b4bb` |
| Primary Domain | `solarpanel.lol` |
| Status | **ISSUED** |
| Type | Amazon-issued (free, auto-renewed) |
| Key Algorithm | RSA-2048 |
| Signature | SHA-256 with RSA |
| Issued | 2026-06-10 |
| Expires | 2026-12-24 |
| Renewal Eligibility | Eligible (auto-renews ~60 days before expiry) |
| Transparency Logging | Enabled |

---

## Subject Alternative Names (SANs)

The certificate covers three names, all DNS-validated:

| Domain | Validation Status |
|--------|-------------------|
| `solarpanel.lol` | SUCCESS |
| `www.solarpanel.lol` | SUCCESS |
| `*.solarpanel.lol` | SUCCESS |

The wildcard `*.solarpanel.lol` covers any future subdomain (e.g. `api.solarpanel.lol`, `staging.solarpanel.lol`) without needing a new certificate.

---

## Validation Method

DNS validation was used — a CNAME record was added to the domain's DNS zone:

| Record Name | Type | Value |
|-------------|------|-------|
| `_576df34637582cf4e036d076bcc13ec7.solarpanel.lol` | CNAME | `_0fc70aef9ff92cf0cccd1801ddaa0328.jkddzztszm.acm-validations.aws` |

ACM checks this record to prove domain ownership. As long as the record stays in DNS, the certificate auto-renews without any manual action.

---

## Where It Is Used

| Resource | Purpose |
|----------|---------|
| CloudFront `E3MRCL1361H3LW` | Terminates HTTPS for `solarpanel.lol` and `www.solarpanel.lol` — this is the primary user-facing TLS endpoint |
| ALB `group-2-alb` (port 443) | HTTPS listener on the ALB for direct access if needed; uses policy `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` |

> **Note:** ACM certificates used with CloudFront **must** be in `us-east-1` regardless of where your other resources are. This certificate is in `us-east-1`, which satisfies that requirement and is also where the ALB lives.

---

## TLS Policy: `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`

The ALB's HTTPS listener uses AWS's most current post-quantum-safe TLS policy (2025). This policy:

- Supports TLS 1.3 and TLS 1.2 only (no 1.0/1.1)
- Includes hybrid post-quantum key exchange algorithms (X25519MLKEM768)
- Rejects all cipher suites below a minimum security level
