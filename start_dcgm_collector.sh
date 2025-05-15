#!/usr/bin/env bash

# Check if the Prometheus HTTP SD service address is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <prometheus_http_sd_address>"
    echo "Example: $0 http://localhost:8000"
    exit 1
fi

PROMETHEUS_HTTP_SD=$1

# Variables
DCGM_IMAGE="nvcr.io/nvidia/k8s/dcgm-exporter:2.1.4-2.3.1-ubuntu20.04"

# Register with Prometheus HTTP SD
echo "Registering DCGM exporter with Prometheus HTTP SD at $PROMETHEUS_HTTP_SD"
curl -X POST $PROMETHEUS_HTTP_SD/targets \
  -H "Authorization: Bearer $(cat ${PWD}/prometheus_http_sd.token)" \
  -H "Content-Type: application/json" \
  -d '{
    "targets": [
      {
        "targets": ["'$HOSTNAME':9400"],
        "labels": {
          "__meta_datacenter": "perlmutter",
          "__meta_prometheus_job": "dcgm_exporter",
          "instance": "'$HOSTNAME'"
        }
      }
    ]
  }'


# Deploy DCGM (see localhost:9400/metrics)
podman-hpc run \
    --rm --gpu --net host \
    --user root \
    -v ${PWD}/dcgm_metrics.csv:/etc/dcgm-exporter/dcgm_metrics.csv \
    ${DCGM_IMAGE} \
        -f /etc/dcgm-exporter/dcgm_metrics.csv -c 15000