---
title: "Demo 07 — Right-Sizing & Cost Impact Analysis"
demo_number: "07"
session: bonus
runtime: "Python 3 (stdlib)"
time: "~3 min"
demo_dir: "quarkus-demo-07-rightsizing"
run_command: "./demo.sh"
cluster_required: false
prev_url: "/demos/demo-06-latency/"
prev_title: "Demo 06 — Low Latency"
next_url: "/demos/demo-08-panama/"
next_title: "Demo 08 — Panama"
---

Pure Python analysis — no containers, no cluster needed. 14 days of bundled Prometheus sample data from a 7-service cluster produces right-sizing recommendations and a quantified cost business case.

## Run options

```bash
./demo.sh                                      # bundled sample data
./demo.sh --live                               # try kubectl first
python3 analyze.py --cost-per-node-hour 0.768  # custom node cost
```

## Sample results

| Service | CPU before → after | Memory before → after |
|---------|-------------------|-----------------------|
| payment-service (SB) | 2000m → 560m (−72%) | 4096 → 2304Mi (−44%) |
| fraud-detection (QK) | 1500m → 280m (−81%) | 2048 → 880Mi (−57%) |
| report-generator (SB) | 4000m → 3640m (−9%) | 8192 → 7744Mi (−5%) |

> The `report-generator` is the honest exception — batch workload with real CPU and memory near limit. Not everything gets cut.

## Business case output

```
4 nodes → 2 nodes  ·  +67% pod density  ·  $6,720/month saving  ·  17× ROI
```

## OpenShift Cost Management

```
Console → Cost Management → Optimizations
API: GET /api/cost-management/v1/recommendations/openshift/
```

## Reference

- [Demo source]({{ site.repo }}/tree/main/java-optimization-demos/quarkus-demo-07-rightsizing)
- [OpenShift Cost Management](https://docs.redhat.com/en/documentation/cost_management_service)
