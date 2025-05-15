#!/usr/bin/env bash

#############################################################################
# Prometheus and Grafana Deployment Script
# 
# This script deploys Prometheus and Grafana containers for metrics collection
# and visualization in a NERSC JupyterHub environment.
#############################################################################

# Function to check if ports are in use
# Arguments: None (uses global ports and port_names_arr arrays)
# Returns: 0 if all ports are available, 1 if any port is in use
check_ports() {
  local unavailable_ports=()
  local port_names=()
  
  for i in "${!ports[@]}"; do
    if ss -tuln | grep -q ":${ports[$i]} "; then
      unavailable_ports+=(${ports[$i]})
      port_names+=(${port_names_arr[$i]})
    fi
  done
  
  if [ ${#unavailable_ports[@]} -gt 0 ]; then
    echo "Error: The following ports are already in use:"
    for i in "${!unavailable_ports[@]}"; do
      echo "  - ${port_names[$i]} (${unavailable_ports[$i]})"
    done
    return 1
  fi
  
  echo "All required ports are available."
  return 0
}

# Function to handle cleanup on signal
# Terminates all background processes and removes temporary files
cleanup() {
  echo "Shutting down services (PIDs: $PROM_SD_PID $PROM_PID $GF_PID)"
  kill $PROM_SD_PID $PROM_PID $GF_PID 2>/dev/null || true
  wait $PROM_SD_PID $PROM_PID $GF_PID 2>/dev/null || true
  
  # Clean up temporary files
  echo "Cleaning up temporary files..."
  rm -f prometheus.yml prometheus_http_sd.token
  
  echo "All services terminated"
  exit 0
}

# Set trap to catch signals
trap cleanup SIGINT SIGTERM EXIT

#############################################################################
# Configuration Variables
#############################################################################

# Container images
readonly PROM_IMAGE="prom/prometheus:v3.3.0"
readonly GF_IMAGE="grafana/grafana-oss:11.6.0"

# Network ports
readonly PROM_PORT="9090"      # Prometheus web interface
readonly GF_PORT="3000"        # Grafana web interface
readonly HTTP_SD_PORT="8080"   # Service discovery API

# Security
readonly HTTP_SD_API_KEY=$(uuidgen)  # Generate unique API key

# Paths
readonly PYTHONUSERBASE_DIR="$SCRATCH/nersc_metrics_install/python-3.11"
readonly PROM_DATA_DIR="$SCRATCH/prometheus_metrics_data"
readonly GF_DATA_DIR="$SCRATCH/grafana_metrics_data"

# JupyterHub configuration
if [ -z "${JUPYTERHUB_SERVICE_PREFIX}" ]; then
  JUPYTERHUB_SERVICE_PREFIX="/user/$(whoami)/perlmutter-login-node-base/"
  echo "JUPYTERHUB_SERVICE_PREFIX not defined, using default: ${JUPYTERHUB_SERVICE_PREFIX}"
fi

#############################################################################
# Pre-deployment Checks
#############################################################################

# Check if required ports are available
echo "Checking if required ports are available..."
ports=($PROM_PORT $GF_PORT $HTTP_SD_PORT)
port_names_arr=("Prometheus" "Grafana" "HTTP Service Discovery")
check_ports || exit 1

# Create required directories
mkdir -p "$PROM_DATA_DIR" "$GF_DATA_DIR"

#############################################################################
# Service Deployment
#############################################################################

# 1. Start Prometheus HTTP service discovery
echo "Starting Prometheus HTTP service discovery..."
PYTHONUSERBASE=$PYTHONUSERBASE_DIR ./prometheus_http_sd.py --api-key "${HTTP_SD_API_KEY}" --port "${HTTP_SD_PORT}" &
PROM_SD_PID=$!
echo "Service discovery running with PID: $PROM_SD_PID"

# 2. Create prometheus config files
echo "Configuring Prometheus..."
sed "s|<HTTP_SD_URL>|http://localhost:${HTTP_SD_PORT}/targets|g" prometheus_template.yml > prometheus.yml
echo "$HTTP_SD_API_KEY" > prometheus_http_sd.token
chmod 600 prometheus_http_sd.token  # Restrict permissions on token file

# 3. Deploy Prometheus
echo "Starting Prometheus..."
podman-hpc run \
    --user root \
    --rm --net host \
    --env HTTP_SD_API_KEY="${HTTP_SD_API_KEY}" \
    -v "${PWD}/prometheus.yml:/prometheus.yml" \
    -v "${PWD}/prometheus_http_sd.token:/prometheus_http_sd.token" \
    -v "${PROM_DATA_DIR}:/prometheus" \
    "$PROM_IMAGE" --config.file=/prometheus.yml --web.listen-address=:"${PROM_PORT}" &
PROM_PID=$!
echo "Prometheus running with PID: $PROM_PID"

# 4. Deploy Grafana
echo "Starting Grafana..."
podman-hpc run \
    --user root \
    --rm --net host \
    --env "GF_SERVER_ROOT_URL=https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/${GF_PORT}" \
    --env "GF_SERVER_HTTP_PORT=${GF_PORT}" \
    -v "$GF_DATA_DIR:/var/lib/grafana" \
    "$GF_IMAGE" &
GF_PID=$!
echo "Grafana running with PID: $GF_PID"

#############################################################################
# Service Verification and Information
#############################################################################

# Wait for services to be ready
echo "Waiting for services to start..."

# Check if services are up by polling their ports
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  all_up=true
  
  # Check Prometheus
  if ! curl -s "http://localhost:${PROM_PORT}/-/healthy" &>/dev/null; then
    all_up=false
  fi
  
  # Check Grafana
  if ! curl -s "http://localhost:${GF_PORT}/api/health" &>/dev/null; then
    all_up=false
  fi
  
  if $all_up; then
    break
  fi
  
  attempt=$((attempt+1))
  sleep 1
done

if [ $attempt -eq $max_attempts ]; then
  echo "Warning: Timeout waiting for services to start. They may not be fully operational."
fi

# Print access information
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Services are ready!"
echo
echo "📊 Prometheus: https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/${PROM_PORT}/query"
echo "📈 Grafana:    https://jupyter.nersc.gov${JUPYTERHUB_SERVICE_PREFIX}proxy/${GF_PORT}/login"
echo "🔍 Service Discovery: http://${HOSTNAME}:${HTTP_SD_PORT}"
echo
echo "Press Ctrl+C to stop all services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Wait for all background processes
wait