#!/usr/bin/env bash

# Check if the Prometheus HTTP SD service address is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <prometheus_http_sd_address>"
    echo "Example: $0 http://localhost:8000"
    exit 1
fi

PROMETHEUS_HTTP_SD=$1

# Register with Prometheus HTTP SD
echo "Registering envoy with Prometheus HTTP SD at $PROMETHEUS_HTTP_SD"
curl -X POST $PROMETHEUS_HTTP_SD/targets \
  -H "Authorization: Bearer $(cat ${PWD}/prometheus_http_sd.token)" \
  -H "Content-Type: application/json" \
  -d '{
    "targets": [
      {
        "targets": ["'$HOSTNAME':9901"],
        "labels": {
          "__meta_datacenter": "perlmutter",
          "__meta_prometheus_job": "envoy",
	  "__metrics_path__": "/stats/prometheus",
          "instance": "'$HOSTNAME'"
        }
      }
    ]
  }'
