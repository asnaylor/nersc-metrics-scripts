#!/usr/bin/env bash

# Check if the Prometheus HTTP SD service address is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <prometheus_http_sd_address>"
    echo "Example: $0 http://localhost:8000"
    exit 1
fi

PROMETHEUS_HTTP_SD=$1

# Variables
NODE_EXPORTER_VERSION="1.9.1"
NODE_EXPORTER_DIR="${SCRATCH}/nersc_metrics_install/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/"


# Register with Prometheus HTTP SD
echo "Registering Node exporter with Prometheus HTTP SD at $PROMETHEUS_HTTP_SD"
curl -X POST $PROMETHEUS_HTTP_SD/targets \
  -H "Authorization: Bearer $(cat prometheus_http_sd.token)" \
  -H "Content-Type: application/json" \
  -d '{
    "targets": [
      {
        "targets": ["'$HOSTNAME':9100"],
        "labels": {
          "__meta_datacenter": "perlmutter",
          "__meta_prometheus_job": "node_exporter",
          "instance": "'$HOSTNAME'"
        }
      }
    ]
  }'


# Deploy Node Exporter (see localhost:9100/metrics)
${NODE_EXPORTER_DIR}/node_exporter \
    --collector.disable-defaults \
    --collector.cpu \
    --collector.meminfo \
    --collector.netdev \
    --collector.infiniband \
    --collector.netstat
