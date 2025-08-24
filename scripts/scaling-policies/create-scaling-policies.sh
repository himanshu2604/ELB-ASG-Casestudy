#!/bin/bash

# AWS Auto-Scaling Policies Creation Script
# XYZ Corporation Infrastructure Migration
# Version: 1.2.0

set -e

# Configuration variables
ASG_NAME="XYZ-Corp-AutoScaling-Group"
REGION="us-east-1"
SCALE_UP_POLICY_NAME="XYZ-ScaleUp-Policy"
SCALE_DOWN_POLICY_NAME="XYZ-ScaleDown-Policy"
TARGET_TRACKING_POLICY_NAME="XYZ-TargetTracking-Policy"

echo "🚀 Creating Auto Scaling Policies for XYZ Corporation"
echo "=================================================="

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS CLI not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    echo "✅ AWS CLI configured successfully"
}

# Create Step Scaling Policy for Scale-Up
create_scale_up_policy() {
    echo "📈 Creating Scale-Up Policy..."
    
    aws autoscaling put-scaling-policy \
        --region $REGION \
        --auto-scaling-group-name $ASG_NAME \
        --policy-name $SCALE_UP_POLICY_NAME \
        --policy-type "StepScaling" \
        --adjustment-type "ChangeInCapacity" \
        --metric-aggregation-type "Average" \
        --step-adjustments MetricIntervalLowerBound=0,MetricIntervalUpperBound=10,ScalingAdjustment=1 \
                            MetricIntervalLowerBound=10,ScalingAdjustment=2 \
        --cooldown 300
    
    echo "✅ Scale-Up Policy created successfully"
}

# Create Step Scaling Policy for Scale-Down
create_scale_down_policy() {
    echo "📉 Creating Scale-Down Policy..."
    
    aws autoscaling put-scaling-policy \
        --region $REGION \
        --auto-scaling-group-name $ASG_NAME \
        --policy-name $SCALE_DOWN_POLICY_NAME \
        --policy-type "StepScaling" \
        --adjustment-type "ChangeInCapacity" \
        --metric-aggregation-type "Average" \
        --step-adjustments MetricIntervalUpperBound=0,ScalingAdjustment=-1 \
        --cooldown 300
    
    echo "✅ Scale-Down Policy created successfully"
}

# Create Target Tracking Scaling Policy
create_target_tracking_policy() {
    echo "🎯 Creating Target Tracking Policy..."
    
    aws autoscaling put-scaling-policy \
        --region $REGION \
        --auto-scaling-group-name $ASG_NAME \
        --policy-name $TARGET_TRACKING_POLICY_NAME \
        --policy-type "TargetTrackingScaling" \
        --target-tracking-configuration file://target-tracking-policy.json
    
    echo "✅ Target Tracking Policy created successfully"
}

# Get scaling policy ARNs for CloudWatch alarms
get_policy_arns() {
    echo "🔍 Retrieving Policy ARNs..."
    
    SCALE_UP_ARN=$(aws autoscaling describe-policies \
        --region $REGION \
        --auto-scaling-group-name $ASG_NAME \
        --policy-names $SCALE_UP_POLICY_NAME \
        --query 'ScalingPolicies[0].PolicyARN' \
        --output text)
    
    SCALE_DOWN_ARN=$(aws autoscaling describe-policies \
        --region $REGION \
        --auto-scaling-group-name $ASG_NAME \
        --policy-names $SCALE_DOWN_POLICY_NAME \
        --query 'ScalingPolicies[0].PolicyARN' \
        --output text)
    
    echo "📋 Policy ARNs:"
    echo "Scale-Up ARN: $SCALE_UP_ARN"
    echo "Scale-Down ARN: $SCALE_DOWN_ARN"
    
    # Save ARNs to file for CloudWatch alarm setup
    cat > policy-arns.txt << EOF
SCALE_UP_POLICY_ARN=$SCALE_UP_ARN
SCALE_DOWN_POLICY_ARN=$SCALE_DOWN_ARN
EOF
    
    echo "✅ Policy ARNs saved to policy-arns.txt"
}

# Main execution
main() {
    echo "Starting Auto Scaling Policies setup..."
    
    check_aws_cli
    
    # Check if Auto Scaling Group exists
    if ! aws autoscaling describe-auto-scaling-groups \
         --region $REGION \
         --auto-scaling-group-names $ASG_NAME &> /dev/null; then
        echo "❌ Auto Scaling Group '$ASG_NAME' not found. Please create it first."
        exit 1
    fi
    
    create_scale_up_policy
    create_scale_down_policy
    create_target_tracking_policy
    get_policy_arns
    
    echo ""
    echo "🎉 All Auto Scaling Policies created successfully!"
    echo "📝 Next steps:"
    echo "   1. Run setup-monitoring.sh to create CloudWatch alarms"
    echo "   2. Test scaling policies with scaling-test.py"
    echo "   3. Monitor scaling events in CloudWatch console"
}

# Execute main function
main "$@"