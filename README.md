# AWS Container Image Scanning System

Automated container vulnerability scanning using Amazon ECR, Inspector v2, and serverless event processing.

## Features

- **Automated Scanning**: Scan-on-push with ECR + Inspector v2 integration
- **Event-Driven Processing**: Lambda functions process findings in real-time
- **Policy Enforcement**: Configurable severity thresholds and blocking rules
- **Real-time Alerts**: Multi-channel notifications (SNS, Slack) for critical vulnerabilities
- **CloudWatch Monitoring**: Dashboards and alarms for security posture tracking
- **Infrastructure as Code**: Complete Terraform modules for reproducible deployments

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
- **ECR**: Container registry with scan-on-push
- **Inspector v2**: Continuous vulnerability scanning
- **EventBridge**: Event routing for scan results
- **Lambda**: Process findings, enforce policies, aggregate data
- **DynamoDB**: Store scan results and vulnerability inventory
- **SNS**: Multi-channel alerting (email, Slack)
- **CloudWatch**: Dashboards and alarms

## Project Structure

```
container-scanning/
├── terraform/
│   ├── modules/           # ECR, Inspector, EventBridge, Lambda, DynamoDB, SNS, Monitoring
│   ├── environments/dev/  # Environment-specific configuration
│   └── main.tf
├── src/lambda-functions/  # scan-processor, vulnerability-aggregator, policy-enforcer, slack-notifier
├── sample-apps/           # Demo vulnerable application
├── scripts/               # build-lambdas.sh, deploy.sh, package-lambdas.py
└── tests/unit/            # Lambda function tests
```

---

## Prerequisites

- AWS Account with Administrator access
- Terraform >= 1.5.0
- AWS CLI v2 configured
- Docker and Python 3.11+

## Quick Start

**1. Configure:**
```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your email
```

**2. Deploy:**
```bash
cd scripts && ./deploy.sh
```

**3. Test:**
```bash
cd sample-apps/vulnerable-app && ./build-and-push.sh
# Wait 2-5 minutes, then check results
aws ecr describe-image-scan-findings --repository-name sample-app --image-id imageTag=latest --region us-east-1
```

## Configuration

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
vulnerability_severity_threshold = "HIGH"
block_on_critical                = true
alert_email                      = "security-team@company.com"
slack_webhook_url                = ""  # Optional
```

## Monitoring

**CloudWatch Dashboard:** `container-scanning-security-dev`
- Active vulnerabilities by severity
- Scan success/failure rates
- Lambda performance metrics

**Pre-configured Alarms:**
- CRITICAL vulnerabilities detected
- Lambda errors and duration thresholds

## Security

- KMS encryption (ECR images, SNS topics)
- IAM least privilege roles
- Optional VPC endpoints
- Complete CloudWatch logging
- DynamoDB audit trail

## Cost

Estimated monthly cost (~50 images):

| Service | Cost |
|---------|------|
| Inspector v2 | $4.50 |
| ECR Storage | $2 |
| Lambda/DynamoDB/CloudWatch | $5 |
| **Total** | **~$12/month** |

## Testing & Cleanup

**Run tests:**
```bash
cd tests/unit && python -m pytest test_scan_processor.py -v
```

**Destroy resources:**
```bash
cd terraform/environments/dev && terraform destroy
```

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

**Production-ready container security infrastructure for modern DevOps teams.**
