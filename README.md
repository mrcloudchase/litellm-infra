# LiteLLM Infrastructure on AWS

This repository contains a modular Terraform configuration for deploying [LiteLLM](https://docs.litellm.ai/) on AWS using ECS, RDS, ALB, SSM, and IAM. The infrastructure is designed to be reusable across multiple environments (dev, staging, production).

## Architecture

The deployment creates the following AWS resources:

- **VPC**: Custom VPC with public, private, and database subnets across multiple AZs
- **ECS**: Fargate cluster running the LiteLLM container with auto-scaling
- **RDS**: PostgreSQL database for LiteLLM data persistence
- **ALB**: Application Load Balancer for traffic distribution
- **S3**: Configuration storage bucket for LiteLLM config file
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
│   ├── ecs/                   # ECS cluster and service
│   └── s3-config/             # S3 bucket for configuration storage
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
4. **Terraform backend setup** (S3 bucket and DynamoDB table for state management)

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

### 1. Clone and Setup Backend

```bash
git clone <your-repo-url>
cd litellm-infra
```

**Important**: Before deploying the infrastructure, you need to set up Terraform remote state management to avoid the chicken-and-egg problem.

#### Setup Terraform Backend (One-time)

1. **Generate unique resource names:**
```bash
# Generate unique names for your backend resources
BUCKET_NAME="litellm-terraform-state-$(openssl rand -hex 4)"
DYNAMODB_TABLE="litellm-terraform-locks-$(openssl rand -hex 4)"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
```

2. **Create backend resources manually:**
```bash
# Set variables
export AWS_REGION="us-east-1"  # or your preferred region

# Create S3 bucket
aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
}'

# Block public access
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table
aws dynamodb create-table \
  --table-name $DYNAMODB_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION
```

3. **Configure Terraform backend:**
```bash
# Copy backend template
cp examples/backend.tf.example backend.tf

# Edit with your actual bucket and table names
vim backend.tf
```

4. **Initialize Terraform:**
```bash
# Initialize with remote state
terraform init
```

### 2. Create Terraform Workspace

```bash
# Create and switch to your environment workspace
terraform workspace new dev

# Or use existing environments
# terraform workspace new staging
# terraform workspace new prod
```

### 3. Configure Environment

```bash
# Copy the environment configuration template
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit with your specific values
nano environments/dev/terraform.tfvars
```

Update the configuration with your values:

```hcl
# Required values to configure
name_prefix = "your-project-name"

# Update tags
default_tags = {
  Environment = "dev"
  Project     = "your-project"
  Owner       = "your-team"
}

# Add your API keys (these will be stored securely in SSM)
additional_ssm_parameters = {
  "openai-api-key" = {
    value       = "sk-proj-your-openai-key-here"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
  "anthropic-api-key" = {
    value       = "sk-ant-your-anthropic-key-here"
    type        = "SecureString"
    description = "Anthropic API Key for LiteLLM"
  }
}

# Secrets are auto-generated - no manual input needed!
# LiteLLM master key, salt key, and database password are 
# automatically generated using Terraform's random provider
```

### 4. Deploy Infrastructure

```bash
# Ensure you're in the correct workspace
terraform workspace show

# Deploy using workspace-specific configuration
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### 5. Access LiteLLM

After deployment, get the ALB URL and auto-generated master key:

```bash
# Get the load balancer URL
terraform output alb_url

# Get the auto-generated master key
terraform output -raw litellm_master_key

# Check configuration bucket
terraform output config_s3_uri
```

Test the deployment:

```bash
# Store the master key in a variable
MASTER_KEY=$(terraform output -raw litellm_master_key)

# Test the health endpoint
curl "$(terraform output -raw alb_url)/health"

# Test the API with a configured model
curl -X POST "$(terraform output -raw alb_url)/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Environment Management with Workspaces

### Workspace-Based Deployment (Recommended)

This project uses Terraform workspaces to manage multiple environments with isolated state:

```bash
# List available workspaces
terraform workspace list

# Create new workspace for environment
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch between environments
terraform workspace select dev
terraform workspace show  # Verify current workspace
```

### Development Environment

```bash
# Switch to dev workspace
terraform workspace select dev

# Configure development environment
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
nano environments/dev/terraform.tfvars

# Deploy with cost optimizations
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Development environment features:
- Single NAT Gateway for cost savings
- Smaller RDS instance (`db.t3.micro`)
- No deletion protection
- ECS Exec enabled for debugging
- Auto-generated secrets unique to dev environment

### Production Environment

```bash
# Switch to prod workspace
terraform workspace select prod

# Configure production environment
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
nano environments/prod/terraform.tfvars

# Deploy with high availability
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

Production environment features:
- Multiple NAT Gateways for HA
- Larger RDS instance with Multi-AZ
- Deletion protection enabled
- Enhanced monitoring
- Restricted network access
- Auto-generated secrets unique to production environment

### Multi-Environment Workflow

```bash
# Deploy to development
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"

# Test and validate changes

# Deploy to staging
terraform workspace select staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Final validation

# Deploy to production
terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Configuration Options

### LiteLLM Configuration

The deployment supports LiteLLM configuration through multiple methods:

#### 1. Configuration File (Primary Method)
The main configuration is managed via `examples/litellm-config.yaml`:

```yaml
# examples/litellm-config.yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  set_verbose: false
  json_logs: true
```

**Update workflow:**
```bash
# 1. Edit the config file
nano examples/litellm-config.yaml

# 2. Deploy changes (automatically uploads to S3 and redeploys ECS)
terraform apply
```

#### 2. Environment Variables
Additional runtime configuration via terraform.tfvars:

```hcl
environment_variables = {
  LITELLM_LOG_LEVEL     = "INFO"
  LITELLM_DROP_PARAMS   = "true"
  LITELLM_REQUEST_TIMEOUT = "600"
}
```

#### 3. API Keys via SSM
Add provider API keys securely:

```hcl
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

# View configuration file location
terraform output config_s3_uri
```

### Configuration Management

The deployment includes automated configuration management:

- **S3 Storage**: Configuration file stored in versioned S3 bucket
- **Automatic Updates**: Config changes trigger ECS redeployment
- **Zero Downtime**: Rolling updates when configuration changes
- **Version Control**: Git tracks config changes, S3 provides file versioning

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
