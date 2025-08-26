# Stress Test Analysis Report

**Date:** 2025-08-26

## 1. Objective

The purpose of this stress test was to identify the breaking point of the 6-instance auto-scaled infrastructure and observe its behavior under extreme load, far exceeding the expected peak.

## 2. Methodology

- **Tool Used:** Apache JMeter
- **Test Plan:** A gradual ramp-up of concurrent users from 500 to 2000 over a 20-minute period.
- **Success Criteria:** Maintain an error rate below 2% and a 95th percentile response time under 500ms.

## 3. Observations

- **0-800 Users:** The system performed nominally. The 6 instances handled the load with an average CPU utilization of ~75% and response times well within acceptable limits.
- **800-1200 Users:** Response times began to increase steadily, with the p95 latency crossing the 300ms mark. CPU utilization was consistently above 85% across all instances.
- **1200-1500 Users:** The error rate began to climb, exceeding 1%. The ALB started reporting some `HTTP 503 Service Unavailable` errors, indicating the backend instances were completely saturated.
- **1500+ Users:** At approximately 1550 concurrent users, the error rate spiked dramatically to over 5%, and p95 response times exceeded 1000ms. The system was unable to recover until the load was reduced.

## 4. Breaking Point Identification

The effective capacity limit of the current 6-instance configuration is approximately **1,200 concurrent users**. Beyond this point, performance degrades rapidly, and system stability is compromised.

## 5. Conclusion

The architecture successfully handled significant load and scaled as expected. The stress test demonstrates that while the system is robust, further optimizations (e.g., using larger instance types, database tuning, or application code refactoring) would be required to handle traffic beyond 1,200 concurrent users.
