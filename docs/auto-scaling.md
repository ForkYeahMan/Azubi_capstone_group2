# Auto Scaling Group

## Configuration

| Field | Value |
|-------|-------|
| Name | `group-2-alb` |
| ARN | `arn:aws:autoscaling:us-east-1:286664220957:autoScalingGroup:9e550da9-cb2e-4f44-9b52-7e3e23777c0a:autoScalingGroupName/group-2-alb` |
| Launch Template | `Group-2-Templates` (`lt-0553607b55dd9c189`) v1 |
| Min Capacity | 1 |
| Desired Capacity | 1 |
| Max Capacity | 4 |
| Availability Zones | `us-east-1a`, `us-east-1b` |
| Subnets | `subnet-07424cf01d4ab25fb`, `subnet-09a9816aff07475ff` |
| Health Check Type | ELB |
| Health Check Grace Period | 300 seconds |
| Default Cooldown | 300 seconds |
| AZ Distribution Strategy | `balanced-best-effort` |
| Scale-in Protection | Disabled |

---

## Target Group Attachment

The ASG is directly attached to the target group:

```
group-2-alb (ASG) → group-2-tg-http (Target Group)
```

New instances launched by the ASG are automatically registered into the target group and start receiving traffic once they pass health checks.

---

## Health Check Behaviour

The ASG uses **ELB health checks** (not EC2 status checks). This means:

- A new instance must pass the ALB's HTTP health check (`GET /` → 200) before being marked `InService`
- The 300-second grace period gives the instance time to boot and for Apache to start serving content before health checks begin
- If an instance fails health checks after the grace period, the ASG terminates it and launches a replacement

---

## Current Running Instances

| Instance ID | AZ | State | Launch Template Version |
|-------------|-----|-------|------------------------|
| `i-0ca04a4c495654234` | `us-east-1b` | InService / Healthy | v1 |

> Note: The two manually provisioned instances (`group-2-1` and `group-2-2`) are registered in the target group but are not part of the ASG's managed instance list. The ASG currently manages one separate instance.

---

## Scaling Policy

No scheduled or metric-based scaling policies are currently configured. The ASG acts as a **self-healing mechanism** — if the managed instance fails, the ASG launches a replacement automatically. To add CPU-based auto-scaling:

```bash
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name group-2-alb \
  --policy-name cpu-scale-out \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration '{
    "PredefinedMetricSpecification": {"PredefinedMetricType": "ASGAverageCPUUtilization"},
    "TargetValue": 60.0
  }'
```

---

## Capacity Distribution

`balanced-best-effort` means the ASG tries to maintain equal instance counts across `us-east-1a` and `us-east-1b`. If one AZ is unavailable, it launches all instances in the remaining AZ rather than failing.
