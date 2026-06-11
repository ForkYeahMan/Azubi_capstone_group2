# CloudFront Distribution

## Distribution Summary

| Field | Value |
|-------|-------|
| Distribution ID | `E3MRCL1361H3LW` |
| Domain Name | `d38cbgxb4o7hvr.cloudfront.net` |
| Status | Deployed |
| Custom Aliases | `solarpanel.lol`, `www.solarpanel.lol` |
| HTTP Version | HTTP/2 |
| Price Class | `PriceClass_100` (US, Canada, Europe — lowest cost tier) |
| ACM Certificate | `arn:aws:acm:us-east-1:286664220957:certificate/3f82af42-4019-4f87-a67d-cceca2b9b4bb` |
| Minimum TLS | 1.2 (SNI only) |
| OAC | `EK2C47MJ4D79Y` (group-2-s3-oac) |

---

## Origins

### Origin 1 — S3 Static Assets

| Field | Value |
|-------|-------|
| Origin ID | `group-2-s3-frontend` |
| Domain | `group-2-286664220957-us-east-1-an.s3.us-east-1.amazonaws.com` |
| Origin Path | `/frontend` |
| Protocol | S3 (OAC signed requests) |
| OAC ID | `EK2C47MJ4D79Y` |

CloudFront uses Origin Access Control (OAC) to sign every request to S3 using SigV4. The S3 bucket policy only accepts requests that carry the correct `aws:SourceArn` matching this distribution, so objects cannot be fetched from S3 directly without going through CloudFront.

The `/frontend` origin path is prepended to all requests routed to this origin, so a browser request for `/_next/static/chunks/app.js` becomes an S3 key lookup for `frontend/_next/static/chunks/app.js`.

### Origin 2 — ALB (EC2)

| Field | Value |
|-------|-------|
| Origin ID | `alb-group-2` |
| Domain | `group-2-alb-1333830676.us-east-1.elb.amazonaws.com` |
| Origin Path | — |
| Protocol | HTTP only (port 80) |

CloudFront connects to the ALB on port 80. TLS is terminated at CloudFront; the CloudFront → ALB segment travels over HTTP inside AWS infrastructure. The ALB security group restricts port 80 to CloudFront's managed prefix list, so this path is not accessible from the public internet.

---

## Cache Behaviors

Behaviors are evaluated top-to-bottom. The first match wins.

### Behavior 1 — `_next/static/*` → S3

| Setting | Value |
|---------|-------|
| Path Pattern | `_next/static/*` |
| Origin | `group-2-s3-frontend` (S3 via OAC) |
| Viewer Protocol | Redirect HTTP → HTTPS |
| Cache Policy | `Managed-CachingOptimized` (`658327ea-f89d-4fab-a63d-7e88639e58f6`) |
| Compress | Yes |

Next.js content-hashes every JS and CSS filename on build (e.g. `185ddf0e-b4fa84cf2ac1bbb8.js`). The hash changes whenever the file content changes. This makes it safe to cache these files for 1 year — a stale URL literally cannot exist because a changed file gets a new URL.

`Managed-CachingOptimized` sets `Cache-Control: max-age=31536000, immutable` and enables Gzip/Brotli compression.

### Default Behavior — `*` → ALB

| Setting | Value |
|---------|-------|
| Path Pattern | `*` (default) |
| Origin | `alb-group-2` (EC2 via ALB) |
| Viewer Protocol | Redirect HTTP → HTTPS |
| Cache Policy | `UseOriginCacheControlHeaders` (`83da9c7e-98b4-4e11-a168-04f0df8e2c65`) |
| Compress | Yes |

`UseOriginCacheControlHeaders` passes through whatever `Cache-Control` header Apache sets. The deploy workflow sets `Cache-Control: public, max-age=0, must-revalidate` on HTML files, so CloudFront always revalidates HTML against the origin on each request. This means users see fresh HTML immediately after a deployment without needing a CloudFront invalidation.

---

## DNS Configuration

The domain registrar has two CNAME records:

| Name | Type | Value |
|------|------|-------|
| `@` (solarpanel.lol) | CNAME | `d38cbgxb4o7hvr.cloudfront.net` |
| `www` | CNAME | `d38cbgxb4o7hvr.cloudfront.net` |

Both aliases are registered on the distribution, so CloudFront serves both `solarpanel.lol` and `www.solarpanel.lol` from the same distribution.

---

## OAC vs OAI

This distribution uses **Origin Access Control (OAC)**, not the legacy Origin Access Identity (OAI). OAC is the current AWS-recommended approach because:

- Supports SigV4 signing (stronger than OAI's unsigned S3 headers)
- Works with SSE-KMS encrypted buckets
- Required for new S3 features (Object Lambda, etc.)
