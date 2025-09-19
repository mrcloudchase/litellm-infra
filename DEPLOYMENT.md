# LiteLLM Deployment Guide

This guide provides step-by-step instructions for deploying LiteLLM infrastructure on AWS.

## Pre-deployment Checklist

### 1. Prerequisites
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] Appropriate AWS IAM permissions
- [ ] Terraform backend setup (S3 + DynamoDB)

**Note**: Secret generation is now fully automated - no manual key generation required!

## Deployment Steps

### Step 1: Repository Setup

1. Clone the repository:
```bash
git clone <your-repo>
cd litellm-infra
```

### Step 2: Backend Configuration (One-time Setup)

**Important**: Set up Terraform remote state before deploying infrastructure to prevent chicken-and-egg issues.

1. **Generate unique backend resource names:**
```bash
# Generate unique names to avoid conflicts
BUCKET_NAME="litellm-terraform-state-$(openssl rand -hex 4)"
DYNAMODB_TABLE="litellm-terraform-locks-$(openssl rand -hex 4)"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
```

2. **Create backend resources manually:**
```bash
# Set your AWS region
export AWS_REGION="us-east-1"  # or your preferred region

# Create S3 bucket for state storage
aws s3api create-bucket --bucket $BUCKET_NAME --region $AWS_REGION

# Enable versioning for state history
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Block public access for security
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name $DYNAMODB_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION
```

3. **Verify backend resources:**
```bash
# Verify S3 bucket creation
aws s3api head-bucket --bucket $BUCKET_NAME
echo "✅ S3 bucket created: $BUCKET_NAME"

# Verify DynamoDB table creation
aws dynamodb describe-table --table-name $DYNAMODB_TABLE --query 'Table.TableStatus'
echo "✅ DynamoDB table created: $DYNAMODB_TABLE"
```

4. **Configure Terraform backend:**
```bash
# Copy backend template
cp examples/backend.tf.example backend.tf

# Edit with your actual resource names
vim backend.tf
# Update bucket and dynamodb_table values with your generated names
```

5. **Initialize Terraform with remote state:**
```bash
terraform init
```

### Step 3: Workspace Creation
```bash
# Create workspace for your environment
terraform workspace new dev  # or staging/prod

# Verify workspace
terraform workspace show
terraform workspace list
```

### Step 4: Environment Configuration
```bash
# Copy configuration template to environment directory
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit with your specific values
vim environments/dev/terraform.tfvars
```

4. Update the configuration file:
```hcl
name_prefix = "my-litellm"

default_tags = {
  Environment = "dev"
  Project     = "litellm"
  Owner       = "your-name"
}

# Add your API keys (stored securely in SSM)
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
# LiteLLM master key, salt key, and database password will be
# automatically generated using Terraform's random provider
```

### Step 5: Infrastructure Deployment

1. Validate the configuration:
```bash
# Ensure you're in the correct workspace
terraform workspace show

# Validate configuration
terraform validate
```

2. Review the deployment plan:
```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
```

3. Deploy the infrastructure:
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Type `yes` when prompted to confirm the deployment.

### Step 6: Post-Deployment Verification

1. Get the ALB URL:
```bash
ALB_URL=$(terraform output -raw alb_url)
echo "LiteLLM URL: $ALB_URL"
```

2. Wait for the service to be healthy (may take 5-10 minutes):
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].deployments[0].status'
```

3. Test the health endpoint:
```bash
curl -f "$ALB_URL/health"
```

4. Test the LiteLLM API:
```bash
# Get the auto-generated master key
MASTER_KEY=$(terraform output -raw litellm_master_key)

# Test the API
curl -X POST "$ALB_URL/v1/models" \
  -H "Authorization: Bearer $MASTER_KEY"
```

### Step 7: Configure LiteLLM Models

Configuration is now managed in the separate litellm-app repository. To customize:

1. **Use custom container with your configuration:**
```bash
# Update terraform.tfvars to use your custom container
container_image = "your-account.dkr.ecr.us-east-1.amazonaws.com/litellm-custom:v1.0.0"
```

2. **Add your API keys to SSM Parameter Store:**
```bash
# Example: Add OpenAI API key
aws ssm put-parameter \
  --name "/$(terraform output -raw name_prefix)/litellm/openai-api-key" \
  --value "sk-your-openai-api-key" \
  --type "SecureString" \
  --description "OpenAI API Key for LiteLLM"
```

3. **Deploy configuration changes:**
```bash
# Ensure you're in the correct workspace
terraform workspace show

# Deploy with updated container image
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

4. **Verify configuration deployment:**
```bash
# Note: Configuration is now baked into container from litellm-app repository

# Verify ECS tasks are using new configuration
aws ecs describe-services --cluster $(terraform output -raw ecs_cluster_name) --services $(terraform output -raw ecs_service_name)
```

### Step 8: Access Generated Secrets

Retrieve auto-generated secrets:

```bash
# Get the master key for API authentication
terraform output -raw litellm_master_key

# Get commands to retrieve all secrets from SSM
terraform output secret_retrieval_commands

# Or access directly from SSM
aws ssm get-parameter --name "/my-litellm/litellm/master-key" --with-decryption
```

## Environment-Specific Deployments

### Development Environment

Development environment is optimized for cost and ease of debugging:

```bash
# Switch to development workspace
terraform workspace select dev

# Configure development environment
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
vim environments/dev/terraform.tfvars

# Deploy to development
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

Key development features:
- Single NAT Gateway (cost optimization)
- Smaller instance sizes
- ECS Exec enabled for debugging
- No deletion protection
- Auto-generated secrets unique to development

### Production Environment

Production environment is optimized for high availability and security:

```bash
# Switch to production workspace
terraform workspace select prod

# Configure production environment
cp environments/prod/terraform.tfvars.example environments/prod/terraform.tfvars
vim environments/prod/terraform.tfvars

# Deploy to production
terraform plan -var-file="environments/prod/terraform.tfvars"
terraform apply -var-file="environments/prod/terraform.tfvars"
```

Key production features:
- Multiple NAT Gateways for HA
- Larger instance sizes
- Multi-AZ RDS deployment
- Deletion protection enabled
- Restricted network access
- Auto-generated secrets unique to production

## Multi-Environment Management

To manage multiple environments:

### Using Terraform Workspaces

1. Create workspaces:
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod
```

2. Deploy to each environment:
```bash
# Deploy to dev
terraform workspace select dev
terraform apply -var-file="environments/dev/terraform.tfvars"

# Deploy to staging
terraform workspace select staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Deploy to prod
terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

### Using Separate State Files

Alternatively, use separate directories:

```bash
# Create environment-specific directories
mkdir -p deployments/{dev,staging,prod}

# Copy main files to each environment
for env in dev staging prod; do
  cp main.tf variables.tf outputs.tf deployments/$env/
  cp environments/$env/terraform.tfvars.example deployments/$env/terraform.tfvars
done

# Deploy each environment
cd deployments/dev
terraform init && terraform apply
```

## Configuration Management

### Updating LiteLLM Configuration

Configuration is now managed in the separate litellm-app repository:

1. **Build New Container:**
```bash
# In litellm-app repository:
# 1. Edit configuration files
# 2. Update guardrails if needed
# 3. Build and push new container version
# 4. Tag with semantic version (e.g., v1.1.0)
```

2. **Deploy Changes:**
```bash
# Update infrastructure with new container version
container_image = "your-account.dkr.ecr.us-east-1.amazonaws.com/litellm-custom:v1.1.0"
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

### Adding Model Providers

#### Method 1: Container Configuration (Recommended)
Edit configuration in litellm-app repository:

```yaml
model_list:
  # Add new models
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY
  
  - model_name: azure-gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: "2024-02-01"
```

#### Method 2: SSM Parameters
Add API keys via SSM Parameter Store:

```bash
# Add Anthropic API key
aws ssm put-parameter \
  --name "/your-prefix/litellm/anthropic-api-key" \
  --value "sk-ant-your-key" \
  --type "SecureString"

# Add Azure OpenAI configuration
aws ssm put-parameter \
  --name "/your-prefix/litellm/azure-api-key" \
  --value "your-azure-key" \
  --type "SecureString"

aws ssm put-parameter \
  --name "/your-prefix/litellm/azure-api-base" \
  --value "https://your-resource.openai.azure.com/" \
  --type "String"
```

Then deploy the configuration:
```bash
# Deploy using current workspace configuration
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

### Scaling Configuration

Update the ECS service scaling parameters:

```hcl
# In terraform.tfvars
ecs_desired_count      = 5
ecs_min_capacity       = 3
ecs_max_capacity       = 20
ecs_enable_autoscaling = true
```

Then apply the changes:
```bash
terraform apply -var-file="environments/$(terraform workspace show)/terraform.tfvars"
```

## Monitoring and Maintenance

### Configuration File Management

Configuration is now managed in the separate litellm-app repository:

```bash
# Configuration is baked into the custom container
# No runtime configuration files to manage
# Update configuration by building new container version in litellm-app repo

# Check current container image version
aws ecs describe-task-definition --task-definition $(terraform output -raw ecs_cluster_name | cut -d'/' -f2)-task --query 'taskDefinition.containerDefinitions[0].image'
```

### Viewing Logs

```bash
# View ECS logs
aws logs tail $(terraform output -raw ecs_log_group_name) --follow

# View specific task logs
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --start-time $(date -d '1 hour ago' +%s)000

# Check for configuration-related errors
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "config"
```

### Health Monitoring

```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw alb_target_group_arn)

# Check ECS service health
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)
```

### Database Maintenance

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1)

# View database logs
aws rds describe-db-log-files \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1)
```

## Troubleshooting

### Common Issues

1. **ECS Tasks Failing to Start**
   - Check CloudWatch logs for error messages
   - Verify SSM parameters are accessible
   - Check security group configurations
   - Verify custom container can be pulled from ECR

2. **Container Issues**
   - Verify custom container image exists in ECR
   - Check ECS task execution role has ECR pull permissions
   - Ensure container includes required configuration and guardrails
   - Verify container architecture matches ECS platform (linux/amd64)

3. **Database Connection Issues**
   - Verify security group allows connections from ECS
   - Check database endpoint and credentials
   - Ensure database is in available state

4. **Load Balancer Health Checks Failing**
   - Verify the health check path is correct
   - Check that the application is listening on the correct port
   - Review security group rules
   - Ensure custom container started successfully

### Getting Help

```bash
# Debug ECS task
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task TASK_ID \
  --container litellm \
  --interactive \
  --command "/bin/bash"

# Check recent events
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].events[:5]'

# Verify custom container and guardrails
aws ecs execute-command \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --task TASK_ID \
  --container litellm \
  --interactive \
  --command "ls -la /app/guardrails/ && cat /app/config.yaml"
```

## Cleanup

To destroy the infrastructure:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy the infrastructure
terraform destroy
```

**Important**: If deletion protection is enabled, disable it first:

```bash
# Disable ALB deletion protection
aws elbv2 modify-load-balancer \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --no-deletion-protection

# Disable RDS deletion protection
aws rds modify-db-instance \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1) \
  --no-deletion-protection
```

## Security Best Practices

1. **Secrets are automatically generated with cryptographic strength**
2. **Restrict network access using security groups**
3. **Enable deletion protection in production**
4. **Secrets are unique per environment and stored securely in SSM**
5. **Monitor access logs and metrics**
6. **Use least-privilege IAM policies**
7. **Enable encryption at rest and in transit**
8. **Rotate secrets by tainting Terraform random resources if needed**

## Performance Optimization

1. **Right-size your instances based on actual usage**
2. **Use appropriate auto-scaling thresholds**
3. **Monitor database performance and optimize queries**
4. **Consider using RDS Proxy for connection pooling**
5. **Enable CloudWatch Container Insights for detailed metrics**
