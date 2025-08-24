#!/bin/bash

# Automated CloudWatch Alarms Configuration
# XYZ Corporation Auto-Scaling Solution
# Version: 1.2.0

set -e

# Configuration
REGION="us-east-1"
ASG_NAME="XYZ-Corp-AutoScaling-Group"
ALB_NAME="XYZ-Corp-LoadBalancer"
TARGET_GROUP_NAME="XYZ-Corp-TargetGroup"

echo "⚠️ Creating CloudWatch Alarms for XYZ Corporation Auto-Scaling"
echo "============================================================="

# Check if policy ARNs file exists
if [[ ! -f "policy-arns.txt" ]]; then
    echo "❌ policy-arns.txt not found. Please run create-scaling-policies.sh first."
    exit 1
fi

# Load policy ARNs and SNS topic
source policy-arns.txt

# Create CPU utilization alarms
create_cpu_alarms() {
    echo "🖥️ Creating CPU utilization alarms..."
    
    # High CPU alarm (Scale-Up trigger)
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-CPU-High-ScaleUp" \
        --alarm-description "Triggers scale-up when average CPU > 80% for 2 periods" \
        --metric-name CPUUtilization \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 2 \
        --datapoints-to-alarm 2 \
        --alarm-actions $SCALE_UP_POLICY_ARN \
        --ok-actions $SNS_TOPIC_ARN \
        --unit Percent \
        --treat-missing-data notBreaching
    
    # Low CPU alarm (Scale-Down trigger)  
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-CPU-Low-ScaleDown" \
        --alarm-description "Triggers scale-down when average CPU < 60% for 3 periods" \
        --metric-name CPUUtilization \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 60 \
        --comparison-operator LessThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 3 \
        --datapoints-to-alarm 3 \
        --alarm-actions $SCALE_DOWN_POLICY_ARN \
        --ok-actions $SNS_TOPIC_ARN \
        --unit Percent \
        --treat-missing-data notBreaching
    
    echo "✅ CPU utilization alarms created"
}

# Create Application Load Balancer alarms
create_alb_alarms() {
    echo "⚖️ Creating Application Load Balancer alarms..."
    
    # High response time alarm
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-ALB-HighResponseTime" \
        --alarm-description "Alert when ALB response time > 200ms" \
        --metric-name TargetResponseTime \
        --namespace AWS/ApplicationELB \
        --statistic Average \
        --period 300 \
        --threshold 0.2 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=LoadBalancer,Value=$ALB_NAME \
        --evaluation-periods 2 \
        --datapoints-to-alarm 2 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Seconds \
        --treat-missing-data breaching
    
    # HTTP 5xx errors alarm
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-ALB-HTTP5XXErrors" \
        --alarm-description "Alert when 5xx error rate > 1% of total requests" \
        --metric-name HTTP_5XX_ELB_Error_Count \
        --namespace AWS/ApplicationELB \
        --statistic Sum \
        --period 300 \
        --threshold 5 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=LoadBalancer,Value=$ALB_NAME \
        --evaluation-periods 2 \
        --datapoints-to-alarm 2 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Count \
        --treat-missing-data notBreaching
    
    # Unhealthy host count alarm
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-UnhealthyHosts" \
        --alarm-description "Alert when unhealthy host count > 0" \
        --metric-name UnHealthyHostCount \
        --namespace AWS/ApplicationELB \
        --statistic Maximum \
        --period 300 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=TargetGroup,Value=$TARGET_GROUP_NAME Name=LoadBalancer,Value=$ALB_NAME \
        --evaluation-periods 2 \
        --datapoints-to-alarm 1 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Count \
        --treat-missing-data breaching
    
    echo "✅ Application Load Balancer alarms created"
}

# Create Auto Scaling Group health alarms
create_asg_alarms() {
    echo "🔄 Creating Auto Scaling Group health alarms..."
    
    # Group size alarm (minimum capacity check)
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-ASG-BelowMinCapacity" \
        --alarm-description "Alert when ASG has fewer than 2 healthy instances" \
        --metric-name GroupInServiceInstances \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 2 \
        --comparison-operator LessThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 1 \
        --datapoints-to-alarm 1 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Count \
        --treat-missing-data breaching
    
    # Group maximum capacity alarm
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-ASG-AtMaxCapacity" \
        --alarm-description "Alert when ASG reaches maximum capacity (10 instances)" \
        --metric-name GroupDesiredCapacity \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 10 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 1 \
        --datapoints-to-alarm 1 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Count \
        --treat-missing-data notBreaching
    
    echo "✅ Auto Scaling Group alarms created"
}

# Create network-related alarms
create_network_alarms() {
    echo "🌐 Creating network performance alarms..."
    
    # High network in alarm (potential DDoS or traffic spike)
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-HighNetworkIn" \
        --alarm-description "Alert when network in > 100MB for 5 minutes" \
        --metric-name NetworkIn \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 104857600 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 1 \
        --datapoints-to-alarm 1 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Bytes \
        --treat-missing-data notBreaching
    
    echo "✅ Network performance alarms created"
}

# Create cost monitoring alarm
create_cost_alarm() {
    echo "💰 Creating cost monitoring alarm..."
    
    # Monthly cost alarm (estimated)
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-EstimatedCharges" \
        --alarm-description "Alert when estimated monthly charges exceed $500" \
        --metric-name EstimatedCharges \
        --namespace AWS/Billing \
        --statistic Maximum \
        --period 86400 \
        --threshold 500 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=Currency,Value=USD \
        --evaluation-periods 1 \
        --datapoints-to-alarm 1 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit None \
        --treat-missing-data notBreaching
    
    echo "✅ Cost monitoring alarm created"
}

# List all created alarms
list_alarms() {
    echo "📋 Created CloudWatch Alarms:"
    echo "============================="
    
    aws cloudwatch describe-alarms \
        --region $REGION \
        --alarm-name-prefix "XYZ-" \
        --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
        --output table
}

# Main execution
main() {
    echo "Starting CloudWatch alarms creation..."
    
    # Verify prerequisites
    if [[ -z "$SCALE_UP_POLICY_ARN" ]] || [[ -z "$SCALE_DOWN_POLICY_ARN" ]] || [[ -z "$SNS_TOPIC_ARN" ]]; then
        echo "❌ Missing required ARNs. Please run create-scaling-policies.sh and setup-monitoring.sh first."
        exit 1
    fi
    
    create_cpu_alarms
    create_alb_alarms
    create_asg_alarms
    create_network_alarms
    create_cost_alarm
    
    echo ""
    echo "⏳ Waiting for alarms to initialize..."
    sleep 10
    
    list_alarms
    
    echo ""
    echo "🎉 All CloudWatch alarms created successfully!"
    echo ""
    echo "📋 Alarm Categories:"
    echo "   • CPU Utilization (Scale-Up/Scale-Down triggers)"
    echo "   • Application Load Balancer performance"
    echo "   • Auto Scaling Group health"
    echo "   • Network performance monitoring"
    echo "   • Cost monitoring and budget alerts"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Subscribe email/SMS to SNS topic: $SNS_TOPIC_ARN"
    echo "   2. Test alarms with validation/scaling-test.py"
    echo "   3. Monitor alarm states in CloudWatch console"
    echo "   4. Fine-tune thresholds based on application behavior"
}

# Execute main function
main "$@"