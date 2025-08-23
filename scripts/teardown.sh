#!/bin/bash

# Bazar Infrastructure Teardown Script
# Usage: ./teardown.sh <environment> [stack_name]
# Example: ./teardown.sh dev
# Example: ./teardown.sh prod database

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity --profile "${AWS_PROFILE:-default}" &> /dev/null; then
        print_error "AWS CLI is not configured for profile '${AWS_PROFILE:-default}'. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured and working."
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" --profile "${AWS_PROFILE:-default}" &> /dev/null
}

# Function to get stack status
get_stack_status() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --profile "${AWS_PROFILE:-default}" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "STACK_NOT_FOUND"
}

# Function to wait for stack deletion
wait_for_stack_deletion() {
    local stack_name=$1
    local max_wait_time=1800  # 30 minutes
    local wait_time=0
    local sleep_interval=30
    
    print_status "Waiting for stack '$stack_name' to be deleted..."
    
    while [[ $wait_time -lt $max_wait_time ]]; do
        local status=$(get_stack_status "$stack_name")
        
        if [[ "$status" == "STACK_NOT_FOUND" ]]; then
            print_success "Stack '$stack_name' has been deleted successfully!"
            return 0
        fi
        
        if [[ "$status" == "DELETE_FAILED" ]]; then
            print_error "Stack '$stack_name' deletion failed!"
            return 1
        fi
        
        print_status "Stack '$stack_name' status: $status. Waiting $sleep_interval seconds..."
        sleep $sleep_interval
        wait_time=$((wait_time + sleep_interval))
    done
    
    print_warning "Stack deletion is taking longer than expected. Check AWS Console for status."
    return 0
}

  # Function to delete database stack
  delete_database() {
    local env=$1
    local stack_name="bazar-database-$env"
    
    if ! stack_exists "$stack_name"; then
        print_warning "Stack '$stack_name' does not exist. Skipping..."
        return 0
    fi
    
    print_status "Deleting database stack: $stack_name"
    
    # Check if this is production environment
    if [[ "$env" == "prod" ]]; then
        print_warning "This is a PRODUCTION environment. Are you sure you want to delete the database stack?"
        print_warning "This will permanently delete the RDS instance and all data!"
        echo -n "Type 'DELETE-PROD' to confirm: "
        read confirmation
        
        if [[ "$confirmation" != "DELETE-PROD" ]]; then
            print_error "Deletion cancelled by user."
            return 1
        fi
    fi
    
    # Warn about S3 bucket retention
    print_warning "IMPORTANT: S3 backup buckets are configured with DeletionPolicy: Retain"
    print_warning "This means S3 buckets will NOT be automatically deleted when the stack is removed."
    print_warning "You must manually delete S3 buckets via AWS Console if needed."
    print_warning "Note: S3 buckets with data can take a very long time to delete."
    
    # Delete the stack
    aws cloudformation delete-stack --stack-name "$stack_name" --profile "${AWS_PROFILE:-default}"
    
    # Wait for deletion to complete
    wait_for_stack_deletion "$stack_name"
    
    print_success "Database stack deleted successfully!"
    print_warning "Remember: S3 backup buckets are still present and must be manually deleted if needed."
  }

# Function to delete compute stack
delete_compute() {
    local env=$1
    local stack_name="bazar-compute-$env"
    
    if ! stack_exists "$stack_name"; then
        print_warning "Stack '$stack_name' does not exist. Skipping..."
        return 0
    fi
    
    print_status "Deleting compute stack: $stack_name"
    
    # Delete the stack
    aws cloudformation delete-stack --stack-name "$stack_name"
    
    # Wait for deletion to complete
    wait_for_stack_deletion "$stack_name"
    
    print_success "Compute stack deleted successfully!"
}

# Function to delete VPC stack
delete_vpc() {
    local env=$1
    local stack_name="bazar-vpc-$env"
    
    if ! stack_exists "$stack_name"; then
        print_warning "Stack '$stack_name' does not exist. Skipping..."
        return 0
    fi
    
    print_status "Deleting VPC stack: $stack_name"
    
    # Check for dependent stacks
    local dependent_stacks=()
    
    if stack_exists "bazar-compute-$env"; then
        dependent_stacks+=("bazar-compute-$env")
    fi
    
    if stack_exists "bazar-database-$env"; then
        dependent_stacks+=("bazar-database-$env")
    fi
    
    if [[ ${#dependent_stacks[@]} -gt 0 ]]; then
        print_error "Cannot delete VPC stack. The following stacks still exist:"
        for stack in "${dependent_stacks[@]}"; do
            echo "  - $stack"
        done
        print_error "Please delete dependent stacks first."
        return 1
    fi
    
    # Delete the stack
    aws cloudformation delete-stack --stack-name "$stack_name"
    
    # Wait for deletion to complete
    wait_for_stack_deletion "$stack_name"
    
    print_success "VPC stack deleted successfully!"
}

# Function to delete all stacks
delete_all() {
    local env=$1
    
    print_status "Deleting complete infrastructure for environment: $env"
    
    # Check if this is production environment
    if [[ "$env" == "prod" ]]; then
        print_warning "This is a PRODUCTION environment. Are you sure you want to delete ALL infrastructure?"
        print_warning "This will permanently delete ALL resources including databases!"
        echo -n "Type 'DELETE-ALL-PROD' to confirm: "
        read confirmation
        
        if [[ "$confirmation" != "DELETE-ALL-PROD" ]]; then
            print_error "Deletion cancelled by user."
            return 1
        fi
    fi
    
    # Delete stacks in reverse dependency order
    delete_database "$env"
    delete_compute "$env"
    delete_vpc "$env"
    
    print_success "Complete infrastructure deleted successfully for environment: $env"
}

# Function to list stacks for an environment
list_stacks() {
    local env=$1
    
    print_status "Listing stacks for environment: $env"
    
    local stacks=(
        "bazar-vpc-$env"
        "bazar-compute-$env"
        "bazar-database-$env"
    )
    
    echo "Stacks for environment '$env':"
    echo "----------------------------------------"
    
    for stack in "${stacks[@]}"; do
        if stack_exists "$stack"; then
            local status=$(get_stack_status "$stack")
            echo "✓ $stack - Status: $status"
        else
            echo "✗ $stack - Not found"
        fi
    done
    
    echo "----------------------------------------"
}

  # Function to check for orphaned resources
  check_orphaned_resources() {
    local env=$1
    
    print_status "Checking for orphaned resources in environment: $env"
    
    # Check for orphaned ECS services
    local ecs_services=$(aws ecs list-services --cluster "bazar-cluster-$env" --query 'serviceArns' --output text 2>/dev/null || echo "")
    if [[ -n "$ecs_services" ]]; then
        print_warning "Found ECS services that may need manual cleanup:"
        echo "$ecs_services"
    fi
    
    # Check for orphaned ECS clusters
    local ecs_clusters=$(aws ecs list-clusters --query 'clusterArns' --output text 2>/dev/null || echo "")
    if [[ -n "$ecs_clusters" ]]; then
        print_warning "Found ECS clusters that may need manual cleanup:"
        echo "$ecs_clusters"
    fi
    
    # Check for orphaned load balancers
    local load_balancers=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `bazar-*`)].LoadBalancerName' --output text 2>/dev/null || echo "")
    if [[ -n "$load_balancers" ]]; then
        print_warning "Found load balancers that may need manual cleanup:"
        echo "$load_balancers"
    fi
    
    # Check for orphaned security groups
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=bazar-*-$env" \
        --profile "${AWS_PROFILE:-default}" \
        --query 'SecurityGroups[].GroupName' \
        --output text 2>/dev/null || echo "")
    if [[ -n "$security_groups" ]]; then
        print_warning "Found security groups that may need manual cleanup:"
        echo "$security_groups"
    fi
    
    # Check for S3 buckets (these are retained by design)
    local s3_buckets=$(aws s3 ls --profile "${AWS_PROFILE:-default}" | grep "bazar-.*-$env" | awk '{print $3}' 2>/dev/null || echo "")
    if [[ -n "$s3_buckets" ]]; then
        print_warning "Found S3 buckets that are RETAINED by design (DeletionPolicy: Retain):"
        echo "$s3_buckets"
        print_warning "These buckets will NOT be automatically deleted. You must manually delete them via AWS Console if needed."
        print_warning "Note: S3 buckets with data can take a very long time to delete."
        print_warning "S3 buckets include: database backups and static assets."
    fi
  }



# Main script
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <environment> [stack_name]"
        echo "Environments: dev, prod"
        echo "Stacks: vpc, compute, database, all, list, check"
        echo ""
        echo "Examples:"
        echo "  $0 dev                    # Delete all stacks for dev"
        echo "  $0 prod database          # Delete only database stack for prod"
        echo "  $0 dev vpc                # Delete only VPC stack for dev"
        echo "  $0 dev list               # List all stacks for dev"
        echo "  $0 dev check              # Check for orphaned resources"
        exit 1
    fi
    
    local environment=$1
    local stack_name=${2:-"all"}
    
    # Validate environment
    if [[ "$environment" != "dev" && "$environment" != "prod" ]]; then
        print_error "Invalid environment: $environment. Use 'dev' or 'prod'."
        exit 1
    fi
    
    # Validate stack name
    if [[ "$stack_name" != "all" && "$stack_name" != "vpc" && "$stack_name" != "compute" && "$stack_name" != "database" && "$stack_name" != "list" && "$stack_name" != "check" ]]; then
        print_error "Invalid stack name: $stack_name. Use 'vpc', 'compute', 'database', 'all', 'list', or 'check'."
        exit 1
    fi
    
    print_status "Starting teardown for environment: $environment"
    print_status "Target: $stack_name"
    
    # Check prerequisites
    check_aws_cli
    
    # Execute based on stack name
    case $stack_name in
        "vpc")
            delete_vpc "$environment"
            ;;
        "compute")
            delete_compute "$environment"
            ;;
        "database")
            delete_database "$environment"
            ;;
        "all")
            delete_all "$environment"
            ;;
        "list")
            list_stacks "$environment"
            ;;
        "check")
            check_orphaned_resources "$environment"
            ;;
        *)
            print_error "Unknown action: $stack_name"
            exit 1
            ;;
    esac
    
    if [[ "$stack_name" != "list" && "$stack_name" != "check" ]]; then
        print_success "Teardown completed successfully!"
        
        # Check for orphaned resources after deletion
        if [[ "$stack_name" == "all" ]]; then
            echo
            check_orphaned_resources "$environment"
        fi
    fi
}

# Run main function with all arguments
main "$@" 