# Solar Technologies — Capstone Project

**Solar Technologies** is a smart farming platform that showcases autonomous solar-powered systems for agricultural monitoring, irrigation management, and precision analytics. Built as an Azubi Africa Cloud Engineering capstone project by Group 2.

> Live site: **[https://solarpanel.lol](https://solarpanel.lol)**

---

## What This Project Is

The application is a production-grade marketing and product site for a fictional solar-powered smart farming company. It demonstrates:

- A **Next.js 15 App Router** frontend with animated hero sections, product feature grids, testimonials, and a call-to-action — all built with Tailwind CSS and Framer Motion
- A **fully automated AWS infrastructure** including a custom VPC, multi-AZ EC2 deployment behind an Application Load Balancer, a CloudFront CDN with dual origins (S3 for static assets, ALB for HTML), ACM-issued SSL, and IAM least-privilege access controls
- A **four-stage CI/CD pipeline** using GitHub Actions that enforces code quality, security scanning, S3 asset upload, and rolling EC2 deployment on every merge to `main`

---

## Team — Group 2

| Name    | Role                      | AWS IAM User |
| ------- | ------------------------- | ------------ |
| Amartey | Cloud Architect / Lead    | `Amartey`    |
| Larry   | Cloud Architect           | `Larry`      |
| Loretta | Backend & DevOps Engineer | `Loretta`    |
| Akosa   | Frontend Engineer         | `Akosa`      |
| Bright  | Frontend Engineer         | `Bright`     |

---

## Architecture Diagram

```mermaid
graph TB
    User(["👤 User\nBrowser"])

    subgraph DNS["DNS — Domain Registrar"]
        CNAME["solarpanel.lol\nCNAME → d38cbgxb4o7hvr.cloudfront.net"]
    end

    subgraph CDN["AWS CloudFront  —  E3MRCL1361H3LW"]
        CF["CloudFront Distribution\nd38cbgxb4o7hvr.cloudfront.net\nAliases: solarpanel.lol, www.solarpanel.lol\nTLS: ACM cert (solarpanel.lol)"]
        ACM["ACM Certificate\nsolarpanel.lol\n*.solarpanel.lol\nwww.solarpanel.lol"]
    end

    subgraph S3Block["AWS S3"]
        S3["S3 Bucket\ngroup-2-286664220957-us-east-1-an\n/frontend/_next/static/*\nAES-256 encrypted"]
        OAC["Origin Access Control\nEK2C47MJ4D79Y\nSigV4 signed requests only"]
    end

    subgraph VPC["AWS VPC  —  group-2-vpc  10.0.0.0/16"]
        IGW["Internet Gateway\ngroup-2-igw"]
        RTB["Route Table group-2-rtb\n0.0.0.0/0 → IGW\n10.0.0.0/16 → local"]

        subgraph AZ1["Availability Zone  us-east-1a   10.0.1.0/24"]
            ALB1["ALB node"]
            EC2A["EC2: group-2-1\nt3.small\n10.0.1.35\nApache 2.4"]
        end

        subgraph AZ2["Availability Zone  us-east-1b   10.0.2.0/24"]
            ALB2["ALB node"]
            EC2B["EC2: group-2-2\nt3.small\n10.0.2.218\nApache 2.4"]
        end

        ALB["ALB  group-2-alb\nPort 80 → forward\nPort 443 → forward\nSG: CloudFront prefix only"]
        TG["Target Group\ngroup-2-tg-http\nHealth: GET / → 200"]
        ASG["Auto Scaling Group\nMin 1 / Desired 1 / Max 4\nLaunch Template: Group-2-Templates"]
    end

    subgraph CICD["GitHub Actions CI/CD"]
        GH["Push to main"]
        QC["code-quality.yml\nESLint · TypeScript · Prettier"]
        SEC["security.yml\nTruffleHog · pnpm audit"]
        DEP["deploy-s3-assets.yml\npnpm build → S3 sync → SSM → httpd restart"]
        SSM["AWS SSM Send-Command\nAWS-RunShellScript"]
    end

    subgraph IAM["IAM"]
        ROLE["EC2 Role\ngroup-2-ec2-ssm-role\nSSMManagedInstanceCore\nS3ReadFrontend"]
        CICDUSER["nextjs-cicd-deploy\nS3 frontend/* write\nSSM two instances only\nCF invalidate one distro"]
    end

    User -->|"HTTPS request\nsolarpanel.lol"| CNAME
    CNAME --> CF
    CF -->|"ACM terminates TLS"| ACM
    CF -->|"_next/static/* \nOAC SigV4"| OAC
    OAC --> S3
    CF -->|"All other paths\nHTTP port 80\nCloudFront prefix list only"| IGW
    IGW --> RTB
    RTB --> ALB
    ALB --> ALB1
    ALB --> ALB2
    ALB1 --> TG
    ALB2 --> TG
    TG -->|"Round-robin\nhealth checked"| EC2A
    TG -->|"Round-robin\nhealth checked"| EC2B
    ASG -.->|"Manages + registers\nnew instances"| TG
    EC2A <-->|"S3 sync\n/var/www/html/"| ROLE
    EC2B <-->|"S3 sync\n/var/www/html/"| ROLE
    ROLE --> S3
    GH --> QC
    GH --> SEC
    QC -->|"pass"| DEP
    SEC -->|"pass"| DEP
    DEP -->|"aws s3 sync\nSSE AES-256"| S3
    DEP --> SSM
    SSM -->|"s3 sync + httpd restart"| EC2A
    SSM -->|"s3 sync + httpd restart"| EC2B
    CICDUSER -->|"credentials"| DEP
```

---

## How Traffic Flows

Understanding how a browser request becomes a webpage helps explain why each AWS service exists:

1. **DNS** — The user types `solarpanel.lol`. Their browser queries DNS and receives a CNAME pointing to `d38cbgxb4o7hvr.cloudfront.net`. CloudFront's anycast network routes the request to the nearest edge location.

2. **CloudFront** — CloudFront holds the ACM TLS certificate and terminates HTTPS. The user never communicates directly with the ALB or EC2. CloudFront then decides which origin to fetch from based on the URL path:
   - `/_next/static/*` → **S3** (immutable assets, cached at the edge for 1 year)
   - Everything else → **ALB** (HTML, images, served fresh every request)

3. **S3 via OAC** — When fetching a JS or CSS bundle, CloudFront signs the request with SigV4 using the OAC. S3 validates the signature and confirms the request originates from the correct distribution before serving the file. The S3 bucket has no public access — only CloudFront can read `frontend/*`.

4. **ALB → EC2** — For HTML pages, CloudFront forwards the request over HTTP (port 80) to the ALB. The ALB's security group only accepts connections from CloudFront's origin-facing IP ranges (`pl-3b927c52`), blocking any direct browser-to-ALB access. The ALB round-robins requests between the two EC2 instances across `us-east-1a` and `us-east-1b`.

5. **Apache on EC2** — Apache serves the static Next.js HTML from `/var/www/html/`. The files were placed there by the last CI/CD deployment, synced from S3 via AWS SSM.

---

## How Deployments Work

When a developer merges a pull request to `main`:

```text
Code lands on main
        │
        ▼
┌───────────────────┐     ┌──────────────────────┐
│  code-quality.yml │     │    security.yml       │
│  • ESLint         │     │  • TruffleHog secrets │
│  • TypeScript     │     │  • pnpm audit --prod  │
│  • Prettier       │     │  • dependency-review  │
└────────┬──────────┘     └──────────┬───────────┘
         │  both pass                │
         └──────────────┬────────────┘
                        ▼
              deploy-s3-assets.yml
                        │
              ┌─────────▼──────────┐
              │   pnpm build       │
              │   next.js export   │
              │   → out/           │
              └─────────┬──────────┘
                        │
              ┌─────────▼──────────────────────────┐
              │   aws s3 sync out/_next/  (immutable)│
              │   aws s3 sync out/ (must-revalidate) │
              │   --sse AES256 --exact-timestamps    │
              └─────────┬──────────────────────────┘
                        │
              ┌─────────▼──────────────────────────┐
              │  SSM Send-Command → both EC2s      │
              │  aws s3 sync s3://bucket/frontend/ │
              │    /var/www/html/ --exact-timestamps│
              │  systemctl restart httpd            │
              └────────────────────────────────────┘
```

No CloudFront invalidation is needed. HTML is uploaded with `Cache-Control: max-age=0, must-revalidate` so CloudFront always fetches a fresh copy. JS/CSS filenames are content-hashed by Next.js so a changed file gets a new URL — old cached entries are never stale.

---

## Running Locally

**Prerequisites:** Node.js 20+, pnpm 10+

```bash
# 1. Clone the repository
git clone <repo-url>
cd Azubi_capstone_group2

# 2. Install dependencies
pnpm install

# 3. Start the development server
pnpm dev
```

Visit [http://localhost:3000](http://localhost:3000).

The dev server uses Next.js's built-in hot-reload. Changes to any file in `src/` are reflected immediately in the browser without a full refresh.

### Building for Production (static export)

```bash
pnpm build
```

This generates a fully static site in `out/`. You can serve it locally to verify the production build:

```bash
npx serve out/
```

### Code Quality

```bash
pnpm lint          # ESLint
pnpm type-check    # TypeScript (tsc --noEmit)
pnpm format        # Prettier check
pnpm format:fix    # Prettier auto-fix
```

---

## Infrastructure Documentation

Full documentation for every AWS service, IAM policy, and CI/CD workflow is in the [`docs/`](docs/) folder.

| Topic                                            | File                                                          |
| ------------------------------------------------ | ------------------------------------------------------------- |
| Architecture overview & service interconnections | [docs/README.md](docs/README.md)                              |
| VPC, Subnets, Route Tables, IGW                  | [docs/vpc-networking.md](docs/vpc-networking.md)              |
| Security Groups                                  | [docs/security-groups.md](docs/security-groups.md)            |
| EC2 Instances & Launch Template                  | [docs/ec2-instances.md](docs/ec2-instances.md)                |
| Auto Scaling Group                               | [docs/auto-scaling.md](docs/auto-scaling.md)                  |
| Target Group & ALB                               | [docs/alb-target-group.md](docs/alb-target-group.md)          |
| CloudFront Distribution                          | [docs/cloudfront.md](docs/cloudfront.md)                      |
| ACM Certificate                                  | [docs/acm.md](docs/acm.md)                                    |
| S3 Bucket & Policies                             | [docs/s3.md](docs/s3.md)                                      |
| IAM Users, Groups & Policies                     | [docs/iam.md](docs/iam.md)                                    |
| Codebase & CI/CD Workflow                        | [docs/codebase-workflow.md](docs/codebase-workflow.md)        |

---

## Tech Stack

| Layer           | Technology                             |
| --------------- | -------------------------------------- |
| Framework       | Next.js 15 (App Router, static export) |
| Language        | TypeScript 5                           |
| Styling         | Tailwind CSS 4                         |
| Animation       | Framer Motion                          |
| Package Manager | pnpm 10                                |
| CDN             | AWS CloudFront                         |
| Origin (HTML)   | AWS EC2 + Apache HTTPD 2.4             |
| Origin (Assets) | AWS S3 (OAC)                           |
| Load Balancer   | AWS Application Load Balancer          |
| TLS             | AWS ACM (auto-renewed)                 |
| CI/CD           | GitHub Actions                         |
| Secret Scanning | TruffleHog                             |
| Instance Access | AWS SSM Session Manager                |
