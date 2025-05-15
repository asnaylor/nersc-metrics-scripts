#!/global/common/software/nersc/pe/conda-envs/24.1.0/python-3.11/nersc-python/bin/python
import argparse
import json
import logging
import os
from typing import Dict, List, Optional, Set, Union

import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Request, Security, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("prometheus_http_sd")

# Define data models
class Target(BaseModel):
    """Model representing a Prometheus target with its labels."""
    targets: List[str]
    labels: Dict[str, str]

class TargetList(BaseModel):
    """Model for adding or removing multiple targets at once."""
    targets: List[Target]

# Initialize FastAPI app
app = FastAPI(
    title="Prometheus HTTP Service Discovery",
    description="HTTP Service Discovery endpoint for Prometheus",
    version="1.0.0",
)

# Bearer token
security = HTTPBearer(auto_error=False)

# In-memory storage for targets
targets_store: List[Target] = []

def get_api_key() -> str:
    """Get the API key from the application state."""
    return app.state.api_key

async def verify_api_key(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
    expected_api_key: str = Depends(get_api_key),
) -> str:
    """
    Verify that the Bearer token is valid.
    
    Args:
        credentials: The Bearer token credentials from the request
        expected_api_key: The expected API key from app state
        
    Returns:
        The API key if valid
        
    Raises:
        HTTPException: If the Bearer token is invalid or missing
    """
    if credentials and credentials.credentials == expected_api_key:
        return credentials.credentials
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing Bearer token",
    )


@app.get("/targets", response_model=List[Target])
async def get_targets(
    request: Request,
    _: str = Depends(verify_api_key),
) -> List[Target]:
    """
    Get all targets for Prometheus service discovery.
    
    This endpoint is called by Prometheus to discover targets.
    
    Args:
        request: The HTTP request
        _: The verified API key
        
    Returns:
        List of targets with their labels
    """
    # Log the refresh interval if provided by Prometheus
    refresh_interval = request.headers.get("X-Prometheus-Refresh-Interval-Seconds")
    if refresh_interval:
        logger.info(f"Prometheus refresh interval: {refresh_interval} seconds")
    
    return targets_store

@app.post("/targets", status_code=status.HTTP_201_CREATED)
async def add_targets(
    target_list: TargetList,
    _: str = Depends(verify_api_key),
) -> Dict[str, str]:
    """
    Add new targets to the service discovery.
    
    Args:
        target_list: List of targets to add
        _: The verified API key
        
    Returns:
        Confirmation message
    """
    for target in target_list.targets:
        # Check if target already exists (based on targets and labels)
        if target not in targets_store:
            targets_store.append(target)
    
    logger.info(f"Added {len(target_list.targets)} targets")
    return {"message": f"Added {len(target_list.targets)} targets"}

@app.delete("/targets")
async def remove_targets(
    target_list: TargetList,
    _: str = Depends(verify_api_key),
) -> Dict[str, str]:
    """
    Remove specific targets from the service discovery.
    
    Args:
        target_list: List of targets to remove
        _: The verified API key
        
    Returns:
        Confirmation message
    """
    removed_count = 0
    
    for target_to_remove in target_list.targets:
        # Convert to dict for comparison
        target_dict = target_to_remove.dict()
        
        # Find and remove matching targets
        for i, existing_target in enumerate(targets_store[:]):
            if (existing_target.targets == target_dict["targets"] and 
                existing_target.labels == target_dict["labels"]):
                targets_store.pop(i)
                removed_count += 1
                break
    
    logger.info(f"Removed {removed_count} targets")
    return {"message": f"Removed {removed_count} targets"}

@app.delete("/targets/all")
async def remove_all_targets(
    _: str = Depends(verify_api_key),
) -> Dict[str, str]:
    """
    Remove all targets from the service discovery.
    
    Args:
        _: The verified API key
        
    Returns:
        Confirmation message
    """
    count = len(targets_store)
    targets_store.clear()
    
    logger.info(f"Removed all {count} targets")
    return {"message": f"Removed all {count} targets"}

def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments.
    
    Returns:
        Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description="Prometheus HTTP Service Discovery Server"
    )
    parser.add_argument(
        "--api-key",
        required=True,
        help="API key for authentication",
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Host to bind the server to (default: 0.0.0.0)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="Port to bind the server to (default: 8000)",
    )
    return parser.parse_args()

def main() -> None:
    """Main entry point for the application."""
    args = parse_args()
    
    # Store API key in app state
    app.state.api_key = args.api_key
    
    # Start the server
    logger.info(f"Starting server on {args.host}:{args.port}")
    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
    )

if __name__ == "__main__":
    main()


# Usage Examples
# Start the server:

# Run
# python prometheus_http_sd.py --api-key your_secret_key
# Add targets with curl:

# Run
# curl -X POST http://localhost:8000/targets \
#   -H "Authorization: Bearer your_secret_key"  \
#   -H "Content-Type: application/json" \
#   -d '{
#     "targets": [
#       {
#         "targets": ["10.0.10.2:9100", "10.0.10.3:9100"],
#         "labels": {
#           "__meta_datacenter": "london",
#           "__meta_prometheus_job": "node"
#         }
#       }
#     ]
#   }'
# Remove specific targets:

# Run
# curl -X DELETE http://localhost:8000/targets \
#   -H "Authorization: Bearer your_secret_key"  \
#   -H "Content-Type: application/json" \
#   -d '{
#     "targets": [
#       {
#         "targets": ["10.0.10.2:9100", "10.0.10.3:9100"],
#         "labels": {
#           "__meta_datacenter": "london",
#           "__meta_prometheus_job": "node"
#         }
#       }
#     ]
#   }'
# Configure Prometheus to use this HTTP SD endpoint:

# Yaml

# Apply
# scrape_configs:
#   - job_name: 'http_sd_targets'
#     http_sd_configs:
#       - url: http://localhost:8000/targets
#         refresh_interval: 30s
#         authorization:
#           type: Bearer
#           credentials: your_secret_key
# The implementation follows Prometheus HTTP SD requirements and provides a secure, flexible way to dynamically manage targets.