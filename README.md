# Terraform Microservices Platform Infrastructure

> Production-grade AWS infrastructure for microservices — custom VPC, RDS, Auto Scaling, ALB, CloudWatch, and more.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Infrastructure Components](#infrastructure-components)
  - [VPC & Networking](#vpc--networking)
  - [Application Load Balancer (ALB)](#application-load-balancer-alb)
  - [Auto Scaling Group (ASG)](#auto-scaling-group-asg)
  - [RDS (Relational Database Service)](#rds-relational-database-service)
  - [CloudWatch Monitoring & Alerts](#cloudwatch-monitoring--alerts)
  - [IAM Roles & Security Groups](#iam-roles--security-groups)
- [Variables Reference](#variables-reference)
- [Outputs Reference](#outputs-reference)
- [Getting Started](#getting-started)
- [Environments](#environments)
- [Tagging Strategy](#tagging-strategy)
- [Security Considerations](#security-considerations)
- [Cost Optimization](#cost-optimization)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │   Route 53     │  (DNS)
                    └───────┬────────┘
                            │
                    ┌───────▼────────┐
                    │  ALB (Public)  │  Multi-AZ
                    └──┬─────────┬──┘
                       │         │
              ┌────────▼──┐  ┌───▼────────┐
              │ Target    │  │  Target    │
              │ Group A   │  │  Group B   │
              └────┬──────┘  └──────┬─────┘
                   │                │
        ┌──────────▼────────────────▼──────────┐
        │         Auto Scaling Group            │
        │  ┌─────────┐  ┌─────────┐            │
        │  │  EC2    │  │  EC2    │  ...        │
        │  │ (AZ-1a) │  │ (AZ-1b) │            │
        │  └────┬────┘  └────┬────┘            │
        └───────┼────────────┼─────────────────┘
                │            │
        ┌───────▼────────────▼─────────┐
        │     Private Subnets (VPC)    │
        │  ┌─────────────────────────┐ │
        │  │     RDS Multi-AZ        │ │
        │  │  Primary  |  Standby    │ │
        │  └─────────────────────────┘ │
        └──────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │    CloudWatch      │
              │  Logs | Metrics    │
              │  Alarms | Dashbd   │
              └────────────────────┘
```

**Key Design Principles:**

- **Multi-AZ** deployment across at least 2 Availability Zones for high availability
- **Private subnets** for application instances and database — no direct internet exposure
- **Public subnets** only for the ALB and NAT Gateways
- **CloudWatch** centralized observability for all resources
- **Auto Scaling** responds to CPU and request-count metrics automatically

---

## Prerequisites

| Tool | Minimum Version | Install |
|------|----------------|---------|
| Terraform | `>= 1.5.0` | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | `>= 2.13` | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |
| AWS Account | — | IAM user with appropriate permissions |

**Required AWS IAM Permissions:**

The Terraform executing role/user needs at minimum:

- `ec2:*` — VPC, subnets, security groups, instances, ALB
- `rds:*` — RDS cluster creation and management
- `autoscaling:*` — Auto Scaling Groups and policies
- `elasticloadbalancing:*` — ALB/NLB management
- `cloudwatch:*` — Alarms, dashboards, metrics
- `logs:*` — CloudWatch Log Groups
- `iam:*` — Roles, policies, instance profiles
- `sns:*` — Alert notification topics

---

## Project Structure

```
terraform-microservices/
├── main.tf                    # Root module entrypoint, provider config
├── variables.tf               # All input variable declarations
├── outputs.tf                 # Output values exported after apply
├── terraform.tfvars           # Default variable values (non-sensitive)
├── versions.tf                # Provider version constraints
│
├── modules/
│   ├── vpc/
│   │   ├── main.tf            # VPC, subnets, IGW, NAT GW, route tables
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── alb/
│   │   ├── main.tf            # ALB, listeners, target groups, rules
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── asg/
│   │   ├── main.tf            # Launch template, ASG, scaling policies
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── rds/
│   │   ├── main.tf            # RDS instance, subnet group, parameter group
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── cloudwatch/
│   │   ├── main.tf            # Alarms, log groups, dashboards
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── security/
│       ├── main.tf            # Security groups, IAM roles, KMS keys
│       ├── variables.tf
│       └── outputs.tf
│
└── environments/
    ├── dev/
    │   └── terraform.tfvars
    ├── staging/
    │   └── terraform.tfvars
    └── prod/
        └── terraform.tfvars
```

---

## Infrastructure Components

### VPC & Networking

**Module:** `modules/vpc`

Creates an isolated virtual network with a clear public/private subnet split across multiple Availability Zones.

**Resources Created:**

| Resource | Description |
|----------|-------------|
| `aws_vpc` | Main VPC with DNS hostnames and DNS resolution enabled |
| `aws_subnet` (public) | One per AZ — for ALB and NAT Gateways |
| `aws_subnet` (private-app) | One per AZ — for EC2 application instances |
| `aws_subnet` (private-db) | One per AZ — isolated DB tier |
| `aws_internet_gateway` | Outbound internet for public subnets |
| `aws_nat_gateway` | Allows private subnets outbound internet (one per AZ) |
| `aws_route_table` | Separate route tables for public and private tiers |
| `aws_vpc_flow_log` | VPC Flow Logs shipped to CloudWatch |

**Example Configuration (`modules/vpc/main.tf`):**

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-vpc"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private_app" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-private-app-${count.index + 1}"
    Tier = "application"
  })
}

resource "aws_subnet" "private_db" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 8)
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-private-db-${count.index + 1}"
    Tier = "database"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-igw"
  })
}

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-nat-${count.index + 1}"
  })
}

resource "aws_flow_log" "vpc" {
  iam_role_arn    = var.flow_log_role_arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}
```

---

### Application Load Balancer (ALB)

**Module:** `modules/alb`

Internet-facing ALB distributes traffic across microservice target groups with path-based and host-based routing rules.

**Resources Created:**

| Resource | Description |
|----------|-------------|
| `aws_lb` | Application Load Balancer (internet-facing) |
| `aws_lb_listener` (HTTP) | Port 80 — redirects to HTTPS |
| `aws_lb_listener` (HTTPS) | Port 443 — SSL termination, forwards to target groups |
| `aws_lb_target_group` | One per microservice with health checks |
| `aws_lb_listener_rule` | Path-based routing rules (e.g., `/api/*`, `/auth/*`) |
| `aws_wafv2_web_acl_association` | WAF protection on the ALB |

**Example Configuration (`modules/alb/main.tf`):**

```hcl
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = "alb-logs"
    enabled = true
  }

  tags = var.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

resource "aws_lb_target_group" "services" {
  for_each = var.microservices

  name        = "${var.project}-${var.environment}-${each.key}"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = each.value.health_check_path
    matcher             = "200-299"
  }

  tags = var.common_tags
}

resource "aws_lb_listener_rule" "service_routing" {
  for_each     = var.microservices
  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.routing_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}
```

---

### Auto Scaling Group (ASG)

**Module:** `modules/asg`

Manages EC2 capacity for microservice instances with target tracking and step scaling policies, tied to CloudWatch alarms.

**Resources Created:**

| Resource | Description |
|----------|-------------|
| `aws_launch_template` | EC2 instance configuration, user data, IAM profile |
| `aws_autoscaling_group` | ASG with multi-AZ distribution |
| `aws_autoscaling_policy` (CPU) | Target tracking — maintains 60% average CPU |
| `aws_autoscaling_policy` (ALB RPS) | Scales on ALB request count per target |
| `aws_autoscaling_schedule` | Scheduled scaling for predictable traffic patterns |

**Example Configuration (`modules/asg/main.tf`):**

```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project}-${var.environment}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = var.instance_profile_arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_security_group_id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      iops                  = 3000
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_id
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true  # Detailed monitoring
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    environment    = var.environment
    project        = var.project
    log_group_name = var.log_group_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = var.common_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project}-${var.environment}-asg"
  vpc_zone_identifier = var.private_app_subnet_ids
  target_group_arns   = var.target_group_arns

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_cooldown          = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, {
      Name = "${var.project}-${var.environment}-app"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Target Tracking: CPU
resource "aws_autoscaling_policy" "cpu_tracking" {
  name                   = "${var.project}-${var.environment}-cpu-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

# Target Tracking: ALB Request Count
resource "aws_autoscaling_policy" "alb_request_tracking" {
  name                   = "${var.project}-${var.environment}-alb-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }
    target_value = 1000.0
  }
}
```

---

### RDS (Relational Database Service)

**Module:** `modules/rds`

Multi-AZ RDS instance with automated backups, encryption at rest, enhanced monitoring, and Parameter Group tuning.

**Resources Created:**

| Resource | Description |
|----------|-------------|
| `aws_db_instance` | Primary RDS instance (Multi-AZ enabled) |
| `aws_db_subnet_group` | DB subnet group using private-db subnets |
| `aws_db_parameter_group` | Custom parameter group for tuning |
| `aws_db_option_group` | Optional — for engine-specific options |
| `aws_secretsmanager_secret` | Stores DB credentials, rotated automatically |
| `aws_iam_role` | Enhanced monitoring IAM role |

**Example Configuration (`modules/rds/main.tf`):**

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  })
}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-pg"
  family = var.db_parameter_group_family  # e.g., "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
  parameter {
    name  = "log_duration"
    value = "1"
  }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = var.common_tags
}

resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-db"

  engine         = var.db_engine         # e.g., "postgres"
  engine_version = var.db_engine_version # e.g., "15.4"
  instance_class = var.db_instance_class # e.g., "db.t3.medium"

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [var.db_security_group_id]

  # Storage
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.rds_kms_key_id

  # High Availability
  multi_az = var.environment == "prod" ? true : false

  # Backups
  backup_retention_period   = var.environment == "prod" ? 30 : 7
  backup_window             = "02:00-03:00"
  maintenance_window        = "Mon:03:00-Mon:04:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  # Protection
  deletion_protection       = var.environment == "prod" ? true : false
  skip_final_snapshot       = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project}-${var.environment}-final-snapshot" : null

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  auto_minor_version_upgrade = true
  apply_immediately          = var.environment == "prod" ? false : true

  tags = var.common_tags
}

# Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project}/${var.environment}/db/credentials"
  kms_key_id              = var.secrets_kms_key_id
  recovery_window_in_days = 30

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.main.username
    password = random_password.db.result
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = aws_db_instance.main.db_name
  })
}
```

---

### CloudWatch Monitoring & Alerts

**Module:** `modules/cloudwatch`

Centralized observability — log groups, metric alarms, composite alarms, and an operational dashboard.

**Resources Created:**

| Resource | Description |
|----------|-------------|
| `aws_cloudwatch_log_group` | Separate log group per microservice + VPC Flow Logs |
| `aws_cloudwatch_metric_alarm` | ALB 5xx, CPU high/low, RDS connections, disk I/O |
| `aws_cloudwatch_composite_alarm` | Composite "service degraded" alarm |
| `aws_cloudwatch_dashboard` | Unified operational dashboard |
| `aws_sns_topic` | Alert notification topic |
| `aws_sns_topic_subscription` | Email/PagerDuty/Slack webhook subscriptions |

**Example Configuration (`modules/cloudwatch/main.tf`):**

```hcl
# Log Groups
resource "aws_cloudwatch_log_group" "app" {
  for_each = var.microservices

  name              = "/app/${var.project}/${var.environment}/${each.key}"
  retention_in_days = var.environment == "prod" ? 90 : 14
  kms_key_id        = var.logs_kms_key_id

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project}-${var.environment}/flow-logs"
  retention_in_days = 30
  tags              = var.common_tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-${var.environment}-alerts"
  kms_master_key_id = var.sns_kms_key_id
  tags              = var.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ALB — 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx-high"
  alarm_description   = "ALB 5XX error rate is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 10

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "5XX Error Rate (%)"
    return_data = true
  }
  metric_query {
    id = "m1"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }
  metric_query {
    id = "m2"
    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      period      = 60
      stat        = "Sum"
      dimensions  = { LoadBalancer = var.alb_arn_suffix }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# EC2 CPU High Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-ec2-cpu-high"
  alarm_description   = "EC2 average CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 85

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# RDS — CPU High Alarm
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.project}-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is too high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# RDS — Low Free Storage Alarm
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${var.project}-${var.environment}-rds-low-storage"
  alarm_description   = "RDS free storage space is critically low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120  # 5 GB in bytes

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# RDS — DB Connections High Alarm
resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "${var.project}-${var.environment}-rds-connections-high"
  alarm_description   = "RDS database connections are approaching limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = var.rds_max_connections_threshold

  dimensions = {
    DBInstanceIdentifier = var.db_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# ALB — Target Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.project}-${var.environment}-alb-latency-high"
  alarm_description   = "ALB target response time is too high (P99 > 2s)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 2.0

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# Composite Alarm — Service Degraded
resource "aws_cloudwatch_composite_alarm" "service_degraded" {
  alarm_name        = "${var.project}-${var.environment}-service-degraded"
  alarm_description = "Composite alarm: service is degraded (high 5xx AND high latency)"

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.alb_5xx_high.alarm_name}) AND ALARM(${aws_cloudwatch_metric_alarm.alb_latency_high.alarm_name})"

  alarm_actions = [aws_sns_topic.alerts.arn]
  tags          = var.common_tags
}

# Operational Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}-operations"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "ALB — Request Count & Error Rate"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix]
          ]
          view = "timeSeries"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "EC2 — CPU Utilization (ASG)"
          period = 60
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Average" }],
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name, { stat = "Maximum" }]
          ]
          view = "timeSeries"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS — CPU & Connections"
          period = 60
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_identifier]
          ]
          view = "timeSeries"
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "ALB — Target Response Time (P50, P99)"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99" }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}
```

---

### IAM Roles & Security Groups

**Module:** `modules/security`

Least-privilege IAM roles and tightly scoped security group rules for all components.

**Security Group Rules Summary:**

| Security Group | Inbound | Outbound |
|---------------|---------|----------|
| `alb-sg` | 80, 443 from `0.0.0.0/0` | 8080 to `app-sg` |
| `app-sg` | 8080 from `alb-sg` | 5432 to `db-sg`, 443 to internet (via NAT) |
| `db-sg` | 5432 from `app-sg` | None |
| `bastion-sg` | 22 from your CIDR | `app-sg`, `db-sg` |

**EC2 Instance Role Permissions (minimal):**

```hcl
resource "aws_iam_role" "app_instance" {
  name = "${var.project}-${var.environment}-app-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "app_instance_policy" {
  name = "${var.project}-${var.environment}-app-instance-policy"
  role = aws_iam_role.app_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/app/${var.project}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.project}/${var.environment}/*"
      }
    ]
  })
}
```

---

## Variables Reference

### Root Module (`variables.tf`)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `project` | `string` | — | Project name (used in all resource names) |
| `environment` | `string` | — | Environment (`dev`, `staging`, `prod`) |
| `vpc_cidr` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `availability_zones` | `list(string)` | `["us-east-1a", "us-east-1b"]` | AZs to use |
| `db_engine` | `string` | `"postgres"` | RDS database engine |
| `db_engine_version` | `string` | `"15.4"` | RDS engine version |
| `db_instance_class` | `string` | `"db.t3.medium"` | RDS instance class |
| `db_allocated_storage` | `number` | `100` | Initial RDS storage (GB) |
| `db_max_allocated_storage` | `number` | `500` | Max RDS autoscaled storage (GB) |
| `instance_type` | `string` | `"t3.medium"` | EC2 instance type for ASG |
| `asg_min_size` | `number` | `2` | ASG minimum capacity |
| `asg_max_size` | `number` | `10` | ASG maximum capacity |
| `asg_desired_capacity` | `number` | `2` | ASG initial desired capacity |
| `alert_email_addresses` | `list(string)` | `[]` | Email addresses to receive CloudWatch alerts |
| `acm_certificate_arn` | `string` | — | ARN of ACM certificate for HTTPS |
| `microservices` | `map(object)` | — | Map of microservice configurations |

### `microservices` Variable Structure

```hcl
variable "microservices" {
  description = "Map of microservice configurations for routing and target groups"
  type = map(object({
    port              = number
    health_check_path = string
    path_patterns     = list(string)
    routing_priority  = number
  }))

  default = {
    api = {
      port              = 8080
      health_check_path = "/health"
      path_patterns     = ["/api/*"]
      routing_priority  = 100
    }
    auth = {
      port              = 8081
      health_check_path = "/health"
      path_patterns     = ["/auth/*"]
      routing_priority  = 90
    }
  }
}
```

---

## Outputs Reference

| Output | Description |
|--------|-------------|
| `vpc_id` | ID of the created VPC |
| `public_subnet_ids` | List of public subnet IDs |
| `private_app_subnet_ids` | List of private application subnet IDs |
| `private_db_subnet_ids` | List of private database subnet IDs |
| `alb_dns_name` | DNS name of the Application Load Balancer |
| `alb_arn` | ARN of the Application Load Balancer |
| `asg_name` | Name of the Auto Scaling Group |
| `db_endpoint` | RDS instance endpoint address |
| `db_port` | RDS instance port |
| `db_secret_arn` | ARN of the Secrets Manager secret holding DB credentials |
| `cloudwatch_dashboard_url` | URL to the CloudWatch operational dashboard |
| `sns_alert_topic_arn` | ARN of the SNS alerts topic |

---

## Getting Started

### 1. Clone and Initialize

```bash
git clone https://github.com/your-org/terraform-microservices.git
cd terraform-microservices
```

### 2. Configure AWS Credentials

```bash
aws configure
# or
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="us-east-1"
```

### 3. Configure Terraform Backend

Edit `main.tf` to set your S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "your-tfstate-lock-table"
    encrypt        = true
  }
}
```

### 4. Set Variables

Copy and edit the environment-specific tfvars:

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
# Edit the file with your values
```

Sensitive values (DB password, etc.) should be passed via environment variables or AWS Secrets Manager — do **not** commit them to version control:

```bash
export TF_VAR_db_password="your-secret-password"
```

### 5. Plan and Apply

```bash
# Initialize providers
terraform init

# Review the execution plan
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply (type 'yes' when prompted)
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 6. Verify Deployment

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Test the health endpoint
curl -f http://$(terraform output -raw alb_dns_name)/health
```

---

## Environments

| Environment | Instance Type | ASG Min/Max | RDS Class | Multi-AZ | Deletion Protection |
|-------------|--------------|-------------|-----------|----------|-------------------|
| `dev` | `t3.small` | 1 / 3 | `db.t3.small` | No | No |
| `staging` | `t3.medium` | 2 / 5 | `db.t3.medium` | No | No |
| `prod` | `m5.large` | 3 / 20 | `db.r6g.large` | Yes | Yes |

Apply to a specific environment:

```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

---

## Tagging Strategy

All resources are tagged with a consistent set of tags for cost allocation, ownership, and automation:

```hcl
locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.team_owner
    CostCenter  = var.cost_center
  }
}
```

| Tag | Value | Purpose |
|-----|-------|---------|
| `Project` | `my-platform` | Cost allocation |
| `Environment` | `prod` | Environment targeting |
| `ManagedBy` | `terraform` | Identifies IaC-managed resources |
| `Owner` | `platform-team` | Escalation ownership |
| `CostCenter` | `CC-1234` | Finance reporting |

---

## Security Considerations

- **IMDSv2 enforced** on all EC2 instances (`http_tokens = "required"`)
- **Encryption at rest** — EBS volumes, RDS storage, S3 logs, and Secrets Manager all use KMS customer-managed keys
- **Encryption in transit** — ALB terminates TLS 1.3; RDS enforces SSL connections
- **No public DB access** — RDS is in isolated private subnets with no public endpoint
- **Least-privilege IAM** — Instance role only allows access to its own project/environment secrets and log groups
- **VPC Flow Logs** enabled for all traffic (`ACCEPT` and `REJECT`)
- **ALB access logs** stored in S3 for 90 days (prod)
- **Security group rules** use resource references, never hardcoded IPs (except bastion ingress)
- **Deletion protection** enabled on RDS and ALB in production

---

## Cost Optimization

- **Scheduled scaling** — scale down ASG overnight in non-production environments
- **RDS storage autoscaling** — starts small, grows automatically rather than over-provisioning
- **Single NAT Gateway in dev/staging** — set `single_nat_gateway = true` in non-prod tfvars
- **GP3 storage** — used for both EBS and RDS (better price/performance than GP2)
- **Spot instances** — optionally configure mixed instance policy in the ASG for non-prod

---

## Troubleshooting

**EC2 instances not passing health checks**

Verify the application is listening on the configured port and returning 2xx from the health check path. Check the target group health in the AWS Console and the application logs in CloudWatch:

```bash
aws logs tail /app/my-project/dev/api --follow
```

**RDS connection refused**

Confirm the security group allows the app-sg to reach the db-sg on port 5432. Verify the DB endpoint and credentials from Secrets Manager are being read correctly by the application.

**Terraform state lock**

If a previous apply failed mid-run, the DynamoDB state lock may need to be released:

```bash
terraform force-unlock <LOCK_ID>
```

**Auto Scaling not triggering**

Check that the CloudWatch alarms are transitioning to `ALARM` state. Confirm the ASG has not reached `max_size`. Review the Auto Scaling activity history in the console.

---

## Contributing

1. Branch from `main` with a descriptive name: `feature/add-elasticache-module`
2. Run `terraform fmt -recursive` and `terraform validate` before committing
3. Include a `plan` output in your PR description
4. All modules must include `variables.tf`, `outputs.tf`, and a module-level `README.md`

---

## License

MIT — see [LICENSE](LICENSE) for details.
