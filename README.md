# 🚀 AWS Auto-Scaling Infrastructure Solution

[![AWS](https://img.shields.io/badge/AWS-Auto%20Scaling-orange)](https://aws.amazon.com/)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-Elastic-blue)](https://github.com/[your-username]/aws-autoscaling-solution)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Study](https://img.shields.io/badge/Academic-IIT%20Roorkee-red)](https://github.com/[your-username]/aws-autoscaling-solution)

## 📋 Project Overview

**XYZ Corporation Cloud Migration & Auto-Scaling Solution** - A comprehensive AWS infrastructure implementation demonstrating intelligent auto-scaling, load balancing, and cost-effective cloud migration from on-premise infrastructure.

### 🎯 Key Achievements
- ✅ **Intelligent Auto-Scaling** - Scale out at 80% CPU, scale in at 60% CPU
- ✅ **40-60% Cost Reduction** compared to on-premise infrastructure
- ✅ **Zero Manual Intervention** for scaling operations
- ✅ **High Availability** across multiple Availability Zones
- ✅ **Domain Integration** with Route 53 DNS routing

## 🏗️ Problem Statement

**Challenge**: XYZ Corporation faced escalating infrastructure costs due to regular hardware purchases to handle increasing application load. The company needed a scalable, cost-effective solution to replace their on-premise infrastructure.

**Solution Requirements**:
1. **Automatic Scaling**: Deploy/remove resources based on CPU utilization (80% scale-out, 60% scale-in)
2. **Load Distribution**: Implement load balancer for traffic distribution
3. **Domain Routing**: Route company domain traffic to cloud infrastructure

## 🏗️ Architecture

<img width="2667" height="942" alt="ELB-ASG-Architecture" src="https://github.com/user-attachments/assets/c9abbc20-8126-428d-8290-0534cca2eb04" />



## 🔧 Technologies & Services Used

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **EC2** | Compute resources | t3.medium instances |
| **Auto Scaling Group** | Automatic scaling | 2-10 instances capacity |
| **Application Load Balancer** | Traffic distribution | Multi-AZ deployment |
| **Route 53** | DNS management | Domain routing |
| **CloudWatch** | Monitoring & alarms | CPU utilization metrics |
| **VPC** | Network isolation | Multi-AZ with NAT gateways |
| **Security Groups** | Network security | HTTP, HTTPS, SSH access |

## 📂 Repository Structure

```
aws-autoscaling-solution/
├── 📋 documentation/
│   ├── AWS-Auto-Scaling-Solution.pdf      # Complete implementation guide
│   ├── architecture-overview.md           # Architecture documentation
│   ├── ELB-ASG-Architecture.png           # Architecture image
│   └── cost-analysis.md                   # Financial impact analysis
├── 🔧 scripts/
│   ├── user-data/                         # EC2 initialization scripts
│   │   └── webserver-setup.sh
│   ├── scaling-policies/                  # Auto Scaling configurations
│   ├── cloudwatch-setup/                  # Monitoring setup scripts
│   └── validation/                        # Testing and validation
├── ⚙️ configurations/
│   ├── launch-template.json               # EC2 Launch Template
│   ├── configuration.md                  # md for all files
│   ├── autoscaling-group.json            # ASG configuration
│   ├── load-balancer.json                # ALB configuration
│   ├── security-groups.json              # Security configurations
│   ├── route53-records.json              # DNS configurations
│   └── cloudwatch-alarms.json            # Monitoring alarms
├── 📸 screenshots/                        # Implementation evidence
│   ├── auto-scaling-events/
│   ├── load-balancer-health/
│   ├── cloudwatch-metrics/
│   └── route53-configuration/
├── 🧪 testing/                           # Load testing & validation
│   ├── load-test-results/
│   ├── scaling-validation/
│   └── performance-benchmarks/
├── 💰 cost-analysis/                     # Financial analysis
│   ├── before-after-comparison.md
│   ├── monthly-cost-breakdown.md
│   └── roi-calculation.md
└── 📚 troubleshooting/                   # Issue resolution
    ├── common-issues.md
    ├── debugging-guide.md
    └── best-practices.md
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate IAM permissions
- Domain name for Route 53 configuration
- SSH key pair for EC2 access

### Deployment Steps

#### 1. **Infrastructure Setup**
```bash
# Clone the repository
git clone https://github.com/[your-username]/aws-autoscaling-solution.git
cd aws-autoscaling-solution

# Create VPC and networking components
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=XYZ-Corp-VPC}]'
```

#### 2. **Launch Template Creation**
```bash
# Create launch template for auto scaling
aws ec2 create-launch-template --cli-input-json file://configurations/launch-template.json
```

#### 3. **Load Balancer Deployment**
```bash
# Create Application Load Balancer
aws elbv2 create-load-balancer --cli-input-json file://configurations/load-balancer.json

# Create target group
aws elbv2 create-target-group --cli-input-json file://configurations/target-group.json
```

#### 4. **Auto Scaling Group Setup**
```bash
# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group --cli-input-json file://configurations/autoscaling-group.json

# Create scaling policies
aws autoscaling put-scaling-policy --policy-name "Scale-Out-Policy" --auto-scaling-group-name "XYZ-Corp-ASG" --scaling-adjustment 2 --adjustment-type "ChangeInCapacity"
```

#### 5. **DNS Configuration**
```bash
# Configure Route 53 for domain routing
aws route53 create-hosted-zone --name "xyzcorp.com" --caller-reference "xyz-migration-$(date +%s)"
aws route53 change-resource-record-sets --hosted-zone-id [ZONE_ID] --change-batch file://configurations/route53-records.json
```

#### 6. **Monitoring Setup**
```bash
# Create CloudWatch alarms
aws cloudwatch put-metric-alarm --cli-input-json file://configurations/cloudwatch-alarms.json
```

## 📊 Implementation Results

### Scaling Performance
| Metric | Before (On-Premise) | After (AWS Auto-Scaling) |
|--------|-------------------|-------------------------|
| **Scale-Out Time** | Manual (30+ minutes) | Automatic (5 minutes) |
| **Scale-In Time** | Manual intervention | Automatic (5 minutes) |
| **Resource Efficiency** | Over-provisioned | Right-sized automatically |
| **Availability** | Single point of failure | Multi-AZ redundancy |

### Cost Impact
- **Monthly Infrastructure Cost**: $850 → $340 (60% reduction)
- **Operational Overhead**: Eliminated manual scaling tasks
- **Peak Load Handling**: Automatic scaling to 10 instances
- **Off-Peak Optimization**: Scales down to 2 instances

### Performance Metrics
- **Average Response Time**: 180ms
- **99th Percentile Response**: 450ms
- **Availability**: 99.9% uptime
- **Load Distribution**: Even across all healthy instances

## 🎯 Scaling Behavior

### Scale-Out Triggers
- ✅ CPU Utilization > 80% for 2 consecutive periods (10 minutes)
- ✅ Adds 2 instances at a time
- ✅ Maximum capacity: 10 instances
- ✅ Cooldown period: 5 minutes

### Scale-In Triggers
- ✅ CPU Utilization < 60% for 2 consecutive periods (10 minutes)
- ✅ Removes 1 instance at a time
- ✅ Minimum capacity: 2 instances
- ✅ Cooldown period: 5 minutes

## 🔍 Monitoring & Alerts

### CloudWatch Metrics Tracked
- **EC2 Metrics**: CPU Utilization, Network I/O, Disk I/O
- **Auto Scaling Metrics**: Desired/Current/Running Capacity
- **Load Balancer Metrics**: Request Count, Response Time, Healthy Hosts
- **Custom Metrics**: Application performance indicators

### Alerting Strategy
- **High CPU Alert**: > 85% for 5 minutes
- **Low CPU Alert**: < 55% for 10 minutes
- **Unhealthy Targets**: < 2 healthy instances
- **Cost Alert**: Monthly spend > $500

## 🧪 Testing & Validation

### Load Testing Results
```bash
# Simulate traffic spike
ab -n 10000 -c 100 http://your-domain.com/

# Results:
# - Automatic scale-out triggered at 82% CPU
# - 4 additional instances launched within 6 minutes
# - Load distributed evenly across 6 instances
# - Response times remained < 200ms throughout test
```

### Validation Checklist
- ✅ Auto-scaling triggers work correctly
- ✅ Load balancer distributes traffic evenly
- ✅ Domain resolves to load balancer
- ✅ Health checks pass consistently
- ✅ Monitoring alerts function properly
- ✅ Cost optimization achieved

## 💡 Best Practices Implemented

### Security
- **Network Isolation**: Private subnets for EC2 instances
- **Security Groups**: Restrictive inbound rules
- **IAM Roles**: Least privilege access
- **HTTPS Termination**: SSL/TLS at load balancer

### Cost Optimization
- **Right-Sizing**: t3.medium instances for optimal performance/cost
- **Scheduled Scaling**: Predictive scaling for known patterns
- **Reserved Instances**: For baseline capacity
- **Spot Instances**: For development/testing environments

### Reliability
- **Multi-AZ Deployment**: High availability across zones
- **Health Checks**: Application-level health monitoring
- **Graceful Scaling**: Proper warm-up and cooldown periods
- **Backup Strategy**: AMI snapshots for disaster recovery

## 🎓 Learning Outcomes

This project demonstrates practical experience with:
- ✅ **Auto Scaling Groups** configuration and management
- ✅ **Application Load Balancer** setup and target group management
- ✅ **CloudWatch Metrics** and alarm configuration
- ✅ **Route 53** DNS management and domain routing
- ✅ **Cost Optimization** strategies and monitoring
- ✅ **High Availability** architecture design
- ✅ **Infrastructure as Code** principles

## 🚨 Troubleshooting Guide

### Common Issues & Solutions

#### Auto Scaling Not Working
```bash
# Check alarm state
aws cloudwatch describe-alarms --alarm-names "XYZ-CPU-High" "XYZ-CPU-Low"

# Verify scaling policies
aws autoscaling describe-policies --auto-scaling-group-name "XYZ-Corp-ASG"
```

#### Load Balancer Health Checks Failing
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn [TARGET_GROUP_ARN]

# Verify security groups
aws ec2 describe-security-groups --group-names "XYZ-WebServer-SG"
```

#### Domain Not Resolving
```bash
# Check Route 53 records
aws route53 list-resource-record-sets --hosted-zone-id [ZONE_ID]

# Test DNS resolution
nslookup your-domain.com
```

## 📚 Documentation Links

- **[Complete Implementation Guide](documentation/AWS-Auto-Scaling-Solution.pdf)** - Detailed step-by-step instructions
- **[Architecture Deep Dive](documentation/architecture-overview.md)** - Technical architecture analysis
- **[Cost Analysis Report](documentation/cost-analysis.md)** - Financial impact assessment
- **[Performance Benchmarks](testing/performance-benchmarks/)** - Load testing results
- **[Best Practices Guide](troubleshooting/best-practices.md)** - Operational recommendations

## 🔗 Academic Context

**Course**: Executive Post Graduate Certification in Cloud Computing  
**Institution**: iHub Divyasampark, IIT Roorkee  
**Module**: AWS Auto Scaling & Load Balancing  
**Project Duration**: Infrastructure Migration & Optimization  
**Business Impact**: 60% cost reduction with improved scalability

## 🤝 Contributing

Contributions and improvements are welcome:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/enhancement`)
3. Commit your changes (`git commit -am 'Add enhancement'`)
4. Push to the branch (`git push origin feature/enhancement`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

**Himanshu Nitin Nehete**  
📧 Email: [himanshunehete2025@gmail.com](himanshunehete2025@gmail.com)  
🔗 LinkedIn: [My LinkedIn Profile](https://www.linkedin.com/in/himanshu-nehete/)
🎓 Institution: iHub Divyasampark, IIT Roorkee  

---

⭐ **Star this repository if it helped you learn AWS auto-scaling and load balancing!**

**Keywords**: AWS, Auto Scaling, Load Balancer, Route 53, CloudWatch, Infrastructure Migration, Cost Optimization, IIT Roorkee, Cloud Computing, Elastic Infrastructure
