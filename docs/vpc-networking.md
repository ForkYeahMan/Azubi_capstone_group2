# VPC, Subnets, Route Tables & Internet Gateway

## VPC

| Field | Value |
|-------|-------|
| Name | `group-2-vpc` |
| VPC ID | `vpc-0d296b2612e167872` |
| CIDR Block | `10.0.0.0/16` (65,536 addresses) |
| Tenancy | Default |
| State | Available |
| Region | `us-east-1` |

The `/16` CIDR gives the project room to carve out multiple `/24` subnets across availability zones without address exhaustion. Default tenancy means instances run on shared hardware — appropriate for a web workload.

---

## Subnets

Two subnets, one per availability zone, enabling high availability. Both are in the same VPC but isolated to different AZs so a failure in `us-east-1a` does not take down `us-east-1b`.

| Name | Subnet ID | CIDR | AZ | Auto-assign Public IP |
|------|-----------|------|----|-----------------------|
| `group-2-subnet` | `subnet-07424cf01d4ab25fb` | `10.0.1.0/24` | `us-east-1a` | No |
| `group-2-subnet-2` | `subnet-09a9816aff07475ff` | `10.0.2.0/24` | `us-east-1b` | No |

**Why auto-assign public IP is off:** EC2 instances have Elastic IPs / public IPs assigned at launch, but the subnet itself does not auto-assign them. All inbound internet traffic reaches the instances through the ALB, not directly.

---

## Internet Gateway

| Field | Value |
|-------|-------|
| Name | `group-2-igw` |
| IGW ID | `igw-033a9b4bc9ef6fd6d` |
| Attached VPC | `vpc-0d296b2612e167872` |
| State | Available |

The IGW is the single egress/ingress point between the VPC and the public internet. Without it, resources inside the VPC cannot reach or be reached from the internet.

---

## Route Tables

Two route tables exist in the VPC.

### Main Route Table (default, implicit)

| Route Table ID | Association |
|----------------|-------------|
| `rtb-0b2312108d0147b88` | Main (implicit for any subnet not explicitly associated) |

| Destination | Target | Purpose |
|-------------|--------|---------|
| `10.0.0.0/16` | `local` | VPC-internal traffic stays inside the VPC |

This table has no internet route — any subnet falling back to the main table cannot reach the internet.

### Public Route Table (`group-2-rtb`)

| Route Table ID | Associated Subnets |
|----------------|--------------------|
| `rtb-0bafb5a4b037e09d4` | `subnet-07424cf01d4ab25fb` (us-east-1a), `subnet-09a9816aff07475ff` (us-east-1b) |

| Destination | Target | Purpose |
|-------------|--------|---------|
| `10.0.0.0/16` | `local` | VPC-internal routing |
| `0.0.0.0/0` | `igw-033a9b4bc9ef6fd6d` | All other traffic exits via the Internet Gateway |

Both application subnets are explicitly associated with `group-2-rtb`, giving the ALB and EC2 instances internet connectivity.

---

## Network Topology Diagram

```
Internet
    │
    ▼
Internet Gateway (group-2-igw)
    │
    ▼
VPC: group-2-vpc  10.0.0.0/16
    ├── Route Table: group-2-rtb
    │       10.0.0.0/16 → local
    │       0.0.0.0/0   → igw
    │
    ├── Subnet: group-2-subnet   10.0.1.0/24  (us-east-1a)
    │       ALB node, EC2 group-2-1 (10.0.1.35)
    │
    └── Subnet: group-2-subnet-2  10.0.2.0/24  (us-east-1b)
            ALB node, EC2 group-2-2 (10.0.2.218)
```
