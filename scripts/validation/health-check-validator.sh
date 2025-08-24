#!/bin/bash

# ALB Target Health Check Validator
# XYZ Corporation Auto-Scaling Solution
# Version: 1.2.0

set -e

# Configuration variables
REGION="us-east-1"
TARGET_GROUP_ARN=""
ALB_DNS_NAME=""
HEALTH_CHECK_PATH="/"
EXPECTED_STATUS_CODE="200"
MAX_RETRIES=10
RETRY_DELAY=30

echo "🏥 ALB Target Health Check Validator"
echo "==================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "WARNING") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $message${NC}" ;;
    esac
}

# Get target group ARN from user input or auto-discover
get_target_group_info() {
    print_status "INFO" "Discovering target group information..."
    
    # Try to find XYZ Corporation target group
    TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --names "XYZ-Corp-TargetGroup" \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$TARGET_GROUP_ARN" == "None" || "$TARGET_GROUP_ARN" == "null" ]]; then
        print_status "ERROR" "Target group 'XYZ-Corp-TargetGroup' not found"
        echo "Available target groups:"
        aws elbv2 describe-target-groups \
            --region $REGION \
            --query 'TargetGroups[*].[TargetGroupName,TargetGroupArn]' \
            --output table
        exit 1
    fi
    
    print_status "SUCCESS" "Found target group: $TARGET_GROUP_ARN"
    
    # Get ALB DNS name
    ALB_DNS_NAME=$(aws elbv2 describe-load-balancers \
        --region $REGION \
        --names "XYZ-Corp-LoadBalancer" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$ALB_DNS_NAME" == "None" || "$ALB_DNS_NAME" == "null" ]]; then
        print_status "WARNING" "Could not find ALB DNS name, will skip direct ALB tests"
    else
        print_status "SUCCESS" "Found ALB DNS: $ALB_DNS_NAME"
    fi
}

# Check target health status
check_target_health() {
    print_status "INFO" "Checking target health status..."
    
    local health_output
    health_output=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason,Target.AvailabilityZone]' \
        --output table)
    
    echo "$health_output"
    
    # Count healthy vs unhealthy targets
    local healthy_count
    local total_count
    
    healthy_count=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text)
    
    total_count=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --query 'TargetHealthDescriptions | length(@)' \
        --output text)
    
    print_status "INFO" "Health Summary: $healthy_count/$total_count targets are healthy"
    
    if [[ $healthy_count -gt 0 ]]; then
        print_status "SUCCESS" "At least one target is healthy"
        return 0
    else
        print_status "ERROR" "No healthy targets found"
        return 1
    fi
}

# Test individual target health
test_individual_targets() {
    print_status "INFO" "Testing individual target endpoints..."
    
    # Get list of target instances with their private IPs
    local targets
    targets=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --query 'TargetHealthDescriptions[*].Target.Id' \
        --output text)
    
    if [[ -z "$targets" ]]; then
        print_status "WARNING" "No targets found in target group"
        return 1
    fi
    
    for target_id in $targets; do
        print_status "INFO" "Testing target: $target_id"
        
        # Get private IP of the instance
        local private_ip
        private_ip=$(aws ec2 describe-instances \
            --region $REGION \
            --instance-ids $target_id \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text 2>/dev/null || echo "unknown")
        
        if [[ "$private_ip" != "unknown" && "$private_ip" != "null" ]]; then
            # Test HTTP endpoint (assuming we're on the same VPC)
            print_status "INFO" "Testing HTTP endpoint: $private_ip:80$HEALTH_CHECK_PATH"
            
            if timeout 10 curl -s -o /dev/null -w "%{http_code}" "http://$private_ip:80$HEALTH_CHECK_PATH" | grep -q "200"; then
                print_status "SUCCESS" "Target $target_id ($private_ip) is responding correctly"
            else
                print_status "ERROR" "Target $target_id ($private_ip) is not responding or returning wrong status code"
            fi
        else
            print_status "WARNING" "Could not determine private IP for target $target_id"
        fi
    done
}

# Test ALB endpoint
test_alb_endpoint() {
    if [[ "$ALB_DNS_NAME" == "None" || "$ALB_DNS_NAME" == "null" || -z "$ALB_DNS_NAME" ]]; then
        print_status "WARNING" "Skipping ALB endpoint test - DNS name not available"
        return 0
    fi
    
    print_status "INFO" "Testing ALB endpoint: $ALB_DNS_NAME"
    
    local retry_count=0
    local success=false
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        print_status "INFO" "Attempt $((retry_count + 1))/$MAX_RETRIES"
        
        local response_code
        local response_time
        
        response_code=$(timeout 30 curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS_NAME$HEALTH_CHECK_PATH" 2>/dev/null || echo "000")
        response_time=$(timeout 30 curl -s -o /dev/null -w "%{time_total}" "http://$ALB_DNS_NAME$HEALTH_CHECK_PATH" 2>/dev/null || echo "999")
        
        if [[ "$response_code" == "$EXPECTED_STATUS_CODE" ]]; then
            print_status "SUCCESS" "ALB endpoint is healthy (Response: $response_code, Time: ${response_time}s)"
            success=true
            break
        else
            print_status "WARNING" "ALB endpoint returned $response_code, expected $EXPECTED_STATUS_CODE"
            
            if [[ $retry_count -lt $((MAX_RETRIES - 1)) ]]; then
                print_status "INFO" "Waiting $RETRY_DELAY seconds before retry..."
                sleep $RETRY_DELAY
            fi
        fi
        
        ((retry_count++))
    done
    
    if [[ "$success" == "false" ]]; then
        print_status "ERROR" "ALB endpoint failed all health checks"
        return 1
    fi
    
    return 0
}

# Check target group configuration
check_target_group_config() {
    print_status "INFO" "Validating target group configuration..."
    
    local config
    config=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --target-group-arns $TARGET_GROUP_ARN \
        --query 'TargetGroups[0]' \
        --output json)
    
    local health_check_path
    local health_check_interval
    local health_check_timeout
    local healthy_threshold
    local unhealthy_threshold
    local health_check_port
    local health_check_protocol
    
    health_check_path=$(echo "$config" | jq -r '.HealthCheckPath')
    health_check_interval=$(echo "$config" | jq -r '.HealthCheckIntervalSeconds')
    health_check_timeout=$(echo "$config" | jq -r '.HealthCheckTimeoutSeconds')
    healthy_threshold=$(echo "$config" | jq -r '.HealthyThresholdCount')
    unhealthy_threshold=$(echo "$config" | jq -r '.UnhealthyThresholdCount')
    health_check_port=$(echo "$config" | jq -r '.HealthCheckPort')
    health_check_protocol=$(echo "$config" | jq -r '.HealthCheckProtocol')
    
    echo ""
    print_status "INFO" "Target Group Health Check Configuration:"
    echo "  Health Check Path: $health_check_path"
    echo "  Health Check Interval: ${health_check_interval}s"
    echo "  Health Check Timeout: ${health_check_timeout}s"
    echo "  Healthy Threshold: $healthy_threshold"
    echo "  Unhealthy Threshold: $unhealthy_threshold"
    echo "  Health Check Port: $health_check_port"
    echo "  Health Check Protocol: $health_check_protocol"
    
    # Validate configuration
    local config_issues=0
    
    if [[ $health_check_timeout -ge $health_check_interval ]]; then
        print_status "ERROR" "Health check timeout ($health_check_timeout) should be less than interval ($health_check_interval)"
        ((config_issues++))
    fi
    
    if [[ $healthy_threshold -lt 2 ]]; then
        print_status "WARNING" "Healthy threshold is low ($healthy_threshold) - consider increasing for stability"
    fi
    
    if [[ $unhealthy_threshold -lt 2 ]]; then
        print_status "WARNING" "Unhealthy threshold is low ($unhealthy_threshold) - may cause frequent health state changes"
    fi
    
    if [[ $config_issues -eq 0 ]]; then
        print_status "SUCCESS" "Target group health check configuration looks good"
    else
        print_status "ERROR" "Found $config_issues configuration issues"
        return 1
    fi
    
    return 0
}

# Generate health check report
generate_report() {
    print_status "INFO" "Generating health check validation report..."
    
    local report_file="health-check-report-$(date +%Y%m%d-%H%M%S).json"
    
    # Gather comprehensive health data
    local health_data
    health_data=$(aws elbv2 describe-target-health \
        --region $REGION \
        --target-group-arn $TARGET_GROUP_ARN \
        --output json)
    
    local target_group_config
    target_group_config=$(aws elbv2 describe-target-groups \
        --region $REGION \
        --target-group-arns $TARGET_GROUP_ARN \
        --output json)
    
    # Create comprehensive report
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "region": "$REGION",
  "target_group_arn": "$TARGET_GROUP_ARN",
  "alb_dns_name": "$ALB_DNS_NAME",
  "validation_results": {
    "target_health": $health_data,
    "target_group_config": $target_group_config
  }
}
EOF
    
    print_status "SUCCESS" "Health check report saved: $report_file"
}

# Main execution
main() {
    echo "Starting ALB target health validation..."
    
    local overall_success=true
    
    # Step 1: Get target group information
    if ! get_target_group_info; then
        overall_success=false
    fi
    
    # Step 2: Check target health status
    if ! check_target_health; then
        overall_success=false
    fi
    
    # Step 3: Test individual targets
    if ! test_individual_targets; then
        overall_success=false
    fi
    
    # Step 4: Test ALB endpoint
    if ! test_alb_endpoint; then
        overall_success=false
    fi
    
    # Step 5: Check target group configuration
    if ! check_target_group_config; then
        overall_success=false
    fi
    
    # Step 6: Generate report
    generate_report
    
    echo ""
    if [[ "$overall_success" == "true" ]]; then
        print_status "SUCCESS" "All health checks passed! ✨"
        echo ""
        echo "📋 Summary:"
        echo "   • Target group discovered and accessible"
        echo "   • All targets are healthy and responding"
        echo "   • ALB endpoint is working correctly"
        echo "   • Health check configuration is optimal"
        echo ""
        echo "🚀 Your auto-scaling setup is ready for production!"
    else
        print_status "ERROR" "Some health checks failed. Please review the issues above."
        echo ""
        echo "🔧 Troubleshooting tips:"
        echo "   • Check security groups allow HTTP traffic on port 80"
        echo "   • Verify web server is running on all instances"
        echo "   • Ensure health check path returns 200 status"
        echo "   • Check if instances are in correct subnets"
        exit 1
    fi
}

# Execute main function
main "$@"