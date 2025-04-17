#!/usr/bin/env bash

# Function to handle cleanup on signal
cleanup() {
  echo "Caught signal, killing background function with PID $PROM_PID $GF_PID_PID"
  kill $PROM_PID $GF_PID_PID
  wait $PROM_PID 2>/dev/null
  echo "Background function terminated"
  exit 0
}

# Set trap to catch signals (SIGINT and SIGTERM in this example)
trap cleanup SIGINT SIGTERM


#Variables
PROM_IMAGE="prom/prometheus:v3.3.0"
GF_IMAGE="grafana/grafana-oss:11.6.0"

#Deploy Prometheus (see localhost:9090)
mkdir -p $SCRATCH/prometheus_metrics_data
podman-hpc run \
    --user root \
    --rm --net host \
    -v /global/homes/a/asnaylor/projects/metrics_collector/prometheus_cfg:/etc/prometheus \
    -v ${SCRATCH}/prometheus_metrics_data:/prometheus \
        $PROM_IMAGE &

PROM_PID=$!
echo "$PROM_PID"
echo "Visit Prometheus at https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/9090/"

#Deploy Grafana (see localhost:3000)
mkdir -p $SCRATCH/grafana_metrics_data
podman-hpc run \
    --user root \
    --rm --net host \
    --env "GF_SERVER_ROOT_URL=https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/3000" \
    -v $SCRATCH/grafana_metrics_data:/var/lib/grafana \
        grafana/grafana-oss:11.6.0 &
GF_PID_PID=$!
echo "$GF_PID_PID"
echo "Visit Grafana at https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/3000/login"
wait
