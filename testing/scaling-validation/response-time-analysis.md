# Response Time Consistency During Scaling Events

## Objective

This report analyzes the application's response time to ensure a consistent user experience was maintained while the Auto Scaling Group (ASG) added or removed instances.

## Analysis of Scale-Out Event

- **Pre-Scaling (11:02 AM):** With 2 instances, as load increased, the average response time climbed from 80ms to 250ms. The P95 latency briefly touched 480ms.
- **Scaling Triggered (11:05 AM):** The high-CPU alarm was triggered. The ASG began launching two new instances. During this ~2 minute provisioning period, latency remained elevated.
- **Post-Scaling (11:08 AM):** Once the new instances were in service and accepting traffic from the ALB, the load was distributed across 4 instances. The average response time quickly dropped back to ~90ms, and P95 latency stabilized around 210ms.

## Analysis of Scale-In Event

- **Pre-Scaling (12:10 PM):** As load decreased, CPU utilization on the 4 instances dropped to ~45%. Response times were stable and low (~60ms).
- **Scaling Triggered (12:15 PM):** The low-CPU alarm triggered the scale-in event. One instance was selected for termination.
- **Post-Scaling (12:18 PM):** After the instance was terminated and de-registered from the ALB, the remaining instances handled the traffic without any noticeable impact on response time, which remained stable.

## Conclusion

The auto-scaling mechanism performed as expected. While there was a brief period of increased latency leading up to the scale-out event, the system successfully self-healed and restored optimal performance once new capacity was added. The scale-in process was seamless and had no negative impact on user experience.
