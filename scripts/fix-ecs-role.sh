#!/bin/bash

# Fix ECS Service Linked Role
# This script creates the missing ECS service linked role required for ECS clusters

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

# Check if AWS_PROFILE is set
if [[ -n "$AWS_PROFILE" ]]; then
    print_status "Using AWS profile: $AWS_PROFILE"
    AWS_CMD="aws --profile $AWS_PROFILE"
else
    print_warning "AWS_PROFILE not set. Using default profile."
    AWS_CMD="aws"
fi

# Function to check if ECS service linked role exists
check_ecs_role() {
    print_status "Checking if ECS service linked role exists..."
    
    if $AWS_CMD iam get-role --role-name AWSServiceRoleForECS &> /dev/null; then
        print_success "ECS service linked role already exists!"
        return 0
    else
        print_warning "ECS service linked role does not exist. Creating it..."
        return 1
    fi
}

# Function to create ECS service linked role
create_ecs_role() {
    print_status "Creating ECS service linked role..."
    
    # Create the service linked role
    if $AWS_CMD iam create-service-linked-role --aws-service-name ecs.amazonaws.com; then
        print_success "ECS service linked role created successfully!"
    else
        print_error "Failed to create ECS service linked role!"
        exit 1
    fi
}

# Function to verify ECS service linked role
verify_ecs_role() {
    print_status "Verifying ECS service linked role..."
    
    if $AWS_CMD iam get-role --role-name AWSServiceRoleForECS &> /dev/null; then
        print_success "ECS service linked role verification successful!"
        
        # Get role details
        local role_arn=$($AWS_CMD iam get-role --role-name AWSServiceRoleForECS --query 'Role.Arn' --output text)
        print_status "Role ARN: $role_arn"
        
        # Check attached policies
        local policies=$($AWS_CMD iam list-attached-role-policies --role-name AWSServiceRoleForECS --query 'AttachedPolicies[].PolicyName' --output text)
        if [[ -n "$policies" ]]; then
            print_status "Attached policies: $policies"
        else
            print_warning "No policies attached to the role"
        fi
        
    else
        print_error "ECS service linked role verification failed!"
        exit 1
    fi
}

# Main execution
main() {
    print_status "Starting ECS service linked role fix..."
    
    # Check if role exists
    if check_ecs_role; then
        print_success "No action needed. ECS service linked role already exists."
        exit 0
    fi
    
    # Create the role
    create_ecs_role
    
    # Verify the role
    verify_ecs_role
    
    print_success "ECS service linked role fix completed successfully!"
    print_status "You can now retry your CloudFormation deployment."
}

# Run main function
main "$@"
