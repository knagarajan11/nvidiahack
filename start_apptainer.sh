#!/bin/bash
# Start script for DGX systems using Apptainer instead of Docker
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

# Authenticate with NGC container registry (required to pull NIM images)
echo "Authenticating with NGC container registry..."
echo "$NGC_API_KEY" | apptainer remote login --username '$oauthtoken' --password-stdin docker://nvcr.io 2>/dev/null \
    || apptainer registry login --username '$oauthtoken' --password "$NGC_API_KEY" docker://nvcr.io 2>/dev/null \
    || echo "WARNING: Could not auto-login to nvcr.io. If the SIF is not cached, pull may fail."

# Set APPTAINER_DOCKER_USERNAME and PASSWORD so that apptainer can pull from nvcr.io
export APPTAINER_DOCKER_USERNAME='$oauthtoken'
export APPTAINER_DOCKER_PASSWORD="$NGC_API_KEY"

# Cleanup on exit safely — register trap BEFORE starting background processes
cleanup() {
    echo "Shutting down services..."
    [ -n "$NEO4J_PID" ] && kill "$NEO4J_PID" 2>/dev/null
    [ -n "$NIM_PID" ] && kill "$NIM_PID" 2>/dev/null
    wait 2>/dev/null
    echo "All services stopped."
}
trap cleanup EXIT INT TERM

echo "Starting Neo4j via Apptainer..."
export NEO4J_AUTH="neo4j/${NEO4J_PASSWORD:-password123}"
mkdir -p neo4j_data neo4j_logs
apptainer run --writable-tmpfs \
    --bind ./neo4j_data:/data \
    --bind ./neo4j_logs:/logs \
    --env NEO4J_AUTH="$NEO4J_AUTH" \
    docker://neo4j:5-community > neo4j.log 2>&1 &
NEO4J_PID=$!
echo "Neo4j started with PID $NEO4J_PID"

echo "Starting Local NVIDIA NIM via Apptainer..."
# Use a pre-built SIF or pull from nvcr.io
NIM_SIF="${NIM_SIF_PATH:-docker://nvcr.io/nim/meta/llama-3.2-11b-vision-instruct:latest}"
mkdir -p nim_cache
apptainer run --nv \
    --writable-tmpfs \
    --bind ./nim_cache:/opt/nim/.cache \
    --env NGC_API_KEY="$NGC_API_KEY" \
    "$NIM_SIF" > nim.log 2>&1 &
NIM_PID=$!
echo "NIM started with PID $NIM_PID using image $NIM_SIF"

# Wait for NIM to become healthy before starting Streamlit
echo "Waiting for NIM to be ready (checking http://localhost:8000/v1/models)..."
for i in $(seq 1 120); do
    if curl -sf http://localhost:8000/v1/models > /dev/null 2>&1; then
        echo "NIM is ready!"
        break
    fi
    if ! kill -0 "$NIM_PID" 2>/dev/null; then
        echo "ERROR: NIM process died. Check nim.log for details:"
        tail -20 nim.log
        exit 1
    fi
    if [ "$i" -eq 120 ]; then
        echo "ERROR: NIM did not start within 120 seconds. Check nim.log:"
        tail -20 nim.log
        exit 1
    fi
    sleep 5
done

echo "Starting Streamlit MVP via Apptainer..."
# We use a container that has both Python and Node (for localtunnel/pinggy)
apptainer exec --writable-tmpfs \
    --env NEO4J_URI=bolt://localhost:7687 \
    --env NEO4J_USER=neo4j \
    --env NEO4J_PASSWORD="${NEO4J_PASSWORD:-password123}" \
    --env NIM_API_BASE_URL=http://localhost:8000/v1 \
    --env NVIDIA_API_KEY="$NGC_API_KEY" \
    --net --network=host \
    docker://nikolaik/python-nodejs:python3.10-nodejs18 bash -c "
    export PATH=\$HOME/.local/bin:\$PATH
    pip install --user -r requirements.txt
    bash run.sh
"
