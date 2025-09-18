# LiteLLM Infrastructure on AWS

This repository contains a modular Terraform configuration for deploying [LiteLLM](https://docs.litellm.ai/) on AWS using ECS, RDS, ALB, SSM, and IAM. The infrastructure is designed to be reusable across multiple environments (dev, staging, production).

## Architecture

The deployment creates the following AWS resources:

- **VPC**: Custom VPC with public, private, and database subnets across multiple AZs
- **ECS**: Fargate cluster running the LiteLLM container
- **RDS**: PostgreSQL database for LiteLLM data persistence
- **ALB**: Application Load Balancer for traffic distribution
- **SSM**: Parameter Store for secure secrets management
- **IAM**: Roles and policies for secure access
- **Security Groups**: Network security rules for each component

## Directory Structure

```
.
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC and networking
│   ├── security-groups/       # Security groups for all components
│   ├── iam/                   # IAM roles and policies
│   ├── ssm/                   # SSM Parameter Store
│   ├── rds/                   # PostgreSQL database
│   ├── alb/                   # Application Load Balancer
│   └── ecs/                   # ECS cluster and service
├── environments/              # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
└── README.md                  # This file
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **AWS IAM permissions** for creating the required resources
4. **LiteLLM configuration** (optional, for custom model configurations)

### Required AWS Permissions

Your AWS credentials need permissions to create and manage:
- VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables
- ECS Cluster, Service, Task Definition
- RDS Instance, DB Subnet Group, Parameter Group
- Application Load Balancer, Target Group, Listener
- IAM Roles and Policies
- SSM Parameters
- Security Groups
- CloudWatch Log Groups

## Quick Start

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd litellm-infra
```

### 2. Create Environment Configuration

Copy the appropriate example configuration:

```bash
# For development
cp environments/dev/terraform.tfvars.example terraform.tfvars

# Or for production
cp environments/prod/terraform.tfvars.example terraform.tfvars
```

### 3. Update Configuration

Edit `terraform.tfvars` and update the required values:

```hcl
# Required values to configure
name_prefix = "your-project-name"

# Update tags
default_tags = {
  Environment = "dev"
  Project     = "your-project"
  Owner       = "your-team"
}

# Secrets are auto-generated - no manual input needed!
# LiteLLM master key, salt key, and database password are 
# automatically generated using Terraform's random provider
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### 5. Access LiteLLM

After deployment, get the ALB URL and auto-generated master key:

```bash
# Get the load balancer URL
terraform output alb_url

# Get the auto-generated master key
terraform output -raw litellm_master_key
```

Test the deployment:

```bash
# Store the master key in a variable
MASTER_KEY=$(terraform output -raw litellm_master_key)

# Test the API
curl -X POST "$(terraform output -raw alb_url)/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Environment Management

### Development Environment

```bash
# Use development configuration
cp environments/dev/terraform.tfvars.example terraform.tfvars

# Deploy with cost optimizations
terraform apply
```

Development environment features:
- Single NAT Gateway for cost savings
- Smaller RDS instance (`db.t3.micro`)
- No deletion protection
- ECS Exec enabled for debugging
- Auto-generated secrets unique to dev environment

### Production Environment

```bash
# Use production configuration
cp environments/prod/terraform.tfvars.example terraform.tfvars

# Deploy with high availability
terraform apply
```

Production environment features:
- Multiple NAT Gateways for HA
- Larger RDS instance with Multi-AZ
- Deletion protection enabled
- Enhanced monitoring
- Restricted network access
- Auto-generated secrets unique to production environment

### Multiple Environments

To manage multiple environments simultaneously:

```bash
# Create workspace for each environment
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch between environments
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"

terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Configuration Options

### LiteLLM Configuration

The deployment supports various LiteLLM configurations through environment variables and SSM parameters:

```hcl
# In terraform.tfvars
environment_variables = {
  LITELLM_LOG_LEVEL     = "INFO"
  LITELLM_DROP_PARAMS   = "true"
  LITELLM_REQUEST_TIMEOUT = "600"
}

# Add API keys via SSM
additional_ssm_parameters = {
  "openai-api-key" = {
    value       = "sk-your-openai-api-key"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
}
```

### Secret Management

All core secrets are automatically generated:

- **LiteLLM Master Key**: Format `sk-{48 alphanumeric chars}` - auto-generated
- **LiteLLM Salt Key**: 32-byte base64-encoded key for AES-256 - auto-generated  
- **Database Password**: 32-char RDS-compliant password - auto-generated

Retrieve secrets after deployment:

```bash
# Get master key for API authentication
terraform output -raw litellm_master_key

# Get SSM parameter names for external access
terraform output secret_retrieval_commands
```

### Scaling Configuration

Configure ECS autoscaling:

```hcl
ecs_desired_count      = 3
ecs_min_capacity       = 2
ecs_max_capacity       = 20
ecs_enable_autoscaling = true
```

### Database Configuration

Configure RDS settings:

```hcl
db_instance_class          = "db.r6g.large"
db_allocated_storage       = 100
db_max_allocated_storage   = 1000
db_multi_az               = true
db_backup_retention_period = 30
```

## Security Considerations

### Network Security

- ECS tasks run in private subnets with no direct internet access
- RDS runs in isolated database subnets
- Security groups restrict access between components
- ALB is the only internet-facing component

### Secrets Management

- All secrets auto-generated using Terraform random provider
- Database passwords, LiteLLM keys stored in SSM Parameter Store as SecureString
- Secrets are unique per environment and cryptographically secure
- IAM roles follow principle of least privilege
- No manual secret management required

### Access Control

```hcl
# Restrict ALB access by IP
allowed_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]

# Enable deletion protection in production
alb_enable_deletion_protection = true
db_deletion_protection        = true
```

## Monitoring and Logging

### CloudWatch Logs

- ECS task logs: `/ecs/{name_prefix}`
- Application logs automatically streamed to CloudWatch

### Monitoring

- ECS Container Insights enabled
- RDS Enhanced Monitoring (optional)
- ALB access logs (optional)

### Health Checks

- ALB health checks on `/health` endpoint
- ECS health checks with configurable thresholds
- Auto-scaling based on CPU and memory utilization

## Troubleshooting

### Common Issues

1. **ECS Tasks Not Starting**
   ```bash
   # Check ECS service events
   aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name) --services $(terraform output -raw ecs_service_name)
   
   # Check CloudWatch logs
   aws logs tail $(terraform output -raw ecs_log_group_name) --follow
   ```

2. **Database Connection Issues**
   ```bash
   # Verify database endpoint
   terraform output database_endpoint
   
   # Check security group rules
   aws ec2 describe-security-groups --group-ids $(terraform output -raw rds_security_group_id)
   ```

3. **ALB Health Check Failures**
   ```bash
   # Check target group health
   aws elbv2 describe-target-health --target-group-arn $(terraform output -raw alb_target_group_arn)
   ```

### Debugging

Enable ECS Exec for debugging:

```hcl
ecs_enable_execute_command = true
```

Then connect to a running task:

```bash
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task <task-id> \
  --container litellm \
  --interactive \
  --command "/bin/bash"
```

## Cleanup

To destroy the infrastructure:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy the infrastructure
terraform destroy
```

**Note**: If deletion protection is enabled, you'll need to disable it first or use the `-target` flag to destroy specific resources.

## Cost Optimization

### Development Environment

- Use `single_nat_gateway = true`
- Use smaller instance types (`db.t3.micro`, `ecs_cpu = 256`)
- Disable Multi-AZ for RDS
- Set shorter backup retention periods

### Production Environment

- Use appropriate instance sizes based on load
- Enable Multi-AZ for high availability
- Use Reserved Instances for predictable workloads
- Monitor and adjust auto-scaling thresholds

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test in a development environment
5. Submit a pull request

## License

[Add your license information here]

## Support

For issues related to:
- **Infrastructure**: Create an issue in this repository
- **LiteLLM**: See [LiteLLM documentation](https://docs.litellm.ai/)
- **AWS Services**: Consult AWS documentation

## References

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [LiteLLM Docker Deployment](https://docs.litellm.ai/docs/proxy/deploy)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/)
