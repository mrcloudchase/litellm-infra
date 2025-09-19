#!/bin/bash

# GitHub Repository Secrets Setup Script
# Run this script to set up all required secrets for the dev environment CI/CD

echo "🔐 Setting up GitHub repository secrets for LiteLLM Infrastructure..."

# Check if GitHub CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Please authenticate with GitHub CLI first: gh auth login"
    exit 1
fi

echo "📋 You need to provide the following values:"
echo ""

# AWS Access Key ID
read -p "Enter your AWS Access Key ID: " AWS_ACCESS_KEY_ID
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"

# AWS Secret Access Key
read -s -p "Enter your AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo ""
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"

# OpenAI API Key
read -s -p "Enter your OpenAI API Key: " OPENAI_API_KEY
echo ""
gh secret set OPENAI_API_KEY --body "$OPENAI_API_KEY"

echo ""
echo "✅ All secrets have been set successfully!"
echo ""
echo "🔍 Verify secrets were set:"
gh secret list

echo ""
echo "🚀 You can now:"
echo "1. Push changes to trigger the dev deployment workflow"
echo "2. Or manually trigger via: gh workflow run deploy-dev.yml"
echo ""
echo "📋 After deployment, get your master key with:"
echo "aws ssm get-parameter --name '/litellm-dev-ci/litellm/master-key' --with-decryption --query 'Parameter.Value' --output text"
