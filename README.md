# AWS Container Image Scanning System

Automated container vulnerability scanning using Amazon ECR, Inspector v2, and serverless event processing.

## Overview

Production-ready infrastructure for continuous container security scanning with:

- **Automated Scanning**: Scan-on-push with ECR + Inspector v2 integration
- **Event-Driven Processing**: Lambda functions process findings in real-time
- **Policy Enforcement**: Configurable severity thresholds and blocking rules
- **Alerting**: Multi-channel notifications (SNS, Slack) for critical vulnerabilities
- **Monitoring**: CloudWatch dashboards and alarms for security posture tracking
- **Infrastructure as Code**: Complete Terraform modules for reproducible deployments

---

## Architecture

```
Container Image → ECR Repository → Inspector v2 Scan
                       ↓
                EventBridge Rules
                       ↓
            ┌──────────┼──────────┐
            ↓          ↓          ↓
        Lambda     DynamoDB    SNS Alerts
      Processing   Storage     (Email/Slack)
            ↓
      CloudWatch Monitoring
```

**Components:**
- **ECR**: Container registry with scan-on-push enabled
- **Inspector v2**: Continuous vulnerability and CVE scanning
- **EventBridge**: Event routing for scan results
- **Lambda**: Processes findings, enforces policies, aggregates data
- **DynamoDB**: Stores scan results and vulnerability inventory
- **SNS**: Multi-channel alerting (email, Slack)
- **CloudWatch**: Dashboards and alarms for security monitoring

---

## Project Structure

```
container-scanning/
├── terraform/
│   ├── modules/           # Reusable infrastructure modules
│   │   ├── ecr/          # ECR repositories
│   │   ├── inspector/    # Inspector v2 configuration
│   │   ├── eventbridge/  # Event rules and targets
│   │   ├── lambda/       # Lambda function deployment
│   │   ├── dynamodb/     # Data storage tables
│   │   ├── sns/          # Notification topics
│   │   └── monitoring/   # CloudWatch resources
│   ├── environments/
│   │   └── dev/          # Development environment config
│   └── main.tf           # Root module
│
├── src/
│   └── lambda-functions/
│       ├── scan-processor/         # Processes scan events
│       ├── vulnerability-aggregator/  # Aggregates findings
│       ├── policy-enforcer/        # Enforces security policies
│       └── slack-notifier/         # Sends Slack alerts
│
├── sample-apps/
│   └── vulnerable-app/    # Demo app for testing
│
├── scripts/
│   ├── build-lambdas.sh   # Package Lambda functions
│   ├── deploy.sh          # Complete deployment script
│   └── package-lambdas.py # Python packaging utility
│
└── tests/
    └── unit/              # Unit tests for Lambda functions
```

---

---

## 📁 Project Structure

```
aws-container-scanning/
├── terraform/                      # Infrastructure as Code
│   ├── modules/                    # Reusable Terraform modules
│   │   ├── ecr/                   # ECR repository module
│   │   ├── inspector/             # Inspector v2 setup
│   │   ├── eventbridge/           # Event routing
│   │   ├── lambda/                # Lambda functions
│   │   ├── dynamodb/              # Results storage
│   │   ├── sns/                   # Notifications
│   │   └── monitoring/            # CloudWatch dashboards
│   ├── environments/              # Environment-specific configs
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── main.tf                    # Root configuration
│
├── src/                           # Application code
│   ├── lambda-functions/          # Lambda handlers
│   │   ├── scan-processor/       # Process scan results
│   │   ├── vulnerability-aggregator/  # Aggregate findings
│   │   ├── slack-notifier/       # Send notifications
│   │   └── policy-enforcer/      # Enforce security policies
│   ├── policies/                  # Security policies
│   │   ├── opa-policies/         # Open Policy Agent rules
│   │   └── compliance/           # Compliance checks
│   └── scripts/                   # Utility scripts
│
├── cicd/                          # CI/CD configurations
│   ├── github-actions/           # GitHub Actions workflows
│   ├── gitlab-ci/                # GitLab CI pipelines
│   └── jenkins/                  # Jenkins pipelines
│
├── sample-apps/                   # Demo applications
│   ├── vulnerable-app/           # Intentionally vulnerable
│   └── secure-app/               # Security best practices
│
├── monitoring/                    # Monitoring configs
│   ├── dashboards/               # CloudWatch dashboards
│   ├── alerts/                   # Alert definitions
│   └── grafana/                  # Grafana configs
│
├── docs/                          # Documentation
│   ├── architecture/             # Architecture diagrams
│   ├── runbooks/                 # Operational guides
│   └── tutorials/                # Step-by-step guides
│
└── tests/                         # Testing
    ├── integration/              # Integration tests
    └── e2e/                      # End-to-end tests
```

---

## Prerequisites

- AWS Account with Administrator access
- Terraform >= 1.5.0
- AWS CLI v2 configured
- Docker installed
- Python 3.11+

## Quick Start

### 1. Configure Environment

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your email and preferences
```

### 2. Deploy Infrastructure

```bash
# Option 1: Using automated script
cd scripts/
./deploy.sh

# Option 2: Manual deployment
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Test Scanning

```bash
# Build and push sample vulnerable app
cd sample-apps/vulnerable-app
./build-and-push.sh

# Check scan results (wait 2-5 minutes)
aws ecr describe-image-scan-findings \
  --repository-name sample-app \
  --image-id imageTag=latest \
  --region us-east-1
```

## Key Features

- **Automated Scanning**: Every image pushed to ECR is automatically scanned
- **Continuous Monitoring**: Inspector v2 continuously rescans for new CVEs
- **Policy Enforcement**: Configurable blocking based on vulnerability severity
- **Real-time Alerts**: Instant notifications for CRITICAL/HIGH findings via SNS
- **Centralized Storage**: All findings stored in DynamoDB for tracking and reporting
- **Production-Ready**: KMS encryption, IAM least privilege, comprehensive monitoring

## Configuration

### Vulnerability Thresholds

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
vulnerability_severity_threshold = "HIGH"  # CRITICAL, HIGH, MEDIUM, LOW
block_on_critical                = true    # Fail deployments on CRITICAL
block_on_high                    = false   # Fail deployments on HIGH
```

### Notification Channels

```hcl
alert_email        = "security-team@company.com"
slack_webhook_url  = "https://hooks.slack.com/..."  # Optional
```

## Monitoring

### CloudWatch Dashboard

The deployment creates a security dashboard showing:
- Active vulnerabilities by severity
- Scan success/failure rates
- Finding trends over time
- Lambda function performance metrics

Access: CloudWatch → Dashboards → `container-scanning-security-dev`

### Alarms

Pre-configured alarms for:
- CRITICAL vulnerabilities detected
- Lambda function errors
- Lambda function duration exceeding thresholds

## Security

- **Encryption**: KMS encryption for ECR images and SNS topics
- **IAM**: Least privilege roles for all Lambda functions
- **Network**: Optional VPC endpoints for private communication
- **Logging**: All actions logged to CloudWatch Logs
- **Audit**: DynamoDB tables track all scan results

## Cost Optimization

Estimated monthly costs for small deployment (~50 images):

| Service | Cost |
|---------|------|
| Inspector v2 | ~$4.50 (50 images × $0.09) |
| ECR Storage | ~$2 (20GB × $0.10) |
| Lambda | ~$1 (generous free tier) |
| DynamoDB | ~$1 (on-demand, light usage) |
| CloudWatch | ~$3 (logs + metrics) |
| **Total** | **~$12/month** |

Tips:
- Use lifecycle policies to remove old images
- Set appropriate scan schedules for dev vs prod
- Monitor usage with Cost Explorer

## Testing

Run unit tests:

```bash
cd tests/unit
python -m pytest test_scan_processor.py -v
```

## Cleanup

To destroy all resources:

```bash
cd terraform/environments/dev
terraform destroy
```

Note: Inspector v2 will be disabled, KMS keys scheduled for deletion (7-day waiting period).

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Production-ready container security infrastructure for modern DevOps teams.**
