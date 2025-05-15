# Configuration
PYTHON_BIN := /global/common/software/nersc/pe/conda-envs/24.1.0/python-3.11/nersc-python/bin/python
PYTHON_USER_BASE := $(SCRATCH)/nersc_metrics_install/python-3.11
PIP_PACKAGES := fastapi uvicorn
NODE_EXPORTER_VERSION := 1.9.1
DOWNLOAD_URL := https://github.com/prometheus/node_exporter/releases/download/v$(NODE_EXPORTER_VERSION)/node_exporter-$(NODE_EXPORTER_VERSION).linux-amd64.tar.gz
DOWNLOAD_DIR := $(SCRATCH)/nersc_metrics_install
DOWNLOAD_FILE := $(DOWNLOAD_DIR)/node_exporter-$(NODE_EXPORTER_VERSION).linux-amd64.tar.gz

# Set Python user base for pip installations
export PYTHONUSERBASE := $(PYTHON_USER_BASE)

.PHONY: all install download clean

all: install download

# Create Python user base directory
$(PYTHON_USER_BASE):
	mkdir -p $(PYTHON_USER_BASE)

# Create download directory
$(DOWNLOAD_DIR):
	mkdir -p $(DOWNLOAD_DIR)

# Install pip packages
install: $(PYTHON_USER_BASE)
	$(PYTHON_BIN) -m pip install --user $(PIP_PACKAGES)

# Download and extract tar file
download: $(DOWNLOAD_DIR)
	wget -O $(DOWNLOAD_FILE) $(DOWNLOAD_URL) || curl -o $(DOWNLOAD_FILE) $(DOWNLOAD_URL)
	tar -xzf $(DOWNLOAD_FILE) -C $(DOWNLOAD_DIR)

# Clean up
clean:
	rm -rf $(PYTHON_USER_BASE) $(DOWNLOAD_DIR)