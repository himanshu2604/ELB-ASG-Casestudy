#!/bin/bash

# CloudWatch Monitoring Setup Script
# XYZ Corporation Auto-Scaling Solution
# Version: 1.2.0

set -e

# Configuration variables
REGION="us-east-1"
ASG_NAME="XYZ-Corp-AutoScaling-Group"
ALB_NAME="XYZ-Corp-LoadBalancer"
DASHBOARD_NAME="XYZ-Corp-AutoScaling-Dashboard"
SNS_TOPIC_NAME="XYZ-Corp-Scaling-Notifications"

echo "📊 Setting up CloudWatch Monitoring for XYZ Corporation"
echo "======================================================"

# Function to check prerequisites
check_prerequisites() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    if [[ ! -f "policy-arns.txt" ]]; then
        echo "❌ policy-arns.txt not found. Please run create-scaling-policies.sh first."
        exit 1
    fi
    
    # Load policy ARNs
    source policy-arns.txt
    
    echo "✅ Prerequisites checked successfully"
}

# Create SNS topic for notifications
create_sns_topic() {
    echo "📢 Creating SNS topic for scaling notifications..."
    
    SNS_TOPIC_ARN=$(aws sns create-topic \
        --region $REGION \
        --name $SNS_TOPIC_NAME \
        --query 'TopicArn' \
        --output text)
    
    echo "✅ SNS Topic created: $SNS_TOPIC_ARN"
    
    # Save SNS ARN for later use
    echo "SNS_TOPIC_ARN=$SNS_TOPIC_ARN" >> policy-arns.txt
}

# Create CloudWatch alarms for scaling
create_scaling_alarms() {
    echo "⚠️ Creating CloudWatch alarms for auto-scaling..."
    
    # High CPU alarm for scale-up
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-HighCPU-ScaleUp" \
        --alarm-description "Scale up when CPU exceeds 80%" \
        --metric-name CPUUtilization \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 2 \
        --alarm-actions $SCALE_UP_POLICY_ARN $SNS_TOPIC_ARN \
        --unit Percent
    
    # Low CPU alarm for scale-down
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-LowCPU-ScaleDown" \
        --alarm-description "Scale down when CPU below 60%" \
        --metric-name CPUUtilization \
        --namespace AWS/AutoScaling \
        --statistic Average \
        --period 300 \
        --threshold 60 \
        --comparison-operator LessThanThreshold \
        --dimensions Name=AutoScalingGroupName,Value=$ASG_NAME \
        --evaluation-periods 2 \
        --alarm-actions $SCALE_DOWN_POLICY_ARN $SNS_TOPIC_ARN \
        --unit Percent
    
    # ALB Target Response Time alarm
    aws cloudwatch put-metric-alarm \
        --region $REGION \
        --alarm-name "XYZ-HighResponseTime" \
        --alarm-description "Alert when response time exceeds 200ms" \
        --metric-name TargetResponseTime \
        --namespace AWS/ApplicationELB \
        --statistic Average \
        --period 300 \
        --threshold 0.2 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=LoadBalancer,Value=$ALB_NAME \
        --evaluation-periods 2 \
        --alarm-actions $SNS_TOPIC_ARN \
        --unit Seconds
    
    echo "✅ CloudWatch alarms created successfully"
}

# Create custom CloudWatch dashboard
create_dashboard() {
    echo "📈 Creating CloudWatch dashboard..."
    
    cat > dashboard-config.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/AutoScaling", "GroupDesiredCapacity", "AutoScalingGroupName", "XYZ-Corp-AutoScaling-Group" ],
                    [ ".", "GroupInServiceInstances", ".", "." ],
                    [ ".", "GroupTotalInstances", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Auto Scaling Group Capacity"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/AutoScaling", "CPUUtilization", "AutoScalingGroupName", "XYZ-Corp-AutoScaling-Group" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "CPU Utilization",
                "yAxis": {
                    "left": {
                        "min": 0,
                        "max": 100
                    }
                }
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "XYZ-Corp-LoadBalancer" ],
                    [ ".", "TargetResponseTime", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Load Balancer Metrics"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "XYZ-Corp-TargetGroup", "LoadBalancer", "XYZ-Corp-LoadBalancer" ],
                    [ ".", "UnHealthyHostCount", ".", ".", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Target Health Status"
            }
        }
    ]
}
EOF

    aws cloudwatch put-dashboard \
        --region $REGION \
        --dashboard-name $DASHBOARD_NAME \
        --dashboard-body file://dashboard-config.json
    
    echo "✅ CloudWatch dashboard created: $DASHBOARD_NAME"
}

# Create custom metrics script
create_custom_metrics_script() {
    echo "📊 Creating custom metrics collection script..."
    
    cat > custom-metrics.py << 'EOF'
#!/usr/bin/env python3

import boto3
import time
import requests
import json
from datetime import datetime

def publish_custom_metrics():
    """Publish custom application metrics to CloudWatch"""
    
    cloudwatch = boto3.client('cloudwatch', region_name='us-east-1')
    
    try:
        # Simulate application-specific metrics
        # In real implementation, these would come from your application
        
        # Example: Application response time
        app_response_time = 0.15  # 150ms
        
        # Example: Active connections count
        active_connections = 45
        
        # Example: Application errors per minute
        error_rate = 0.5
        
        # Publish metrics
        cloudwatch.put_metric_data(
            Namespace='XYZ/Application',
            MetricData=[
                {
                    'MetricName': 'ApplicationResponseTime',
                    'Value': app_response_time,
                    'Unit': 'Seconds',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'ActiveConnections',
                    'Value': active_connections,
                    'Unit': 'Count',
                    'Timestamp': datetime.utcnow()
                },
                {
                    'MetricName': 'ErrorRate',
                    'Value': error_rate,
                    'Unit': 'Count/Second',
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
        
        print(f"✅ Custom metrics published at {datetime.utcnow()}")
        
    except Exception as e:
        print(f"❌ Error publishing metrics: {str(e)}")

if __name__ == "__main__":
    publish_custom_metrics()
EOF

    chmod +x custom-metrics.py
    echo "✅ Custom metrics script created: custom-metrics.py"
}

# Main execution
main() {
    echo "Starting CloudWatch monitoring setup..."
    
    check_prerequisites
    create_sns_topic
    create_scaling_alarms
    create_dashboard
    create_custom_metrics_script
    
    echo ""
    echo "🎉 CloudWatch monitoring setup completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "   • SNS topic created for scaling notifications"
    echo "   • CloudWatch alarms created for auto-scaling triggers"
    echo "   • Custom dashboard created: $DASHBOARD_NAME"
    echo "   • Custom metrics collection script ready"
    echo ""
    echo "🔗 Access your dashboard:"
    echo "   https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$DASHBOARD_NAME"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Subscribe to SNS topic for notifications"
    echo "   2. Run validation/health-check-validator.sh"
    echo "   3. Test scaling with validation/scaling-test.py"
    echo "   4. Schedule custom-metrics.py for regular execution"
}

# Execute main function
main "$@"