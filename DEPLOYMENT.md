# LiteLLM Multi-Container Deployment Guide

This guide provides comprehensive instructions for deploying the LiteLLM multi-container infrastructure on AWS with local AI model serving capabilities.

## 🎯 Deployment Overview

This deployment creates a production-ready setup with:
- **LiteLLM API proxy** with PII detection guardrails
- **Ollama local AI server** running llama3.2:3b model
- **Multi-container ECS task** with shared networking
- **Automated CI/CD pipeline** via repository dispatch

## 📋 Pre-deployment Checklist

### Prerequisites
- [ ] AWS CLI installed and configured
- [ ] Terraform >= 1.0 installed
- [ ] GitHub CLI installed (for CI/CD setup)
- [ ] Appropriate AWS IAM permissions
- [ ] Access to both litellm-infra and litellm-app repositories

### Required Secrets
- [ ] AWS credentials with ECS, RDS, VPC, IAM permissions
- [ ] OpenAI API key (for cloud models)
- [ ] GitHub Personal Access Token (for repository dispatch)

## 🚀 Step-by-Step Deployment

### Step 1: Repository Setup

```bash
# Clone the infrastructure repository
git clone https://github.com/mrcloudchase/litellm-infra.git
cd litellm-infra
```

### Step 2: Backend Configuration (One-time Setup)

**Important**: Set up Terraform remote state before deploying infrastructure.

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
export AWS_REGION="us-east-1"

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
# Verify S3 bucket
aws s3api head-bucket --bucket $BUCKET_NAME
echo "✅ S3 bucket created: $BUCKET_NAME"

# Verify DynamoDB table
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

### Step 3: Environment Configuration

1. **Create workspace:**
```bash
# Create workspace for your environment
terraform workspace new dev

# Verify workspace
terraform workspace show
```

2. **Configure environment variables:**
```bash
# Copy configuration template
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit with your specific values
vim environments/dev/terraform.tfvars
```

3. **Update key configuration values:**
```hcl
# Required: Update name prefix
name_prefix = "litellm-dev"

# Required: Update tags
default_tags = {
  Environment = "dev"
  Project     = "litellm"
  Owner       = "your-name"
  CostCenter  = "engineering"
}

# Required: Add your OpenAI API key
additional_ssm_parameters = {
  "openai-api-key" = {
    value       = "sk-proj-your-openai-key-here"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
}

# Optional: Restrict access to your IP
allowed_cidr_blocks = ["your.ip.address.here/32"]

# Multi-container resources (pre-configured)
ecs_cpu    = 2048  # For LiteLLM + Ollama
ecs_memory = 6144  # For llama3.2:3b model (~3GB)
```

### Step 4: Infrastructure Deployment

1. **Validate configuration:**
```bash
# Ensure you're in the correct workspace
terraform workspace show

# Validate Terraform configuration
terraform validate
```

2. **Review deployment plan:**
```bash
terraform plan -var-file="environments/dev/terraform.tfvars"
```

3. **Deploy infrastructure:**
```bash
terraform apply -var-file="environments/dev/terraform.tfvars"
```

**Expected deployment time**: 10-15 minutes

### Step 5: Post-Deployment Verification

1. **Get deployment information:**
```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)
echo "LiteLLM URL: $ALB_URL"

# Get auto-generated master key
MASTER_KEY=$(terraform output -raw litellm_master_key)
echo "Master Key: $MASTER_KEY"
```

2. **Wait for containers to be ready:**
```bash
# Check ECS service status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].{runningCount:runningCount,pendingCount:pendingCount}'

# Check individual container health
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[*].{name:name,healthStatus:healthStatus}'
```

3. **Verify Ollama model is ready:**
```bash
# Check Ollama logs for model pull completion
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "Model pulled successfully" \
  --start-time $(date -v-10M +%s)000
```

4. **Test the deployment:**
```bash
# Test health endpoint (may require authentication)
curl "$ALB_URL/health"

# Test local model inference
curl -X POST "$ALB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2-3b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Test PII guardrails
curl -X POST "$ALB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2-3b", 
    "messages": [{"role": "user", "content": "My email is test@example.com"}]
  }'
```

## 🔄 CI/CD Setup (Optional)

### Setup Repository Dispatch Integration

1. **Create Personal Access Token:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens
   - Create fine-grained token with access to litellm-infra repository
   - Permissions: Actions (write), Metadata (read)

2. **Configure litellm-app repository:**
```bash
# In your litellm-app repository
gh secret set INFRA_DEPLOY_TOKEN --body "your-personal-access-token"

# Add repository dispatch step to build workflow
# (See litellm-app repository for implementation details)
```

3. **Test automated deployment:**
```bash
# Push changes to litellm-app
cd /path/to/litellm-app
git commit -m "Test repository dispatch"
git push origin main

# Monitor both repositories
gh run watch --repo mrcloudchase/litellm-app
gh run watch --repo mrcloudchase/litellm-infra
```

## 🔧 Configuration Management

### **Container Image Management:**

**Manual deployments** use:
```
container_image = "734184332381.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:latest"
```

**Repository dispatch deployments** use:
```
container_image = "734184332381.dkr.ecr.us-east-1.amazonaws.com/litellm-guardrails:commit-sha"
```

### **Model Configuration:**
Model configuration is baked into the container image from litellm-app repository:

```yaml
# In litellm-app/litellm-config.yaml
model_list:
  - model_name: llama3.2-3b
    litellm_params:
      model: ollama/llama3.2:3b
      api_base: http://localhost:11434  # Ollama container communication

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  health_check: true
  set_verbose: false
  json_logs: true
```

### **Adding New Models:**
To add new models, you need to update both repositories:

#### **Step 1: Add Model Configuration (litellm-app repository)**
```bash
# Clone or navigate to your litellm-app repository
git clone https://github.com/mrcloudchase/litellm-app.git
cd litellm-app

# Edit the LiteLLM configuration file
vim litellm-config.yaml
```

Add your new model to the configuration:
```yaml
model_list:
  # Existing local model
  - model_name: llama3.2-3b
    litellm_params:
      model: ollama/llama3.2:3b
      api_base: http://localhost:11434

  # Add new OpenAI model
  - model_name: gpt-4o-mini
    litellm_params:
      model: openai/gpt-4o-mini
      api_key: os.environ/OPENAI_API_KEY

  # Add new Anthropic model
  - model_name: claude-3-5-sonnet
    litellm_params:
      model: anthropic/claude-3-5-sonnet-20241022
      api_key: os.environ/ANTHROPIC_API_KEY

  # Add new Azure OpenAI model
  - model_name: azure-gpt-4o
    litellm_params:
      model: azure/gpt-4o
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: "2024-02-01"
```

#### **Step 2: Add API Keys (litellm-infra repository)**
```bash
# Navigate to your litellm-infra repository
cd /path/to/litellm-infra

# Edit your environment configuration
vim environments/dev/terraform.tfvars
```

Add the required API keys:
```hcl
additional_ssm_parameters = {
  # Existing OpenAI key
  "openai-api-key" = {
    value       = "sk-proj-your-openai-key-here"
    type        = "SecureString"
    description = "OpenAI API Key for LiteLLM"
  }
  
  # Add new Anthropic key
  "anthropic-api-key" = {
    value       = "sk-ant-your-anthropic-key-here"
    type        = "SecureString"
    description = "Anthropic API Key for Claude models"
  }
  
  # Add new Azure OpenAI keys
  "azure-api-key" = {
    value       = "your-azure-openai-key-here"
    type        = "SecureString"
    description = "Azure OpenAI API Key"
  }
  
  "azure-api-base" = {
    value       = "https://your-resource.openai.azure.com/"
    type        = "String"
    description = "Azure OpenAI API Base URL"
  }
}
```

#### **Step 3: Deploy Changes**
```bash
# In litellm-app repository - build and push new container
git add litellm-config.yaml
git commit -m "Add new models: gpt-4o-mini, claude-3-5-sonnet, azure-gpt-4o"
git push origin main
# This triggers ECR build and repository dispatch to litellm-infra

# In litellm-infra repository - update API keys
git add environments/dev/terraform.tfvars
git commit -m "Add API keys for new models"
git push origin main
# This triggers infrastructure update with new SSM parameters
```

#### **Step 4: Verify Model Availability**
```bash
# Wait for deployment to complete, then test
ALB_URL=$(terraform output -raw alb_url)
MASTER_KEY=$(terraform output -raw litellm_master_key)

# List available models
curl -H "Authorization: Bearer $MASTER_KEY" "$ALB_URL/v1/models"

# Test new OpenAI model
curl -X POST "$ALB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [{"role": "user", "content": "Hello from OpenAI!"}]
  }'

# Test new Anthropic model
curl -X POST "$ALB_URL/v1/chat/completions" \
  -H "Authorization: Bearer $MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-5-sonnet",
    "messages": [{"role": "user", "content": "Hello from Anthropic!"}]
  }'
```

## 📊 Monitoring and Maintenance

### **Container Health Monitoring:**
```bash
# Check multi-container task status
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)

# Monitor container logs in real-time
aws logs tail $(terraform output -raw ecs_log_group_name) --follow
```

### **Performance Monitoring:**
```bash
# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names $(terraform output -raw ecs_cluster_name | sed 's/-cluster//')-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Monitor ECS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$(terraform output -raw ecs_service_name) \
  --start-time $(date -v-1H +%s) \
  --end-time $(date +%s) \
  --period 300 \
  --statistics Average
```

### **Database Maintenance:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1)

# Monitor database connections
aws rds describe-db-instances \
  --db-instance-identifier $(terraform output -raw database_endpoint | cut -d. -f1) \
  --query 'DBInstances[0].DbInstanceStatus'
```

## 🚨 Troubleshooting Guide

### **Container Startup Issues:**

1. **Check container status:**
```bash
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[*].{name:name,lastStatus:lastStatus,healthStatus:healthStatus}'
```

2. **Check container logs:**
```bash
# Ollama container logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --log-stream-name "ollama/ollama/$(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text | cut -d'/' -f3)"

# LiteLLM container logs
aws logs get-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --log-stream-name "litellm/litellm/$(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text | cut -d'/' -f3)"
```

### **Model Inference Issues:**

1. **Verify Ollama model is loaded:**
```bash
# Check for successful model pull
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "Model pulled successfully"
```

2. **Test Ollama connectivity:**
```bash
# Check for connection errors in LiteLLM logs
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "localhost:11434"
```

3. **Common connection issues:**
- **"Cannot connect to host ollama:11434"**: Config should use `localhost:11434`
- **"exec format error"**: Wrong container architecture
- **"Model not found"**: Ollama model not pulled successfully

### **Health Check Issues:**

1. **503 Service Unavailable:**
```bash
# Check ALB target health (most common cause)
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names litellm-dev-ci-tg \
    --query 'TargetGroups[0].TargetGroupArn' --output text)

# Common 503 causes:
# - "initial" + "Elb.RegistrationInProgress": Containers still starting
# - "unhealthy" + "Target.FailedHealthChecks": Health checks failing
# - "draining": Old tasks being replaced

# Check if containers are running
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].{runningCount:runningCount,pendingCount:pendingCount}'

# Check container health status
aws ecs describe-tasks \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --tasks $(aws ecs list-tasks --cluster $(terraform output -raw ecs_cluster_name) --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[*].{name:name,healthStatus:healthStatus,lastStatus:lastStatus}'
```

2. **401 Unauthorized on /health:**
```bash
# Health endpoint requires authentication
curl -H "Authorization: Bearer $(terraform output -raw litellm_master_key)" \
  "$(terraform output -raw alb_url)/health"
```

3. **Multi-Container Startup Timing:**
```bash
# Ollama container needs time to pull the 2GB llama3.2:3b model
# Expected startup time: 3-5 minutes for model download
# Check Ollama model pull progress:
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "pulling" \
  --start-time $(date -v-10M +%s)000

# Wait for "Model pulled successfully" message:
aws logs filter-log-events \
  --log-group-name $(terraform output -raw ecs_log_group_name) \
  --filter-pattern "Model pulled successfully"
```

### **Network Access Issues:**

1. **Cannot reach ALB:**
```bash
# Check your IP is allowed
curl -s https://checkip.amazonaws.com
# Update allowed_cidr_blocks in terraform.tfvars if needed
```

2. **Security group issues:**
```bash
# Check ALB security group rules
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id)
```

## 🔄 Environment Management

### **Manual Development Workflow:**
```bash
# Switch to dev workspace
terraform workspace select dev

# Deploy with your configuration
terraform apply -var-file="environments/dev/terraform.tfvars"

# Test and iterate
# Make changes, redeploy as needed
```

### **CI/CD Workflow:**
```bash
# Automated via GitHub Actions
# Uses dev-ci workspace for isolation
# Triggered by:
# 1. Infrastructure changes (push to main)
# 2. New container images (repository dispatch from litellm-app)
# 3. Manual workflow dispatch
```

### **Multi-Environment Deployment:**
```bash
# Deploy to staging
terraform workspace select staging
terraform apply -var-file="environments/staging/terraform.tfvars"

# Deploy to production
terraform workspace select prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## 🔧 Configuration Updates

### **Updating Container Images:**

**Method 1: Automatic (Recommended)**
- Push changes to litellm-app repository
- Repository dispatch automatically triggers infrastructure update
- New container deployed with latest guardrails and configuration

**Method 2: Manual**
```bash
# Update GitHub secret
gh secret set CUSTOM_CONTAINER_IMAGE --body "your-ecr-registry/litellm-guardrails:new-tag"

# Trigger deployment
gh workflow run deploy-dev.yml
```

### **Updating Model Configuration:**
1. **Edit litellm-config.yaml** in litellm-app repository
2. **Update API keys** in terraform.tfvars if needed
3. **Push changes** → automatic deployment via repository dispatch

### **Scaling Resources:**
```hcl
# For heavier workloads, update terraform.tfvars:
ecs_cpu                = 4096  # More CPU for model inference
ecs_memory            = 8192   # More memory for larger models
ecs_desired_count     = 3      # More instances for load
ecs_enable_autoscaling = true  # Enable auto-scaling
```

## 📊 Monitoring and Observability

### **Real-time Monitoring:**
```bash
# Monitor container logs
aws logs tail $(terraform output -raw ecs_log_group_name) --follow

# Monitor specific container
aws logs tail $(terraform output -raw ecs_log_group_name) --follow --filter-pattern "[ollama]"
aws logs tail $(terraform output -raw ecs_log_group_name) --follow --filter-pattern "[litellm]"
```

### **Performance Metrics:**
```bash
# Check ECS service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=$(terraform output -raw ecs_service_name) \
  --start-time $(date -v-1H +%s) \
  --end-time $(date +%s) \
  --period 300 \
  --statistics Average,Maximum

# Check memory utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=$(terraform output -raw ecs_service_name) \
  --start-time $(date -v-1H +%s) \
  --end-time $(date +%s) \
  --period 300 \
  --statistics Average,Maximum
```

### **Application Metrics:**
```bash
# Check ALB request metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_dns_name | cut -d'-' -f1-3) \
  --start-time $(date -v-1H +%s) \
  --end-time $(date +%s) \
  --period 300 \
  --statistics Sum
```

## 🧹 Cleanup and Destruction

### **Manual Cleanup:**
```bash
# Review what will be destroyed
terraform plan -destroy -var-file="environments/dev/terraform.tfvars"

# Destroy infrastructure
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

### **Automated Cleanup via GitHub Actions:**
```bash
# Use the destroy workflow
gh workflow run destroy-dev.yml -f confirm_destroy=DESTROY

# Monitor destruction
gh run watch
```

### **Complete Cleanup:**
```bash
# Remove workspace after destruction
terraform workspace select default
terraform workspace delete dev

# Clean up backend resources (optional)
aws s3 rb s3://$BUCKET_NAME --force
aws dynamodb delete-table --table-name $DYNAMODB_TABLE
```

## 💰 Cost Management

### **Development Environment Cost:**
- **Total**: ~$148/month for 24/7 operation
- **Optimized**: ~$96/month for work hours only

### **Cost Reduction Strategies:**
1. **Scheduled operation**: Run only during work hours
2. **Smaller models**: Use llama3.2:1b instead of 3b
3. **Spot instances**: Use Fargate Spot pricing when available
4. **Resource right-sizing**: Monitor and adjust CPU/memory allocation

### **Cost Monitoring:**
```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

## 🔐 Security Best Practices

### **Network Security:**
- ✅ **Private subnets**: ECS tasks isolated from internet
- ✅ **IP restrictions**: ALB access limited to specific IPs
- ✅ **Security groups**: Granular network access control
- ✅ **VPC isolation**: Database in dedicated subnets

### **Secret Management:**
- ✅ **Auto-generated secrets**: No manual secret handling
- ✅ **SSM Parameter Store**: Encrypted secret storage
- ✅ **Unique per environment**: Separate secrets for each workspace
- ✅ **Rotation capability**: Taint random resources to regenerate

### **Container Security:**
- ✅ **Custom guardrails**: Built-in PII detection
- ✅ **Health checks**: Automated container monitoring
- ✅ **Least privilege**: Minimal IAM permissions
- ✅ **Encrypted storage**: RDS and EBS encryption enabled

## 📚 Advanced Topics

### **Multi-Environment Promotion:**
```bash
# Promote container from dev to staging
# 1. Test in dev environment
# 2. Tag container for staging
# 3. Update staging terraform.tfvars
# 4. Deploy to staging workspace
```

### **Disaster Recovery:**
```bash
# Backup current state
terraform state pull > backup-$(date +%Y%m%d).tfstate

# Restore from backup
terraform state push backup-YYYYMMDD.tfstate
```

### **Performance Tuning:**
```hcl
# Optimize for your workload
ecs_cpu    = 4096  # Scale up for heavy inference
ecs_memory = 8192  # Scale up for larger models

# Enable auto-scaling
ecs_enable_autoscaling = true
ecs_min_capacity      = 2
ecs_max_capacity      = 10
```

## 🆘 Getting Help

### **Common Error Patterns:**
- **"exec format error"**: Container architecture mismatch
- **"Cannot connect to host ollama"**: Incorrect API base configuration
- **"No api key passed in"**: Authentication required for endpoints
- **"Model not found"**: Ollama model not pulled or LiteLLM config mismatch

### **Debug Resources:**
- **Container logs**: Primary debugging tool
- **ECS service events**: Infrastructure-level issues
- **ALB target health**: Network connectivity issues
- **CloudWatch metrics**: Performance and resource utilization

### **Support Channels:**
- **Infrastructure issues**: Create issue in litellm-infra repository
- **Application issues**: Create issue in litellm-app repository
- **LiteLLM issues**: See [LiteLLM documentation](https://docs.litellm.ai/)
- **Ollama issues**: See [Ollama documentation](https://ollama.ai/)

---

**This deployment guide reflects the current multi-container architecture with local AI model serving and automated CI/CD pipeline integration.**