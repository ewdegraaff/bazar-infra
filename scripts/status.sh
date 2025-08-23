#!/bin/bash

# Bazar Infrastructure Status Script
# Usage: ./status.sh <environment> [stack_name]
# Example: ./status.sh dev
# Example: ./status.sh prod vpc

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${CYAN}$1${NC}"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured and working."
}

# Function to check if stack exists
stack_exists() {
    local stack_name=$1
    aws cloudformation describe-stacks --stack-name "$stack_name" &> /dev/null
}

# Function to get stack status
get_stack_status() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "STACK_NOT_FOUND"
}

# Function to get stack creation time
get_stack_creation_time() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].CreationTime' \
        --output text 2>/dev/null || echo "N/A"
}

# Function to get stack outputs
get_stack_outputs() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Outputs' \
        --output json 2>/dev/null || echo "[]"
}

# Function to get stack parameters
get_stack_parameters() {
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --query 'Stacks[0].Parameters' \
        --output json 2>/dev/null || echo "[]"
}

# Function to get stack events (last 5)
get_stack_events() {
    local stack_name=$1
    aws cloudformation describe-stack-events \
        --stack-name "$stack_name" \
        --max-items 5 \
        --query 'StackEvents[].{Time:Timestamp,Status:ResourceStatus,Type:ResourceType,LogicalId:LogicalResourceId}' \
        --output table 2>/dev/null || echo "No events found"
}

# Function to display stack status
display_stack_status() {
    local stack_name=$1
    local status=$(get_stack_status "$stack_name")
    local creation_time=$(get_stack_creation_time "$stack_name")
    
    echo "Stack: $stack_name"
    echo "Status: $status"
    echo "Created: $creation_time"
    echo "----------------------------------------"
}

# Function to display stack outputs
display_stack_outputs() {
    local stack_name=$1
    local outputs=$(get_stack_outputs "$stack_name")
    
    if [[ "$outputs" != "[]" ]]; then
        echo "Outputs:"
        echo "$outputs" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"' 2>/dev/null || echo "  (Unable to parse outputs)"
    else
        echo "Outputs: None"
    fi
    echo
}

# Function to display stack parameters
display_stack_parameters() {
    local stack_name=$1
    local parameters=$(get_stack_parameters "$stack_name")
    
    if [[ "$outputs" != "[]" ]]; then
        echo "Parameters:"
        echo "$parameters" | jq -r '.[] | "  \(.ParameterKey): \(.ParameterValue)"' 2>/dev/null || echo "  (Unable to parse parameters)"
    else
        echo "Parameters: None"
    fi
    echo
}

# Function to display stack events
display_stack_events() {
    local stack_name=$1
    echo "Recent Events:"
    get_stack_events "$stack_name"
    echo
}

# Function to show VPC stack status
show_vpc_status() {
    local env=$1
    local stack_name="bazar-vpc-$env"
    
    print_header "VPC Stack Status"
    echo "=================="
    
    if stack_exists "$stack_name"; then
        display_stack_status "$stack_name"
        display_stack_outputs "$stack_name"
        
        # Show VPC-specific information
        local vpc_id=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        if [[ "$vpc_id" != "N/A" && "$vpc_id" != "None" ]]; then
            echo "VPC Details:"
            echo "  VPC ID: $vpc_id"
            
            # Get subnet information
            local public_subnet_id=$(aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetId`].OutputValue' \
                --output text 2>/dev/null || echo "N/A")
            
            local private_app_subnet_id=$(aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --query 'Stacks[0].Outputs[?OutputKey==`PrivateAppSubnetId`].OutputValue' \
                --output text 2>/dev/null || echo "N/A")
            
            local private_data_subnet_id=$(aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --query 'Stacks[0].Outputs[?OutputKey==`PrivateDataSubnetId`].OutputValue' \
                --output text 2>/dev/null || echo "N/A")
            
            echo "  Public Subnet: $public_subnet_id"
            echo "  Private App Subnet: $private_app_subnet_id"
            echo "  Private Data Subnet: $private_data_subnet_id"
        fi
    else
        echo "Stack '$stack_name' does not exist."
    fi
    echo
}

# Function to show compute stack status
show_compute_status() {
    local env=$1
    local stack_name="bazar-compute-$env"
    
    print_header "Compute Stack Status"
    echo "======================="
    
    if stack_exists "$stack_name"; then
        display_stack_status "$stack_name"
        display_stack_outputs "$stack_name"
        
        # Show ECS-specific information
        local cluster_name=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`EcsClusterName`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        if [[ "$cluster_name" != "N/A" && "$cluster_name" != "None" ]]; then
            echo "ECS Details:"
            echo "  Cluster: $cluster_name"
            
            # Get ECS service status
            local service_name=$(aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --query 'Stacks[0].Outputs[?OutputKey==`EcsServiceName`].OutputValue' \
                --output text 2>/dev/null || echo "N/A")
            
            if [[ "$service_name" != "N/A" && "$service_name" != "None" ]]; then
                echo "  Service: $service_name"
                
                # Get service status
                local service_status=$(aws ecs describe-services \
                    --cluster "$cluster_name" \
                    --services "$service_name" \
                    --query 'services[0].status' \
                    --output text 2>/dev/null || echo "Unknown")
                
                local desired_count=$(aws ecs describe-services \
                    --cluster "$cluster_name" \
                    --services "$service_name" \
                    --query 'services[0].desiredCount' \
                    --output text 2>/dev/null || echo "0")
                
                local running_count=$(aws ecs describe-services \
                    --cluster "$cluster_name" \
                    --services "$service_name" \
                    --query 'services[0].runningCount' \
                    --output text 2>/dev/null || echo "0")
                
                echo "  Service Status: $service_status"
                echo "  Desired Tasks: $desired_count"
                echo "  Running Tasks: $running_count"
            fi
        fi
        
        # Show ALB information
        local alb_dns=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`AlbDnsName`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        if [[ "$alb_dns" != "N/A" && "$alb_dns" != "None" ]]; then
            echo "Load Balancer:"
            echo "  DNS Name: $alb_dns"
        fi
    else
        echo "Stack '$stack_name' does not exist."
    fi
    echo
}

# Function to show database stack status
show_database_status() {
    local env=$1
    local stack_name="bazar-database-$env"
    
    print_header "Database Stack Status"
    echo "========================"
    
    if stack_exists "$stack_name"; then
        display_stack_status "$stack_name"
        display_stack_outputs "$stack_name"
        
        # Show RDS-specific information
        local rds_endpoint=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`RdsEndpoint`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        if [[ "$rds_endpoint" != "N/A" && "$rds_endpoint" != "None" ]]; then
            echo "RDS Details:"
            echo "  Endpoint: $rds_endpoint"
            
            # Get RDS instance status
            local db_instance_id="bazar-postgres-$env"
            local db_status=$(aws rds describe-db-instances \
                --db-instance-identifier "$db_instance_id" \
                --query 'DBInstances[0].DBInstanceStatus' \
                --output text 2>/dev/null || echo "Unknown")
            
            local db_class=$(aws rds describe-db-instances \
                --db-instance-identifier "$db_instance_id" \
                --query 'DBInstances[0].DBInstanceClass' \
                --output text 2>/dev/null || echo "Unknown")
            
            local db_storage=$(aws rds describe-db-instances \
                --db-instance-identifier "$db_instance_id" \
                --query 'DBInstances[0].AllocatedStorage' \
                --output text 2>/dev/null || echo "Unknown")
            
            echo "  Status: $db_status"
            echo "  Instance Class: $db_class"
            echo "  Storage: ${db_storage}GB"
        fi
        
        # Show S3 information
        local s3_backup_bucket=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`S3BackupBucketName`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        local s3_static_bucket=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --query 'Stacks[0].Outputs[?OutputKey==`S3StaticAssetsBucketName`].OutputValue' \
            --output text 2>/dev/null || echo "N/A")
        
        if [[ "$s3_backup_bucket" != "N/A" && "$s3_backup_bucket" != "None" ]]; then
            echo "S3 Backup Bucket:"
            echo "  Bucket: $s3_backup_bucket"
            
            # Get bucket size
            local bucket_size=$(aws s3 ls s3://"$s3_backup_bucket" --recursive --human-readable --summarize 2>/dev/null | tail -1 | awk '{print $3, $4}' || echo "Unknown")
            echo "  Size: $bucket_size"
        fi
        
        if [[ "$s3_static_bucket" != "N/A" && "$s3_static_bucket" != "None" ]]; then
            echo "S3 Static Assets Bucket:"
            echo "  Bucket: $s3_static_bucket"
            
            # Get bucket size
            local bucket_size=$(aws s3 ls s3://"$s3_static_bucket" --recursive --human-readable --summarize 2>/dev/null | tail -1 | awk '{print $3, $4}' || echo "Unknown")
            echo "  Size: $bucket_size"
        fi
    else
        echo "Stack '$stack_name' does not exist."
    fi
    echo
}

# Function to show all stacks status
show_all_status() {
    local env=$1
    
    print_header "Complete Infrastructure Status for Environment: $env"
    echo "================================================================"
    echo
    
    show_vpc_status "$env"
    show_compute_status "$env"
    show_database_status "$env"
    
    # Summary
    print_header "Summary"
    echo "======="
    
    local stacks=(
        "bazar-vpc-$env"
        "bazar-compute-$env"
        "bazar-database-$env"
    )
    
    local total_stacks=${#stacks[@]}
    local existing_stacks=0
    local healthy_stacks=0
    
    for stack in "${stacks[@]}"; do
        if stack_exists "$stack"; then
            existing_stacks=$((existing_stacks + 1))
            local status=$(get_stack_status "$stack")
            if [[ "$status" == "CREATE_COMPLETE" || "$status" == "UPDATE_COMPLETE" ]]; then
                healthy_stacks=$((healthy_stacks + 1))
            fi
        fi
    done
    
    echo "Total Stacks: $total_stacks"
    echo "Existing Stacks: $existing_stacks"
    echo "Healthy Stacks: $healthy_stacks"
    
    if [[ $existing_stacks -eq $total_stacks && $healthy_stacks -eq $total_stacks ]]; then
        print_success "All infrastructure stacks are healthy!"
    elif [[ $existing_stacks -eq $total_stacks ]]; then
        print_warning "All stacks exist but some may have issues."
    else
        print_error "Some infrastructure stacks are missing."
    fi
}

# Function to show detailed stack information
show_detailed_status() {
    local env=$1
    local stack_name=$2
    local full_stack_name="bazar-$stack_name-$env"
    
    print_header "Detailed Status for Stack: $full_stack_name"
    echo "================================================"
    
    if stack_exists "$full_stack_name"; then
        display_stack_status "$full_stack_name"
        display_stack_parameters "$full_stack_name"
        display_stack_outputs "$full_stack_name"
        display_stack_events "$full_stack_name"
    else
        echo "Stack '$full_stack_name' does not exist."
    fi
}

# Main script
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <environment> [stack_name]"
        echo "Environments: dev, prod"
        echo "Stacks: vpc, compute, database, all, detailed"
        echo ""
        echo "Examples:"
        echo "  $0 dev                    # Show status of all stacks for dev"
        echo "  $0 prod vpc              # Show status of VPC stack for prod"
        echo "  $0 dev compute           # Show status of compute stack for dev"
        echo "  $0 dev detailed vpc      # Show detailed status of VPC stack for dev"
        exit 1
    fi
    
    local environment=$1
    local stack_name=${2:-"all"}
    local detailed=${3:-""}
    
    # Validate environment
    if [[ "$environment" != "dev" && "$environment" != "prod" ]]; then
        print_error "Invalid environment: $environment. Use 'dev' or 'prod'."
        exit 1
    fi
    
    # Validate stack name
    if [[ "$stack_name" != "all" && "$stack_name" != "vpc" && "$stack_name" != "compute" && "$stack_name" != "database" && "$stack_name" != "detailed" ]]; then
        print_error "Invalid stack name: $stack_name. Use 'vpc', 'compute', 'database', 'all', or 'detailed'."
        exit 1
    fi
    
    # Check prerequisites
    check_aws_cli
    
    # Execute based on stack name
    case $stack_name in
        "vpc")
            show_vpc_status "$environment"
            ;;
        "compute")
            show_compute_status "$environment"
            ;;
        "database")
            show_database_status "$environment"
            ;;
        "all")
            show_all_status "$environment"
            ;;
        "detailed")
            if [[ -z "$detailed" ]]; then
                print_error "Please specify which stack to show detailed status for."
                echo "Usage: $0 <environment> detailed <stack_name>"
                exit 1
            fi
            show_detailed_status "$environment" "$detailed"
            ;;
        *)
            print_error "Unknown stack: $stack_name"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 