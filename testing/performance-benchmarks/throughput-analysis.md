# System Throughput Analysis (Requests Per Second)

## Objective

To measure the maximum sustained throughput (Requests Per Second - RPS) of the application at different instance counts within the Auto Scaling Group.

## Summary of Results

| Number of Instances | Sustained RPS (Average) | Peak RPS | Notes |
| :---: | :---: | :---: | :--- |
| 2 (Baseline) | 250 | 280 | System is stable, CPU at ~55%. |
| 4 | 510 | 550 | Shows good linear scaling. |
| 6 | 750 | 820 | Scaling is still effective but shows slight diminishing returns. |
| 6 (Stress) | ~950 | 1100 | Throughput achieved just before error rates became unacceptable. |

## Analysis

- **Linear Scalability:** The architecture demonstrates strong, near-linear scalability when increasing the instance count from 2 to 6 under normal load conditions. Doubling the instances from 2 to 4 approximately doubled the throughput.
- **Bottleneck Identification:** The diminishing returns observed when scaling from 4 to 6 instances (and confirmed during the stress test) suggest that another component, potentially the database read/write capacity or network I/O, may become the next bottleneck under extreme load.
- **Maximum Throughput:** The infrastructure can reliably handle a sustained throughput of **750 RPS** while maintaining low latency and error rates. The absolute peak throughput before failure is approximately **950 RPS**.

## Conclusion

The auto-scaling configuration is highly effective at increasing system throughput to match demand. For future growth beyond ~800 RPS, further analysis of downstream dependencies will be necessary.
