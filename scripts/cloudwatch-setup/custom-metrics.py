#!/usr/bin/env python3

"""
Custom CloudWatch Metrics Collection Script
XYZ Corporation Auto-Scaling Solution
Version: 1.2.0

This script collects custom application metrics and publishes them to CloudWatch
for enhanced monitoring and scaling decisions.
"""

import boto3
import requests
import psutil
import time
import json
import logging
from datetime import datetime
from typing import Dict, List
import argparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class CustomMetricsCollector:
    """Collects and publishes custom metrics to CloudWatch"""
    
    def __init__(self, region='us-east-1', namespace='XYZ/Application'):
        self.region = region
        self.namespace = namespace
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.instance_id = self._get_instance_id()
        
    def _get_instance_id(self) -> str:
        """Get the current EC2 instance ID"""
        try:
            response = requests.get(
                'http://169.254.169.254/latest/meta-data/instance-id',
                timeout=2
            )
            return response.text
        except:
            return 'unknown-instance'
    
    def collect_system_metrics(self) -> List[Dict]:
        """Collect system-level performance metrics"""
        metrics = []
        
        try:
            # Memory utilization
            memory = psutil.virtual_memory()
            metrics.append({
                'MetricName': 'MemoryUtilization',
                'Value': memory.percent,
                'Unit': 'Percent',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Disk utilization
            disk = psutil.disk_usage('/')
            disk_percent = (disk.used / disk.total) * 100
            metrics.append({
                'MetricName': 'DiskUtilization',
                'Value': disk_percent,
                'Unit': 'Percent',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Network connections
            connections = len(psutil.net_connections())
            metrics.append({
                'MetricName': 'NetworkConnections',
                'Value': connections,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Load average (1 minute)
            load_avg = psutil.getloadavg()[0] if hasattr(psutil, 'getloadavg') else 0
            metrics.append({
                'MetricName': 'LoadAverage1Min',
                'Value': load_avg,
                'Unit': 'None',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            logger.info(f"Collected {len(metrics)} system metrics")
            
        except Exception as e:
            logger.error(f"Error collecting system metrics: {str(e)}")
            
        return metrics
    
    def collect_application_metrics(self) -> List[Dict]:
        """Collect application-specific metrics"""
        metrics = []
        
        try:
            # Simulate application health check
            app_health = self._check_application_health()
            metrics.append({
                'MetricName': 'ApplicationHealth',
                'Value': 1 if app_health else 0,
                'Unit': 'None',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Simulate active user sessions
            active_sessions = self._get_active_sessions()
            metrics.append({
                'MetricName': 'ActiveSessions',
                'Value': active_sessions,
                'Unit': 'Count',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Simulate application response time
            response_time = self._measure_response_time()
            metrics.append({
                'MetricName': 'ApplicationResponseTime',
                'Value': response_time,
                'Unit': 'Seconds',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            # Simulate error rate
            error_rate = self._get_error_rate()
            metrics.append({
                'MetricName': 'ApplicationErrorRate',
                'Value': error_rate,
                'Unit': 'Percent',
                'Dimensions': [
                    {'Name': 'InstanceId', 'Value': self.instance_id}
                ]
            })
            
            logger.info(f"Collected {len(metrics)} application metrics")
            
        except Exception as e:
            logger.error(f"Error collecting application metrics: {str(e)}")
            
        return metrics
    
    def _check_application_health(self) -> bool:
        """Check if the web application is responding"""
        try:
            response = requests.get('http://localhost:80', timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def _get_active_sessions(self) -> int:
        """Simulate getting active user sessions count"""
        # In a real application, this would query your session store
        # For simulation, return a random-ish number based on time
        base_sessions = 20
        time_factor = int(time.time() % 100)
        return base_sessions + (time_factor % 30)
    
    def _measure_response_time(self) -> float:
        """Measure application response time"""
        try:
            start_time = time.time()
            response = requests.get('http://localhost:80', timeout=5)
            end_time = time.time()
            
            if response.status_code == 200:
                return end_time - start_time
            else:
                return 1.0  # High response time for errors
        except:
            return 2.0  # Very high response time for failures
    
    def _get_error_rate(self) -> float:
        """Calculate application error rate percentage"""
        # In a real application, this would analyze logs or application metrics
        # For simulation, return a low error rate with occasional spikes
        base_error_rate = 0.5
        time_spike = int(time.time() % 300)  # 5-minute cycle
        
        if time_spike < 30:  # Spike for 30 seconds every 5 minutes
            return base_error_rate + 2.0
        return base_error_rate
    
    def publish_metrics(self, metrics: List[Dict]) -> bool:
        """Publish metrics to CloudWatch"""
        if not metrics:
            logger.warning("No metrics to publish")
            return False
        
        try:
            # Add timestamp to all metrics
            current_time = datetime.utcnow()
            for metric in metrics:
                metric['Timestamp'] = current_time
            
            # Publish metrics in batches (CloudWatch limit is 20 per call)
            batch_size = 20
            for i in range(0, len(metrics), batch_size):
                batch = metrics[i:i + batch_size]
                
                response = self.cloudwatch.put_metric_data(
                    Namespace=self.namespace,
                    MetricData=batch
                )
                
                logger.info(f"Published batch of {len(batch)} metrics")
            
            logger.info(f"Successfully published {len(metrics)} total metrics")
            return True
            
        except Exception as e:
            logger.error(f"Error publishing metrics: {str(e)}")
            return False
    
    def collect_and_publish_all(self) -> bool:
        """Collect all metrics and publish to CloudWatch"""
        logger.info("Starting metrics collection...")
        
        all_metrics = []
        
        # Collect system metrics
        system_metrics = self.collect_system_metrics()
        all_metrics.extend(system_metrics)
        
        # Collect application metrics
        app_metrics = self.collect_application_metrics()
        all_metrics.extend(app_metrics)
        
        # Publish all metrics
        success = self.publish_metrics(all_metrics)
        
        logger.info(f"Metrics collection completed. Success: {success}")
        return success

def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description='Collect and publish custom metrics to CloudWatch'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--namespace',
        default='XYZ/Application',
        help='CloudWatch namespace (default: XYZ/Application)'
    )
    parser.add_argument(
        '--continuous',
        action='store_true',
        help='Run continuously with 5-minute intervals'
    )
    parser.add_argument(
        '--interval',
        type=int,
        default=300,
        help='Interval in seconds for continuous mode (default: 300)'
    )
    
    args = parser.parse_args()
    
    # Initialize metrics collector
    collector = CustomMetricsCollector(
        region=args.region,
        namespace=args.namespace
    )
    
    if args.continuous:
        logger.info(f"Starting continuous metrics collection (interval: {args.interval}s)")
        
        while True:
            try:
                collector.collect_and_publish_all()
                logger.info(f"Sleeping for {args.interval} seconds...")
                time.sleep(args.interval)
                
            except KeyboardInterrupt:
                logger.info("Received interrupt signal. Stopping...")
                break
            except Exception as e:
                logger.error(f"Unexpected error: {str(e)}")
                time.sleep(60)  # Wait 1 minute before retry
    else:
        # Single execution
        success = collector.collect_and_publish_all()
        exit(0 if success else 1)

if __name__ == "__main__":
    main()