#!/usr/bin/env bash

# Function to handle cleanup on signal
cleanup() {
  echo "Caught signal, killing background function with PID $DCGM_PID $NODE_EXPORTER_PID"
  kill $DCGM_PID $NODE_EXPORTER_PID
  wait $DCGM_PID 2>/dev/null
  echo "Background function terminated"
  exit 0
}

# Set trap to catch signals (SIGINT and SIGTERM in this example)
trap cleanup SIGINT SIGTERM


#Variables
DCGM_IMAGE="nvcr.io/nvidia/k8s/dcgm-exporter:2.1.4-2.3.1-ubuntu20.04"
NODE_EXPORTER_DIR="${SCRATCH}/ldms/node_exporter-1.9.1.linux-amd64/"

#Deploy DCGM (see localhost:9400/metrics)
podman-hpc run \
    --rm --gpu --net host \
    --user root \
    -v $PWD/dcgm_metrics.csv:/etc/dcgm-exporter/dcgm_metrics.csv \
    ${DCGM_IMAGE} \
        -f /etc/dcgm-exporter/dcgm_metrics.csv -c 15000 &

DCGM_PID=$!
echo "$DCGM_PID"

#Deploy Node Exporter (see localhost:9100/metrics)
${NODE_EXPORTER_DIR}/node_exporter \
    --collector.disable-defaults \
    --collector.cpu \
    --collector.meminfo \
    --collector.netdev \
    --collector.infiniband \
    --collector.netstat &
NODE_EXPORTER_PID=$!
echo "$NODE_EXPORTER_PID"

wait


