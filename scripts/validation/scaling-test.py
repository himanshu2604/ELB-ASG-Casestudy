#!/usr/bin/env python3

"""
Auto-Scaling Behavior Testing Script
XYZ Corporation Auto-Scaling Solution
Version: 1.2.0

This script generates load to test auto-scaling policies and validates
scaling behavior under different load conditions.
"""

import boto3
import requests
import threading
import time
import json
import logging
import argparse
import statistics
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import concurrent.futures

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class AutoScalingTester:
    """Tests auto-scaling behavior by generating load and monitoring responses"""
    
    def __init__(self, region='us-east-1', asg_name='XYZ-Corp-AutoScaling-Group', alb_dns=None):
        self.region = region
        self.asg_name = asg_name
        self.alb_dns = alb_dns
        
        # AWS clients
        self.autoscaling = boto3.client('autoscaling', region_name=region)
        self.cloudwatch = boto3.client('cloudwatch', region_name=region)
        self.elbv2 = boto3.client('elbv2', region_name=region)
        
        # Test configuration
        self.test_results = []
        self.load_test_active = False
        
        # Discover ALB DNS if not provided
        if not self.alb_dns:
            self.alb_dns = self._discover_alb_dns()
    
    def _discover_alb_dns(self) -> str:
        """Discover ALB DNS name automatically"""
        try:
            response = self.elbv2.describe_load_balancers(Names=['XYZ-Corp-LoadBalancer'])
            return response['LoadBalancers'][0]['DNSName']
        except Exception as e:
            logger.error(f"Could not discover ALB DNS: {str(e)}")
            return None
    
    def get_current_capacity(self) -> Dict:
        """Get current Auto Scaling Group capacity"""
        try:
            response = self.autoscaling.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.asg_name]
            )
            
            if not response['AutoScalingGroups']:
                logger.error(f"Auto Scaling Group {self.asg_name} not found")
                return {}
            
            asg = response['AutoScalingGroups'][0]
            return {
                'desired': asg['DesiredCapacity'],
                'min': asg['MinSize'],
                'max': asg['MaxSize'],
                'current': len(asg['Instances']),
                'healthy': len([i for i in asg['Instances'] if i['HealthStatus'] == 'Healthy'])
            }
        except Exception as e:
            logger.error(f"Error getting ASG capacity: {str(e)}")
            return {}
    
    def get_scaling_activities(self, max_records=10) -> List[Dict]:
        """Get recent scaling activities"""
        try:
            response = self.autoscaling.describe_scaling_activities(
                AutoScalingGroupName=self.asg_name,
                MaxRecords=max_records
            )
            return response['Activities']
        except Exception as e:
            logger.error(f"Error getting scaling activities: {str(e)}")
            return []
    
    def get_cpu_utilization(self, minutes=10) -> float:
        """Get average CPU utilization for the ASG"""
        try:
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(minutes=minutes)
            
            response = self.cloudwatch.get_metric_statistics(
                Namespace='AWS/AutoScaling',
                MetricName='CPUUtilization',
                Dimensions=[
                    {
                        'Name': 'AutoScalingGroupName',
                        'Value': self.asg_name
                    }
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,  # 5 minutes
                Statistics=['Average']
            )
            
            if response['Datapoints']:
                return statistics.mean([dp['Average'] for dp in response['Datapoints']])
            return 0.0
            
        except Exception as e:
            logger.error(f"Error getting CPU utilization: {str(e)}")
            return 0.0
    
    def load_test_worker(self, duration: int, requests_per_second: int) -> Dict:
        """Worker function for load testing"""
        if not self.alb_dns:
            logger.error("ALB DNS not available for load testing")
            return {'success': 0, 'failed': 0, 'response_times': []}
        
        url = f"http://{self.alb_dns}/"
        interval = 1.0 / requests_per_second if requests_per_second > 0 else 1.0
        
        success_count = 0
        failed_count = 0
        response_times = []
        
        end_time = time.time() + duration
        
        while time.time() < end_time and self.load_test_active:
            try:
                start_time = time.time()
                response = requests.get(url, timeout=10)
                response_time = time.time() - start_time
                
                if response.status_code == 200:
                    success_count += 1
                    response_times.append(response_time)
                else:
                    failed_count += 1
                    
            except Exception as e:
                failed_count += 1
                logger.debug(f"Request failed: {str(e)}")
            
            # Control request rate
            time.sleep(max(0, interval - (time.time() - start_time)))
        
        return {
            'success': success_count,
            'failed': failed_count,
            'response_times': response_times
        }
    
    def generate_load(self, duration: int, concurrent_users: int, requests_per_second: int = 1) -> Dict:
        """Generate load using multiple threads"""
        logger.info(f"Starting load test: {concurrent_users} users, {requests_per_second} RPS each, {duration}s duration")
        
        self.load_test_active = True
        
        # Start load testing threads
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrent_users) as executor:
            futures = []
            
            for _ in range(concurrent_users):
                future = executor.submit(self.load_test_worker, duration, requests_per_second)
                futures.append(future)
            
            # Wait for all threads to complete
            results = []
            for future in concurrent.futures.as_completed(futures):
                try:
                    result = future.result()
                    results.append(result)
                except Exception as e:
                    logger.error(f"Load test worker failed: {str(e)}")
        
        self.load_test_active = False
        
        # Aggregate results
        total_success = sum(r['success'] for r in results)
        total_failed = sum(r['failed'] for r in results)
        all_response_times = []
        for r in results:
            all_response_times.extend(r['response_times'])
        
        avg_response_time = statistics.mean(all_response_times) if all_response_times else 0
        p95_response_time = statistics.quantiles(all_response_times, n=20)[18] if len(all_response_times) > 20 else 0
        
        return {
            'total_requests': total_success + total_failed,
            'successful_requests': total_success,
            'failed_requests': total_failed,
            'success_rate': (total_success / (total_success + total_failed) * 100) if (total_success + total_failed) > 0 else 0,
            'average_response_time': avg_response_time,
            'p95_response_time': p95_response_time,
            'requests_per_second': (total_success + total_failed) / duration if duration > 0 else 0
        }
    
    def monitor_scaling_event(self, timeout: int = 600) -> Dict:
        """Monitor for scaling events during test"""
        logger.info(f"Monitoring scaling events for {timeout} seconds...")
        
        initial_capacity = self.get_current_capacity()
        initial_activities = len(self.get_scaling_activities())
        
        start_time = time.time()
        scaling_detected = False
        final_capacity = initial_capacity
        
        while time.time() - start_time < timeout:
            current_capacity = self.get_current_capacity()
            current_activities = self.get_scaling_activities()
            
            # Check if capacity changed
            if current_capacity.get('desired', 0) != initial_capacity.get('desired', 0):
                if not scaling_detected:
                    scaling_detected = True
                    logger.info(f"Scaling detected! Capacity changed from {initial_capacity.get('desired')} to {current_capacity.get('desired')}")
                
                final_capacity = current_capacity
            
            # Check for new scaling activities
            if len(current_activities) > initial_activities:
                for activity in current_activities[:len(current_activities) - initial_activities]:
                    logger.info(f"Scaling activity: {activity['Description']} - {activity['StatusCode']}")
            
            time.sleep(30)  # Check every 30 seconds
        
        return {
            'scaling_detected': scaling_detected,
            'initial_capacity': initial_capacity,
            'final_capacity': final_capacity,
            'capacity_change': final_capacity.get('desired', 0) - initial_capacity.get('desired', 0),
            'monitoring_duration': timeout
        }
    
    def run_scale_up_test(self, duration: int = 300) -> Dict:
        """Run test to trigger scale-up event"""
        logger.info("🚀 Starting Scale-Up Test")
        logger.info("=" * 50)
        
        # Get baseline metrics
        initial_capacity = self.get_current_capacity()
        initial_cpu = self.get_cpu_utilization(5)
        
        logger.info(f"Initial state:")
        logger.info(f"  Capacity: {initial_capacity}")
        logger.info(f"  CPU Utilization: {initial_cpu:.2f}%")
        
        # Start monitoring in background
        monitoring_future = None
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            monitoring_future = executor.submit(self.monitor_scaling_event, duration + 300)
            
            # Generate high load to trigger scale-up
            logger.info("Generating high load to trigger scale-up...")
            load_results = self.generate_load(
                duration=duration,
                concurrent_users=20,  # High concurrent load
                requests_per_second=5  # 5 requests per second per user = 100 total RPS
            )
            
            # Wait for monitoring to complete
            monitoring_results = monitoring_future.result()
        
        # Get final metrics
        final_capacity = self.get_current_capacity()
        final_cpu = self.get_cpu_utilization(5)
        recent_activities = self.get_scaling_activities(5)
        
        test_results = {
            'test_type': 'scale_up',
            'timestamp': datetime.utcnow().isoformat(),
            'duration': duration,
            'initial_state': {
                'capacity': initial_capacity,
                'cpu_utilization': initial_cpu
            },
            'final_state': {
                'capacity': final_capacity,
                'cpu_utilization': final_cpu
            },
            'load_test_results': load_results,
            'monitoring_results': monitoring_results,
            'scaling_activities': recent_activities,
            'success': monitoring_results['scaling_detected'] and monitoring_results['capacity_change'] > 0
        }
        
        return test_results
    
    def run_scale_down_test(self, wait_duration: int = 600) -> Dict:
        """Run test to trigger scale-down event"""
        logger.info("📉 Starting Scale-Down Test")
        logger.info("=" * 50)
        
        # Get baseline metrics
        initial_capacity = self.get_current_capacity()
        initial_cpu = self.get_cpu_utilization(5)
        
        logger.info(f"Initial state:")
        logger.info(f"  Capacity: {initial_capacity}")
        logger.info(f"  CPU Utilization: {initial_cpu:.2f}%")
        
        # Stop all load and wait for scale-down
        logger.info(f"Waiting {wait_duration} seconds for scale-down to occur...")
        
        monitoring_results = self.monitor_scaling_event(wait_duration)
        
        # Get final metrics
        final_capacity = self.get_current_capacity()
        final_cpu = self.get_cpu_utilization(5)
        recent_activities = self.get_scaling_activities(5)
        
        test_results = {
            'test_type': 'scale_down',
            'timestamp': datetime.utcnow().isoformat(),
            'wait_duration': wait_duration,
            'initial_state': {
                'capacity': initial_capacity,
                'cpu_utilization': initial_cpu
            },
            'final_state': {
                'capacity': final_capacity,
                'cpu_utilization': final_cpu
            },
            'monitoring_results': monitoring_results,
            'scaling_activities': recent_activities,
            'success': monitoring_results['scaling_detected'] and monitoring_results['capacity_change'] < 0
        }
        
        return test_results
    
    def run_stress_test(self, duration: int = 600) -> Dict:
        """Run comprehensive stress test"""
        logger.info("💪 Starting Comprehensive Stress Test")
        logger.info("=" * 50)
        
        # Get baseline
        initial_capacity = self.get_current_capacity()
        
        # Start monitoring
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            monitoring_future = executor.submit(self.monitor_scaling_event, duration + 300)
            
            # Phase 1: Light load
            logger.info("Phase 1: Light load (100 RPS)")
            light_load_results = self.generate_load(
                duration=duration // 3,
                concurrent_users=10,
                requests_per_second=10
            )
            
            # Phase 2: Medium load
            logger.info("Phase 2: Medium load (200 RPS)")
            medium_load_results = self.generate_load(
                duration=duration // 3,
                concurrent_users=20,
                requests_per_second=10
            )
            
            # Phase 3: Heavy load
            logger.info("Phase 3: Heavy load (500 RPS)")
            heavy_load_results = self.generate_load(
                duration=duration // 3,
                concurrent_users=50,
                requests_per_second=10
            )
            
            monitoring_results = monitoring_future.result()
        
        # Get final state
        final_capacity = self.get_current_capacity()
        recent_activities = self.get_scaling_activities(10)
        
        test_results = {
            'test_type': 'stress_test',
            'timestamp': datetime.utcnow().isoformat(),
            'duration': duration,
            'initial_capacity': initial_capacity,
            'final_capacity': final_capacity,
            'load_phases': {
                'light_load': light_load_results,
                'medium_load': medium_load_results,
                'heavy_load': heavy_load_results
            },
            'monitoring_results': monitoring_results,
            'scaling_activities': recent_activities,
            'max_capacity_reached': max(activity.get('DesiredCapacity', 0) for activity in recent_activities if 'DesiredCapacity' in activity)
        }
        
        return test_results
    
    def generate_test_report(self, test_results: List[Dict], filename: str = None) -> str:
        """Generate comprehensive test report"""
        if not filename:
            filename = f"scaling-test-report-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        
        report = {
            'report_metadata': {
                'generated_at': datetime.utcnow().isoformat(),
                'region': self.region,
                'asg_name': self.asg_name,
                'alb_dns': self.alb_dns,
                'total_tests': len(test_results)
            },
            'test_results': test_results,
            'summary': self._generate_summary(test_results)
        }
        
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        logger.info(f"Test report generated: {filename}")
        return filename
    
    def _generate_summary(self, test_results: List[Dict]) -> Dict:
        """Generate test summary"""
        successful_tests = sum(1 for result in test_results if result.get('success', False))
        
        summary = {
            'total_tests': len(test_results),
            'successful_tests': successful_tests,
            'failed_tests': len(test_results) - successful_tests,
            'success_rate': (successful_tests / len(test_results) * 100) if test_results else 0
        }
        
        # Add specific test type summaries
        for test_type in ['scale_up', 'scale_down', 'stress_test']:
            type_results = [r for r in test_results if r.get('test_type') == test_type]
            if type_results:
                summary[f'{test_type}_results'] = {
                    'count': len(type_results),
                    'success_rate': sum(1 for r in type_results if r.get('success', False)) / len(type_results) * 100
                }
        
        return summary

def main():
    """Main execution function"""
    parser = argparse.ArgumentParser(
        description='Test Auto-Scaling behavior and performance'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--asg-name',
        default='XYZ-Corp-AutoScaling-Group',
        help='Auto Scaling Group name'
    )
    parser.add_argument(
        '--alb-dns',
        help='ALB DNS name (will auto-discover if not provided)'
    )
    parser.add_argument(
        '--test-type',
        choices=['scale-up', 'scale-down', 'stress', 'all'],
        default='all',
        help='Type of test to run (default: all)'
    )
    parser.add_argument(
        '--duration',
        type=int,
        default=300,
        help='Test duration in seconds (default: 300)'
    )
    parser.add_argument(
        '--report-file',
        help='Output report filename'
    )
    
    args = parser.parse_args()
    
    # Initialize tester
    tester = AutoScalingTester(
        region=args.region,
        asg_name=args.asg_name,
        alb_dns=args.alb_dns
    )
    
    # Check if ALB is available
    if not tester.alb_dns:
        logger.error("ALB DNS not available. Load testing will be limited.")
    
    # Run tests
    test_results = []
    
    try:
        if args.test_type in ['scale-up', 'all']:
            logger.info("Running scale-up test...")
            result = tester.run_scale_up_test(args.duration)
            test_results.append(result)
            
            if result['success']:
                logger.info("✅ Scale-up test PASSED")
            else:
                logger.warning("❌ Scale-up test FAILED")
        
        if args.test_type in ['scale-down', 'all']:
            logger.info("Running scale-down test...")
            result = tester.run_scale_down_test(args.duration * 2)  # Longer wait for scale-down
            test_results.append(result)
            
            if result['success']:
                logger.info("✅ Scale-down test PASSED")
            else:
                logger.warning("❌ Scale-down test FAILED")
        
        if args.test_type in ['stress', 'all']:
            logger.info("Running stress test...")
            result = tester.run_stress_test(args.duration * 2)  # Longer duration for stress test
            test_results.append(result)
            logger.info("✅ Stress test completed")
        
    except KeyboardInterrupt:
        logger.info("Test interrupted by user")
        tester.load_test_active = False
    except Exception as e:
        logger.error(f"Test failed with error: {str(e)}")
        return 1
    
    # Generate report
    if test_results:
        report_file = tester.generate_test_report(test_results, args.report_file)
        
        logger.info("\n" + "=" * 50)
        logger.info("🎉 SCALING TEST COMPLETED")
        logger.info("=" * 50)
        logger.info(f"Report saved to: {report_file}")
        
        # Print summary
        summary = tester._generate_summary(test_results)
        logger.info(f"Overall Success Rate: {summary['success_rate']:.1f}%")
        logger.info(f"Successful Tests: {summary['successful_tests']}/{summary['total_tests']}")
    else:
        logger.warning("No test results to report")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())