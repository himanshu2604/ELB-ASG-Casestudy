# AWS ELB-ASG Case Study Troubleshooting Guide

## 🚨 Common Issues & Quick Solutions

This guide provides solutions to the most frequent issues encountered during the AWS Auto-Scaling Infrastructure implementation for XYZ Corporation.

---

### 🔧 Auto Scaling Issues

#### Problem: Auto Scaling Group Not Scaling
**Symptoms:**
- Instances not launching despite high CPU
- Scale-in not working when CPU drops

**Quick Checks:**
```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "XYZ-Corp-ASG"

# Verify scaling policies
aws autoscaling describe-policies --auto-scaling-group-name "XYZ-Corp-ASG"

# Check CloudWatch alarms
aws cloudwatch describe-alarms --alarm-names "XYZ-CPU-High" "XYZ-CPU-Low"
```

**Solutions:**
1. **Alarm State Issues**: Ensure CloudWatch alarms are in "OK" state before testing
2. **Cooldown Period**: Default 300s cooldown may prevent rapid scaling
3. **IAM Permissions**: ASG needs CloudWatch and EC2 permissions
4. **Launch Template**: Verify launch template exists and is valid

---

### 🎯 Load Balancer Health Check Failures

#### Problem: Instances Failing Health Checks
**Symptoms:**
- Targets show "unhealthy" in console
- Traffic not reaching instances
- 503 Service Unavailable errors

**Diagnostic Commands:**
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn [TARGET_GROUP_ARN]

# Verify security groups
aws ec2 describe-security-groups --group-names "XYZ-WebServer-SG"

# Test connectivity
curl -I http://[INSTANCE_IP]
```

**Solutions:**
1. **Security Groups**: Ensure port 80/443 open from ALB subnets (not 0.0.0.0/0)
2. **Web Server Status**: Check if httpd/nginx is running on instances
3. **Health Check Path**: Verify health check path "/" exists and responds
4. **Instance Initialization**: Allow 5-10 minutes for user data script completion

---

### 🌐 DNS and Route 53 Issues

#### Problem: Domain Not Resolving to Load Balancer
**Symptoms:**
- Domain returns DNS errors
- Website not accessible via domain name
- DNS propagation delays

**Verification Steps:**
```bash
# Check DNS records
nslookup xyzcorp.com
dig xyzcorp.com

# Verify Route 53 configuration
aws route53 list-resource-record-sets --hosted-zone-id [ZONE_ID]

# Test ALB directly
curl -I http://[ALB_DNS_NAME]
```

**Solutions:**
1. **DNS Propagation**: Wait 24-48 hours for global propagation
2. **A Record Configuration**: Ensure A record points to ALB (use alias)
3. **Hosted Zone**: Verify NS records match domain registrar settings
4. **SSL Certificate**: If using HTTPS, ensure certificate is valid

---

### 📊 CloudWatch Monitoring Problems

#### Problem: Missing Metrics or Alarms Not Triggering
**Symptoms:**
- No CPU metrics visible
- Alarms stuck in "Insufficient Data"
- Scaling not triggered despite load

**Troubleshooting:**
```bash
# Check metric availability
aws cloudwatch get-metric-statistics --namespace "AWS/EC2" --metric-name "CPUUtilization" --dimensions Name=AutoScalingGroupName,Value=XYZ-Corp-ASG --start-time 2023-01-01T00:00:00Z --end-time 2023-01-01T23:59:59Z --period 300 --statistics Average

# Verify IAM role permissions
aws sts get-caller-identity
```

**Solutions:**
1. **CloudWatch Agent**: Ensure agent is installed and configured
2. **IAM Role**: Instance profile needs CloudWatch permissions
3. **Metric Filters**: Check if custom metrics are properly configured
4. **Time Synchronization**: Ensure instance time is synchronized

---

### 🔐 Security Group Configuration

#### Problem: Connection Timeouts or Access Denied
**Symptoms:**
- SSH access denied
- Web traffic blocked
- Internal communication failures

**Security Group Rules Required:**
```
Web Server Security Group (XYZ-WebServer-SG):
- HTTP (80): Source = ALB Security Group
- HTTPS (443): Source = ALB Security Group  
- SSH (22): Source = Your IP or Bastion Host
- All Outbound: 0.0.0.0/0 (for updates)

ALB Security Group:
- HTTP (80): Source = 0.0.0.0/0
- HTTPS (443): Source = 0.0.0.0/0
```

---

### 🚀 Instance Launch Failures

#### Problem: EC2 Instances Not Starting
**Symptoms:**
- ASG shows "launching" but instances fail
- Launch template errors
- User data script failures

**Investigation Steps:**
```bash
# Check ASG activities
aws autoscaling describe-scaling-activities --auto-scaling-group-name "XYZ-Corp-ASG"

# Verify launch template
aws ec2 describe-launch-templates --launch-template-names "XYZ-Corp-LaunchTemplate"

# Check instance logs (if accessible)
sudo cat /var/log/cloud-init-output.log
```

**Common Fixes:**
1. **AMI Issues**: Ensure AMI exists in correct region
2. **Instance Type**: Verify t3.medium available in target AZ
3. **Subnet Capacity**: Check if subnets have available IP addresses
4. **User Data**: Debug script syntax and permissions

---

### 💰 Cost Optimization Issues

#### Problem: Unexpected High Costs
**Symptoms:**
- Higher than expected AWS bills
- Instances not scaling down
- Data transfer charges

**Cost Analysis:**
```bash
# Check current instance count
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "XYZ-Corp-ASG" --query 'AutoScalingGroups[0].{Min:MinSize,Max:MaxSize,Desired:DesiredCapacity,Current:Instances[?LifecycleState==`InService`] | length(@)}'

# Review scaling history
aws autoscaling describe-scaling-activities --auto-scaling-group-name "XYZ-Corp-ASG" --max-items 10
```

**Optimization Actions:**
1. **Aggressive Scale-In**: Lower scale-in threshold from 60% to 50%
2. **Shorter Evaluation Periods**: Reduce evaluation period for faster scale-down
3. **Scheduled Scaling**: Implement predictive scaling for known patterns
4. **Right-Sizing**: Monitor actual usage and adjust instance types

---

### 🔍 Performance Issues

#### Problem: Slow Response Times or High Latency
**Symptoms:**
- Response times > 200ms
- Users reporting slow performance
- High CPU despite scaling

**Performance Diagnostics:**
```bash
# Load test command
ab -n 1000 -c 50 http://xyzcorp.com/

# Check ALB metrics
aws cloudwatch get-metric-statistics --namespace "AWS/ApplicationELB" --metric-name "TargetResponseTime"
```

**Performance Improvements:**
1. **Application Optimization**: Profile and optimize web application code
2. **Caching**: Implement CloudFront CDN for static content
3. **Database**: Optimize database queries and consider RDS
4. **Instance Types**: Consider compute-optimized instances for CPU-intensive workloads

---

### 📋 Quick Diagnostic Checklist

**Before Troubleshooting:**
- [ ] Check AWS Service Health Dashboard
- [ ] Verify all resources in same region (us-east-1)
- [ ] Confirm IAM permissions for all services
- [ ] Check AWS CLI configuration and credentials

**During Issues:**
- [ ] Check CloudWatch Logs and Metrics
- [ ] Review ASG Activities tab in console
- [ ] Verify security group rules
- [ ] Test components individually (ALB → Target Group → Instances)

**Emergency Contacts:**
- AWS Support (if applicable)
- Internal DevOps team
- Escalation procedures documented

---

### 🛠️ Useful Commands Reference

```bash
# Quick status check
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "XYZ-Corp-ASG" --query 'AutoScalingGroups[0].{Status:Instances[].{InstanceId:InstanceId,State:LifecycleState,Health:HealthStatus}}'

# Force scaling activity (testing only)
aws autoscaling set-desired-capacity --auto-scaling-group-name "XYZ-Corp-ASG" --desired-capacity 4 --honor-cooldown

# Manual health check
curl -v -H "Host: xyzcorp.com" http://[ALB_DNS_NAME]/

# CloudWatch alarm test
aws cloudwatch set-alarm-state --alarm-name "XYZ-CPU-High" --state-value ALARM --state-reason "Manual test"
```

---

## 📞 Getting Additional Help

1. **AWS Documentation**: [Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/)
2. **Community Support**: AWS re:Post forums
3. **Professional Support**: AWS Support Center (if business/enterprise support)
4. **Project Repository**: Check GitHub issues and documentation

**Remember**: Always test changes in development environment before applying to production!
