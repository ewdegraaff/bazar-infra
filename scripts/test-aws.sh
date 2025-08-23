#!/bin/bash

# Test AWS Profile Configuration
# Usage: ./test-aws.sh [profile_name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if profile is provided as argument
if [[ $# -gt 0 ]]; then
    AWS_PROFILE="$1"
    print_status "Testing AWS profile: $AWS_PROFILE"
else
    # Use AWS_PROFILE environment variable or default
    AWS_PROFILE="${AWS_PROFILE:-default}"
    print_status "Testing AWS profile: $AWS_PROFILE (from environment or default)"
fi

# Test AWS CLI installation
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

print_success "AWS CLI is installed"

# Test profile configuration
print_status "Testing profile configuration..."

if aws sts get-caller-identity --profile "$AWS_PROFILE" --output text &> /dev/null; then
    print_success "Profile '$AWS_PROFILE' is configured and working!"
    
    # Get account information
    account_id=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Account' --output text)
    user_arn=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'Arn' --output text)
    user_id=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query 'UserId' --output text)
    
    echo "Account ID: $account_id"
    echo "User ARN: $user_arn"
    echo "User ID: $user_id"
    
    # Test region configuration
    region=$(aws configure get region --profile "$AWS_PROFILE")
    if [[ -n "$region" ]]; then
        print_success "Region configured: $region"
    else
        print_warning "No region configured for profile '$AWS_PROFILE'"
    fi
    
    # Test basic AWS services
    print_status "Testing basic AWS services..."
    
    # Test S3 access
    if aws s3 ls --profile "$AWS_PROFILE" &> /dev/null; then
        print_success "S3 access: OK"
    else
        print_warning "S3 access: Limited or no access"
    fi
    
    # Test CloudFormation access
    if aws cloudformation list-stacks --profile "$AWS_PROFILE" --max-items 1 &> /dev/null; then
        print_success "CloudFormation access: OK"
    else
        print_warning "CloudFormation access: Limited or no access"
    fi
    
    # Test ECR access
    if aws ecr describe-repositories --profile "$AWS_PROFILE" --max-items 1 &> /dev/null; then
        print_success "ECR access: OK"
    else
        print_warning "ECR access: Limited or no access"
    fi
    
    print_success "AWS profile '$AWS_PROFILE' is ready for use!"
    
else
    print_error "Profile '$AWS_PROFILE' is not configured or has invalid credentials."
    print_error "Please run: aws configure --profile $AWS_PROFILE"
    exit 1
fi
