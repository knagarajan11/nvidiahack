#!/bin/bash
# Start script for DGX systems using Apptainer instead of Docker
# Uses NVIDIA Cloud API for inference (no local NIM needed)
set -e

# Resolve script directory so .env is always found regardless of where you run from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load environment variables from .env if it exists
if [ -f ".env" ]; then
    echo "Loading .env file..."
    set -a
    source .env
    set +a
else
    echo "WARNING: No .env file found in $SCRIPT_DIR"
    echo "Copy .env.example to .env and fill in your credentials."
    exit 1
fi

# Validate required environment variables
if [ -z "$NGC_API_KEY" ] || [ "$NGC_API_KEY" = "your_ngc_api_key_here" ]; then
    echo "ERROR: NGC_API_KEY is not set or still has placeholder value."
    echo "Please set a valid NGC API key in your .env file."
    exit 1
fi

echo "Using NVIDIA Cloud API at https://integrate.api.nvidia.com/v1"

# Cleanup on exit safely — register trap BEFORE starting background processes
cleanup() {
    echo "Shutting down services..."
    [ -n "$NEO4J_PID" ] && kill "$NEO4J_PID" 2>/dev/null
    wait 2>/dev/null
    echo "All services stopped."
}
trap cleanup EXIT INT TERM

echo "Starting Neo4j via Apptainer..."
export NEO4J_AUTH="neo4j/${NEO4J_PASSWORD:-password123}"
mkdir -p neo4j_data neo4j_logs
apptainer run --writable-tmpfs --cleanenv \
    --bind ./neo4j_data:/data \
    --bind ./neo4j_logs:/logs \
    --env NEO4J_AUTH="$NEO4J_AUTH" \
    docker://neo4j:5-community > neo4j.log 2>&1 &
NEO4J_PID=$!
echo "Neo4j started with PID $NEO4J_PID"

# Wait for Neo4j to be ready
echo "Waiting for Neo4j to be ready..."
for i in $(seq 1 60); do
    if curl -sf http://localhost:7474 > /dev/null 2>&1; then
        echo "Neo4j is ready!"
        break
    fi
    if ! kill -0 "$NEO4J_PID" 2>/dev/null; then
        echo "ERROR: Neo4j process died. Check neo4j.log:"
        tail -20 neo4j.log
        exit 1
    fi
    if [ "$i" -eq 60 ]; then
        echo "WARNING: Neo4j may still be starting. Continuing anyway..."
    fi
    sleep 2
done

echo "Starting Streamlit MVP via Apptainer..."
# Point to NVIDIA Cloud API instead of local NIM
apptainer exec --writable-tmpfs \
    --env NEO4J_URI=bolt://localhost:7687 \
    --env NEO4J_USER=neo4j \
    --env NEO4J_PASSWORD="${NEO4J_PASSWORD:-password123}" \
    --env NIM_API_BASE_URL=https://integrate.api.nvidia.com/v1 \
    --env NVIDIA_API_KEY="$NGC_API_KEY" \
    --net --network=host \
    docker://nikolaik/python-nodejs:python3.10-nodejs18 bash -c "
    export PATH=\$HOME/.local/bin:\$PATH
    pip install --user -r requirements.txt
    bash run.sh
"

