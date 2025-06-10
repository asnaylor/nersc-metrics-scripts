# NERSC Metrics Scripts

A comprehensive solution for deploying Prometheus, Grafana, node_exporter, and DCGM for monitoring compute nodes and GPU metrics at NERSC.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Dashboards](#dashboards)
- [Troubleshooting](#troubleshooting)
- [Cleaning Up](#cleaning-up)
- [Advanced Configuration](#advanced-configuration)

## Overview

This toolkit provides a set of scripts to easily deploy a complete metrics collection and visualization stack on NERSC systems. It's designed to work within the NERSC JupyterHub environment and supports dynamic registration of monitoring targets through HTTP service discovery.

### Architecture Example

<div align="center">
  <img src="example_metrics_diagrams.svg" alt="Multi-node monitoring example with NERSC Metrics" width="800">
  <p><em>Figure 1: Example deployment showing how the NERSC Metrics scripts can be used to monitor multiple compute nodes, with each node running node_exporter and DCGM collectors that register with the central Prometheus instance</em></p>
</div>

## Features

- **Prometheus** for metrics collection and storage
- **Grafana** for metrics visualization and dashboarding
- **node_exporter** for system-level metrics (CPU, memory, network, etc.)
- **DCGM exporter** for NVIDIA GPU metrics
- **HTTP Service Discovery API** for dynamic target registration
- Works within NERSC JupyterHub environment

## Installation

1. Clone the repository to your local machine:

    ```bash
    git clone https://github.com/yourusername/nersc-metrics-scripts.git
    cd nersc-metrics-scripts
    ```

2. Install dependencies and download node_exporter:
   ```bash
   make all
   ```

   This will:
   - Create a Python user base directory in your SCRATCH space
   - Install required Python packages (FastAPI, uvicorn)
   - Download and extract node_exporter

## Usage

### 1. Start Prometheus and Grafana

Launch the core monitoring infrastructure within JupyterHub:

```bash
./start_grafana_prometheus.sh
```

This script:
- Starts the HTTP service discovery API
- Deploys Prometheus in a container
- Deploys Grafana in a container
- Configures all services to work within JupyterHub

After running, you'll see URLs to access Prometheus and Grafana through the JupyterHub proxy.

### 2. Start Collectors on Compute Nodes

To monitor a compute node, run one or both of these scripts:

For system metrics:
```bash
./start_node_exporter_collector.sh http://hostname:8080 &
```

For NVIDIA GPU metrics:
```bash
./start_dcgm_collector.sh http://hostname:8080 &
```

Replace `hostname:8080` with the address of your HTTP service discovery API.

## Dashboards

After deployment, you can access:

- **Prometheus**: `https://jupyter.nersc.gov/user/<username>/proxy/9090/query`
- **Grafana**: `https://jupyter.nersc.gov/user/<username>/proxy/3000/login`

Default Grafana login is admin/admin. You'll be prompted to change the password on first login.

### Configuring Grafana

1. Log in to Grafana
2. Add Prometheus as a data source:
   - URL: `http://localhost:9090`
   - Access: Server (default)
3. Import the [provided dashboard](/grafana_dashboard.json) or create your own

### Dashboard Preview
Here’s a preview of the Grafana dashboard:

![Grafana Dashboard Preview](grafana_dashboard_preview.png)


## Troubleshooting

### Common Issues

1. **Services not starting**:
   - Check if ports are already in use
   - Verify you have the necessary permissions

2. **Cannot access dashboards**:
   - Ensure JupyterHub is running
   - Check the service prefix in the URLs

3. **No metrics appearing**:
   - Verify collectors are running
   - Check Prometheus targets page for errors

### Logs

- Check the terminal output for error messages
- Prometheus logs are available in the Prometheus web UI under Status > Runtime & Build Information

## Cleaning Up

To stop all services, press Ctrl+C in the terminal where you started the services.

To remove all installed components:
```bash
make clean
```

## Advanced Configuration

### Customizing Prometheus

Edit `prometheus_template.yml` to modify the Prometheus configuration, such as:
- Scrape intervals
- Retention policies
- Alert rules

### Customizing Container Images

You can modify the container images used in [`start_grafana_prometheus.sh`](./start_grafana_prometheus.sh):
- Change `PROM_IMAGE` to use a different Prometheus version
- Change `GF_IMAGE` to use a different Grafana version
- Adjust container parameters as needed

### Customizing Network Ports

If the default ports conflict with other services, you can modify:
- `PROM_PORT` (default: 9090) for Prometheus
- `GF_PORT` (default: 3000) for Grafana
- `HTTP_SD_PORT` (default: 8080) for the HTTP service discovery API

### Customizing Metrics Collection

#### Node Exporter Metrics

In [`start_node_exporter_collector.sh`](./start_node_exporter_collector.sh), you can enable or disable specific collectors:
- Add or remove `--collector.<name>` flags to customize which system metrics are collected
- Current enabled collectors include CPU, memory, network devices, InfiniBand, and network stats
- See the [node_exporter documentation](https://github.com/prometheus/node_exporter) for all available collectors

#### DCGM Metrics

For GPU metrics in [`start_dcgm_collector.sh`](./start_dcgm_collector.sh):
- Modify the `dcgm_metrics.csv` file to select which GPU metrics to collect
- Adjust the collection interval with the `-c` parameter (in milliseconds)
- See the [DCGM Exporter documentation](https://github.com/NVIDIA/dcgm-exporter) for more options

### Adding Custom Exporters

1. Create a new script similar to the existing collector scripts (see [`start_dcgm_collector.sh`](./start_dcgm_collector.sh) for help)
2. Register your exporter with the HTTP service discovery API using the appropriate labels