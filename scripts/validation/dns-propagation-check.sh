#!/bin/bash

# Route 53 DNS Propagation Validation Script
# XYZ Corporation Auto-Scaling Solution
# Version: 1.2.0

set -e

# Configuration
DOMAIN="xyzcorp.com"
EXPECTED_RECORD_TYPE="A"
REGION="us-east-1"
HOSTED_ZONE_NAME="xyzcorp.com"

# Global DNS servers to test against
DNS_SERVERS=(
    "8.8.8.8"          # Google Public DNS
    "8.8.4.4"          # Google Public DNS Secondary
    "1.1.1.1"          # Cloudflare DNS
    "1.0.0.1"          # Cloudflare DNS Secondary
    "208.67.222.222"   # OpenDNS
    "208.67.220.220"   # OpenDNS Secondary
    "4.2.2.1"          # Level3 DNS
    "4.2.2.2"          # Level3 DNS Secondary
)

# International DNS servers for global propagation check
GLOBAL_DNS_SERVERS=(
    "8.8.8.8,Global-Google"
    "1.1.1.1,Global-Cloudflare"
    "9.9.9.9,Quad9-Global"
    "76.76.76.76,ControlD-Global"
    "94.140.14.14,AdGuard-Global"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Get expected ALB DNS name from AWS
get_expected_alb_dns() {
    print_status "INFO" "Discovering expected ALB DNS name..."
    
    local alb_dns
    alb_dns=$(aws elbv2 describe-load-balancers \
        --region $REGION \
        --names "XYZ-Corp-LoadBalancer" \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null || echo "None")
    
    if [[ "$alb_dns" == "None" || "$alb_dns" == "null" ]]; then
        print_status "ERROR" "Could not find ALB DNS name"
        print_status "INFO" "Available load balancers:"
        aws elbv2 describe-load-balancers \
            --region $REGION \
            --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' \
            --output table
        exit 1
    fi
    
    print_status "SUCCESS" "Expected ALB DNS: $alb_dns"
    echo "$alb_dns"
}

# Check Route 53 hosted zone configuration
check_hosted_zone() {
    print_status "INFO" "Checking Route 53 hosted zone configuration..."
    
    local zone_id
    zone_id=$(aws route53 list-hosted-zones \
        --query "HostedZones[?Name=='${HOSTED_ZONE_NAME}.'].Id" \
        --output text | cut -d'/' -f3)
    
    if [[ -z "$zone_id" || "$zone_id" == "None" ]]; then
        print_status "ERROR" "Hosted zone for $HOSTED_ZONE_NAME not found"
        return 1
    fi
    
    print_status "SUCCESS" "Found hosted zone: $zone_id"
    
    # Get DNS records for the domain
    print_status "INFO" "Fetching DNS records..."
    
    local records
    records=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query "ResourceRecordSets[?Name=='${DOMAIN}.' || Name=='www.${DOMAIN}.']" \
        --output json)
    
    echo "$records" | jq '.'
    
    # Check if A record exists
    local a_record_exists
    a_record_exists=$(echo "$records" | jq -r ".[] | select(.Type==\"A\" and .Name==\"${DOMAIN}.\") | .Name" || echo "")
    
    if [[ -n "$a_record_exists" ]]; then
        print_status "SUCCESS" "A record exists for $DOMAIN"
        
        # Check if it's an alias record pointing to ALB
        local is_alias
        is_alias=$(echo "$records" | jq -r ".[] | select(.Type==\"A\" and .Name==\"${DOMAIN}.\") | .AliasTarget.DNSName // \"\"")
        
        if [[ -n "$is_alias" ]]; then
            print_status "SUCCESS" "A record is properly configured as ALB alias: $is_alias"
            echo "$is_alias"
        else
            print_status "WARNING" "A record exists but may not be configured as ALB alias"
            return 1
        fi
    else
        print_status "ERROR" "No A record found for $DOMAIN"
        return 1
    fi
}

# Test DNS resolution against multiple servers
test_dns_resolution() {
    local test_domain=$1
    local expected_value=$2
    
    print_status "INFO" "Testing DNS resolution for $test_domain"
    echo "Expected value: $expected_value"
    echo ""
    
    local success_count=0
    local total_tests=${#DNS_SERVERS[@]}
    
    for dns_server in "${DNS_SERVERS[@]}"; do
        print_status "INFO" "Testing against DNS server: $dns_server"
        
        local resolved_value
        resolved_value=$(dig +short @"$dns_server" "$test_domain" A 2>/dev/null | head -1 || echo "FAILED")
        
        if [[ "$resolved_value" == "FAILED" || -z "$resolved_value" ]]; then
            print_status "ERROR" "Failed to resolve $test_domain via $dns_server"
        elif [[ "$resolved_value" == "$expected_value" ]]; then
            print_status "SUCCESS" "$dns_server: $resolved_value ✓"
            ((success_count++))
        else
            print_status "WARNING" "$dns_server: $resolved_value (expected: $expected_value)"
        fi
    done
    
    local success_rate=$((success_count * 100 / total_tests))
    
    if [[ $success_rate -ge 80 ]]; then
        print_status "SUCCESS" "DNS propagation: $success_count/$total_tests servers ($success_rate%) ✓"
        return 0
    elif [[ $success_rate -ge 50 ]]; then
        print_status "WARNING" "Partial DNS propagation: $success_count/$total_tests servers ($success_rate%)"
        return 1
    else
        print_status "ERROR" "Poor DNS propagation: $success_count/$total_tests servers ($success_rate%)"
        return 2
    fi
}

# Test global DNS propagation
test_global_propagation() {
    local test_domain=$1
    
    print_status "INFO" "Testing global DNS propagation for $test_domain"
    echo ""
    
    local global_results=()
    
    for server_info in "${GLOBAL_DNS_SERVERS[@]}"; do
        IFS=',' read -r dns_server server_name <<< "$server_info"
        
        print_status "INFO" "Testing global DNS server: $server_name ($dns_server)"
        
        local resolved_value
        resolved_value=$(timeout 10 dig +short @"$dns_server" "$test_domain" A 2>/dev/null | head -1 || echo "TIMEOUT")
        
        local response_time
        response_time=$(timeout 10 dig +stats @"$dns_server" "$test_domain" A 2>/dev/null | grep "Query time:" | awk '{print $4}' || echo "999")
        
        if [[ "$resolved_value" == "TIMEOUT" || -z "$resolved_value" ]]; then
            print_status "ERROR" "$server_name: Query timeout or failed"
            global_results+=("$server_name:FAILED")
        else
            print_status "SUCCESS" "$server_name: $resolved_value (${response_time}ms)"
            global_results+=("$server_name:SUCCESS:$resolved_value:${response_time}ms")
        fi
    done
    
    # Analyze global results
    local success_count=0
    for result in "${global_results[@]}"; do
        if [[ "$result" =~ :SUCCESS: ]]; then
            ((success_count++))
        fi
    done
    
    local global_success_rate=$((success_count * 100 / ${#GLOBAL_DNS_SERVERS[@]}))
    
    if [[ $global_success_rate -ge 80 ]]; then
        print_status "SUCCESS" "Global propagation: $success_count/${#GLOBAL_DNS_SERVERS[@]} servers ($global_success_rate%) ✓"
        return 0
    else
        print_status "WARNING" "Global propagation incomplete: $success_count/${#GLOBAL_DNS_SERVERS[@]} servers ($global_success_rate%)"
        return 1
    fi
}

# Test DNS response time performance
test_dns_performance() {
    local test_domain=$1
    
    print_status "INFO" "Testing DNS performance for $test_domain"
    echo ""
    
    local response_times=()
    
    for dns_server in "${DNS_SERVERS[@]:0:4}"; do  # Test top 4 servers for performance
        local total_time=0
        local successful_queries=0
        
        for i in {1..5}; do  # 5 queries per server
            local query_time
            query_time=$(dig +stats @"$dns_server" "$test_domain" A 2>/dev/null | grep "Query time:" | awk '{print $4}' || echo "999")
            
            if [[ "$query_time" != "999" && "$query_time" -lt 1000 ]]; then
                total_time=$((total_time + query_time))
                ((successful_queries++))
            fi
        done
        
        if [[ $successful_queries -gt 0 ]]; then
            local avg_time=$((total_time / successful_queries))
            response_times+=("$dns_server:$avg_time")
            
            if [[ $avg_time -lt 50 ]]; then
                print_status "SUCCESS" "$dns_server: ${avg_time}ms average (excellent)"
            elif [[ $avg_time -lt 100 ]]; then
                print_status "SUCCESS" "$dns_server: ${avg_time}ms average (good)"
            elif [[ $avg_time -lt 200 ]]; then
                print_status "WARNING" "$dns_server: ${avg_time}ms average (acceptable)"
            else
                print_status "ERROR" "$dns_server: ${avg_time}ms average (slow)"
            fi
        else
            print_status "ERROR" "$dns_server: All queries failed"
        fi
    done
}

# Test HTTP response through domain
test_http_response() {
    local test_domain=$1
    
    print_status "INFO" "Testing HTTP response through domain: $test_domain"
    
    local max_attempts=5
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))
        print_status "INFO" "HTTP test attempt $attempt/$max_attempts"
        
        local http_response
        local response_time
        
        http_response=$(timeout 15 curl -s -o /dev/null -w "%{http_code}" "http://$test_domain/" 2>/dev/null || echo "000")
        response_time=$(timeout 15 curl -s -o /dev/null -w "%{time_total}" "http://$test_domain/" 2>/dev/null || echo "999")
        
        if [[ "$http_response" == "200" ]]; then
            print_status "SUCCESS" "HTTP response: $http_response (${response_time}s response time)"
            
            # Test HTTPS as well if available
            local https_response
            https_response=$(timeout 15 curl -s -o /dev/null -w "%{http_code}" "https://$test_domain/" 2>/dev/null || echo "000")
            
            if [[ "$https_response" == "200" ]]; then
                print_status "SUCCESS" "HTTPS response: $https_response"
            else
                print_status "WARNING" "HTTPS not available or not responding correctly ($https_response)"
            fi
            
            return 0
        else
            print_status "WARNING" "HTTP response: $http_response (attempt $attempt)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                print_status "INFO" "Waiting 30 seconds before retry..."
                sleep 30
            fi
        fi
    done
    
    print_status "ERROR" "HTTP test failed after $max_attempts attempts"
    return 1
}

# Generate DNS validation report
generate_dns_report() {
    local domain=$1
    local alb_dns=$2
    
    local report_file="dns-validation-report-$(date +%Y%m%d-%H%M%S).json"
    
    print_status "INFO" "Generating DNS validation report..."
    
    # Collect comprehensive DNS data
    local dns_data="{}"
    
    # Add Route 53 configuration
    local zone_id
    zone_id=$(aws route53 list-hosted-zones \
        --query "HostedZones[?Name=='${HOSTED_ZONE_NAME}.'].Id" \
        --output text | cut -d'/' -f3)
    
    if [[ -n "$zone_id" && "$zone_id" != "None" ]]; then
        local route53_records
        route53_records=$(aws route53 list-resource-record-sets \
            --hosted-zone-id "$zone_id" \
            --output json)
        
        dns_data=$(echo "$dns_data" | jq ". + {\"route53_zone_id\": \"$zone_id\", \"route53_records\": $route53_records}")