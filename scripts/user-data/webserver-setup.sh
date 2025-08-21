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