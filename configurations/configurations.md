# Core Configuration Files

## File Structure for v1.1.0

```
⚙️ configurations/
├── launch-template.json
├── autoscaling-group.json
├── load-balancer.json
├── security-groups.json
├── route53-records.json
└── cloudwatch-alarms.json

🔧 scripts/user-data/
└── webserver-setup.sh
```

---

## 1. Launch Template Configuration
**File: `configurations/launch-template.json`**

```json
{
  "LaunchTemplateName": "XYZ-Corp-WebServer-Template",
  "LaunchTemplateData": {
    "ImageId": "ami-0abcdef1234567890",
    "InstanceType": "t3.medium",
    "KeyName": "xyz-corp-keypair",
    "SecurityGroupIds": [
      "sg-webserver123456"
    ],
    "UserData": "IyEvYmluL2Jhc2gKd3VtIHVwZGF0ZSAteQp5dW0gaW5zdGFsbCAteSBodHRwZApzeXN0ZW1jdGwgc3RhcnQgaHR0cGQKc3lzdGVtY3RsIGVuYWJsZSBodHRwZApzZXRlbmZvcmNlIDAgMjkxCmVjaG8gIjxodG1sPjxib2R5PjxoMT5IZWxsbyBmcm9tIFhZWiBDb3JwIFNlcnZlciE8L2gxPjxwPlNlcnZlcjogJChob3N0bmFtZSk8L3A+PC9ib2R5PjwvaHRtbD4iID4gL3Zhci93d3cvaHRtbC9pbmRleC5odG1s",
    "IamInstanceProfile": {
      "Name": "XYZ-Corp-EC2-Profile"
    },
    "Monitoring": {
      "Enabled": true
    },
    "BlockDeviceMappings": [
      {
        "DeviceName": "/dev/xvda",
        "Ebs": {
          "VolumeSize": 20,
          "VolumeType": "gp3",
          "DeleteOnTermination": true,
          "Encrypted": true
        }
      }
    ],
    "TagSpecification": [
      {
        "ResourceType": "instance",
        "Tags": [
          {
            "Key": "Name",
            "Value": "XYZ-Corp-WebServer"
          },
          {
            "Key": "Project",
            "Value": "Auto-Scaling-Solution"
          },
          {
            "Key": "Environment",
            "Value": "Production"
          }
        ]
      }
    ]
  }
}
```

---

## 2. Auto Scaling Group Configuration
**File: `configurations/autoscaling-group.json`**

```json
{
  "AutoScalingGroupName": "XYZ-Corp-ASG",
  "LaunchTemplate": {
    "LaunchTemplateName": "XYZ-Corp-WebServer-Template",
    "Version": "$Latest"
  },
  "MinSize": 2,
  "MaxSize": 10,
  "DesiredCapacity": 2,
  "DefaultCooldown": 300,
  "AvailabilityZones": [
    "us-east-1a",
    "us-east-1b"
  ],
  "VPCZoneIdentifier": [
    "subnet-private1a123456",
    "subnet-private1b789012"
  ],
  "TargetGroupARNs": [
    "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/XYZ-Corp-TG/1234567890123456"
  ],
  "HealthCheckType": "ELB",
  "HealthCheckGracePeriod": 300,
  "Tags": [
    {
      "Key": "Name",
      "Value": "XYZ-Corp-ASG",
      "PropagateAtLaunch": false,
      "ResourceId": "XYZ-Corp-ASG",
      "ResourceType": "auto-scaling-group"
    },
    {
      "Key": "Project",
      "Value": "Auto-Scaling-Solution",
      "PropagateAtLaunch": true,
      "ResourceId": "XYZ-Corp-ASG",
      "ResourceType": "auto-scaling-group"
    }
  ]
}
```

---

## 3. Application Load Balancer Configuration
**File: `configurations/load-balancer.json`**

```json
{
  "Name": "XYZ-Corp-ALB",
  "Scheme": "internet-facing",
  "Type": "application",
  "IpAddressType": "ipv4",
  "Subnets": [
    "subnet-public1a123456",
    "subnet-public1b789012"
  ],
  "SecurityGroups": [
    "sg-alb123456"
  ],
  "Tags": [
    {
      "Key": "Name",
      "Value": "XYZ-Corp-ALB"
    },
    {
      "Key": "Project",
      "Value": "Auto-Scaling-Solution"
    }
  ],
  "TargetGroup": {
    "Name": "XYZ-Corp-TG",
    "Protocol": "HTTP",
    "Port": 80,
    "VpcId": "vpc-12345678",
    "HealthCheckProtocol": "HTTP",
    "HealthCheckPath": "/",
    "HealthCheckIntervalSeconds": 30,
    "HealthCheckTimeoutSeconds": 5,
    "HealthyThresholdCount": 2,
    "UnhealthyThresholdCount": 3,
    "Matcher": {
      "HttpCode": "200"
    }
  },
  "Listener": {
    "Protocol": "HTTP",
    "Port": 80,
    "DefaultActions": [
      {
        "Type": "forward",
        "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/XYZ-Corp-TG/1234567890123456"
      }
    ]
  }
}
```

---

## 4. Security Groups Configuration
**File: `configurations/security-groups.json`**

```json
{
  "SecurityGroups": [
    {
      "GroupName": "XYZ-Corp-ALB-SG",
      "Description": "Security group for XYZ Corp Application Load Balancer",
      "VpcId": "vpc-12345678",
      "SecurityGroupRules": [
        {
          "IpPermissions": [
            {
              "IpProtocol": "tcp",
              "FromPort": 80,
              "ToPort": 80,
              "IpRanges": [
                {
                  "CidrIp": "0.0.0.0/0",
                  "Description": "HTTP access from internet"
                }
              ]
            },
            {
              "IpProtocol": "tcp",
              "FromPort": 443,
              "ToPort": 443,
              "IpRanges": [
                {
                  "CidrIp": "0.0.0.0/0",
                  "Description": "HTTPS access from internet"
                }
              ]
            }
          ]
        }
      ],
      "Tags": [
        {
          "Key": "Name",
          "Value": "XYZ-Corp-ALB-SG"
        }
      ]
    },
    {
      "GroupName": "XYZ-Corp-WebServer-SG",
      "Description": "Security group for XYZ Corp Web Servers",
      "VpcId": "vpc-12345678",
      "SecurityGroupRules": [
        {
          "IpPermissions": [
            {
              "IpProtocol": "tcp",
              "FromPort": 80,
              "ToPort": 80,
              "UserIdGroupPairs": [
                {
                  "GroupId": "sg-alb123456",
                  "Description": "HTTP from ALB"
                }
              ]
            },
            {
              "IpProtocol": "tcp",
              "FromPort": 22,
              "ToPort": 22,
              "IpRanges": [
                {
                  "CidrIp": "203.0.113.0/24",
                  "Description": "SSH access from office"
                }
              ]
            }
          ]
        }
      ],
      "Tags": [
        {
          "Key": "Name",
          "Value": "XYZ-Corp-WebServer-SG"
        }
      ]
    }
  ]
}
```

---

## 5. Route 53 DNS Records
**File: `configurations/route53-records.json`**

```json
{
  "HostedZone": {
    "Name": "xyzcorp.com",
    "CallerReference": "xyz-corp-zone-2024-001"
  },
  "ResourceRecordSets": [
    {
      "Name": "xyzcorp.com",
      "Type": "A",
      "AliasTarget": {
        "DNSName": "xyz-corp-alb-123456789.us-east-1.elb.amazonaws.com",
        "EvaluateTargetHealth": true,
        "HostedZoneId": "Z35SXDOTRQ7X7K"
      }
    },
    {
      "Name": "www.xyzcorp.com",
      "Type": "A",
      "AliasTarget": {
        "DNSName": "xyz-corp-alb-123456789.us-east-1.elb.amazonaws.com",
        "EvaluateTargetHealth": true,
        "HostedZoneId": "Z35SXDOTRQ7X7K"
      }
    }
  ]
}
```

---

## 6. CloudWatch Alarms Configuration
**File: `configurations/cloudwatch-alarms.json`**

```json
{
  "CloudWatchAlarms": [
    {
      "AlarmName": "XYZ-Corp-CPU-High",
      "AlarmDescription": "Triggers when CPU utilization is above 80%",
      "ActionsEnabled": true,
      "AlarmActions": [
        "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:12345678-1234-1234-1234-123456789012:autoScalingGroupName/XYZ-Corp-ASG:policyName/XYZ-Corp-ScaleOut"
      ],
      "MetricName": "CPUUtilization",
      "Namespace": "AWS/EC2",
      "Statistic": "Average",
      "Dimensions": [
        {
          "Name": "AutoScalingGroupName",
          "Value": "XYZ-Corp-ASG"
        }
      ],
      "Period": 300,
      "EvaluationPeriods": 2,
      "Threshold": 80,
      "ComparisonOperator": "GreaterThanThreshold",
      "TreatMissingData": "notBreaching"
    },
    {
      "AlarmName": "XYZ-Corp-CPU-Low",
      "AlarmDescription": "Triggers when CPU utilization is below 60%",
      "ActionsEnabled": true,
      "AlarmActions": [
        "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:87654321-4321-4321-4321-210987654321:autoScalingGroupName/XYZ-Corp-ASG:policyName/XYZ-Corp-ScaleIn"
      ],
      "MetricName": "CPUUtilization",
      "Namespace": "AWS/EC2",
      "Statistic": "Average",
      "Dimensions": [
        {
          "Name": "AutoScalingGroupName",
          "Value": "XYZ-Corp-ASG"
        }
      ],
      "Period": 300,
      "EvaluationPeriods": 2,
      "Threshold": 60,
      "ComparisonOperator": "LessThanThreshold",
      "TreatMissingData": "notBreaching"
    }
  ]
}
```

---

## 7. Web Server Setup Script
**File: `scripts/user-data/webserver-setup.sh`**

```bash
#!/bin/bash

# XYZ Corporation Web Server Setup Script
# Auto-Scaling Solution - EC2 User Data
# Author: Himanshu Nitin Nehete

# Update system packages
yum update -y

# Install Apache HTTP Server
yum install -y httpd

# Install additional utilities
yum install -y htop stress awscli

# Start Apache and enable on boot
systemctl start httpd
systemctl enable httpd

# Disable SELinux for demo purposes
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Create simple web page with server information
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>XYZ Corporation - Auto Scaling Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; padding: 20px; background: rgba(255,255,255,0.1); border-radius: 10px; }
        .server-info { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 5px; margin: 20px 0; }
        .status { color: #00ff00; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 XYZ Corporation Auto-Scaling Solution</h1>
        <div class="server-info">
            <h2>Server Information</h2>
            <p><strong>Server Hostname:</strong> <span class="status">HOSTNAME_PLACEHOLDER</span></p>
            <p><strong>Instance ID:</strong> <span class="status">INSTANCE_ID_PLACEHOLDER</span></p>
            <p><strong>Availability Zone:</strong> <span class="status">AZ_PLACEHOLDER</span></p>
            <p><strong>Server Status:</strong> <span class="status">ONLINE</span></p>
        </div>
        <h2>📊 Project Details</h2>
        <ul>
            <li>Auto-Scaling Group: XYZ-Corp-ASG</li>
            <li>Load Balancer: Application Load Balancer</li>
            <li>Monitoring: CloudWatch Integration</li>
            <li>Cost Savings: 97% vs Traditional Infrastructure</li>
        </ul>
        <h2>🎓 Educational Context</h2>
        <p>Executive Post Graduate Certification in Cloud Computing<br>
           iHUB IIT Roorkee - Auto-Scaling Module</p>
    </div>
</body>
</html>
EOF

# Get instance metadata and update the web page
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
HOSTNAME=$(hostname)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Replace placeholders with actual values
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /var/www/html/index.html
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html

# Create a health check endpoint
echo "OK" > /var/www/html/health.html

# Install and configure CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "XYZ-Corp/WebServers",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60,
                "totalcpu": false
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Configure log rotation for Apache
cat > /etc/logrotate.d/httpd-custom << 'EOF'
/var/log/httpd/*log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        systemctl reload httpd
    endscript
}
EOF

# Create startup log
echo "$(date): XYZ Corp Web Server setup completed successfully" >> /var/log/user-data.log
echo "Instance ID: $INSTANCE_ID" >> /var/log/user-data.log
echo "Availability Zone: $AZ" >> /var/log/user-data.log

# Set appropriate permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Restart Apache to apply all changes
systemctl restart httpd

echo "XYZ Corporation Auto-Scaling Web Server setup completed successfully!"
```

---

## Quick Deployment Commands

### Using AWS CLI:
```bash
# Create Launch Template
aws ec2 create-launch-template --cli-input-json file://configurations/launch-template.json

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group --cli-input-json file://configurations/autoscaling-group.json

# Create Application Load Balancer
aws elbv2 create-load-balancer --cli-input-json file://configurations/load-balancer.json
```

### File Sizes:
- **Total files**: 7
- **Configuration files**: 6 JSON files (~15KB total)
- **Script file**: 1 shell script (~8KB)
- **Complete package**: ~23KB
