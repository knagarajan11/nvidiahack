#!/bin/bash
# Start script for DGX systems using Apptainer instead of Docker

echo "Starting Neo4j via Apptainer..."
export NEO4J_AUTH=neo4j/${NEO4J_PASSWORD:-password123}
mkdir -p neo4j_data neo4j_logs
apptainer run --writable-tmpfs \
    --bind ./neo4j_data:/data \
    --bind ./neo4j_logs:/logs \
    --env NEO4J_AUTH=$NEO4J_AUTH \
    docker://neo4j:5-community > neo4j.log 2>&1 &
NEO4J_PID=$!
echo "Neo4j started with PID $NEO4J_PID"

echo "Starting Local NVIDIA NIM via Apptainer..."
# Assuming you have llama32-vision.sif in your home directory or current directory
# Ensure NGC_API_KEY is exported before running this script
if [ -f "llama32-vision.sif" ]; then
    apptainer run --nv --env NGC_API_KEY=$NGC_API_KEY llama32-vision.sif > nim.log 2>&1 &
    NIM_PID=$!
    echo "NIM started with PID $NIM_PID"
else
    echo "WARNING: llama32-vision.sif not found in current directory. Make sure NIM is running!"
fi

echo "Starting Streamlit MVP via Apptainer..."
# We use a container that has both Python and Node (for localtunnel)
apptainer exec --writable-tmpfs docker://nikolaik/python-nodejs:python3.10-nodejs18 bash -c "
    export PATH=\$HOME/.local/bin:\$PATH
    pip install --user -r requirements.txt
    npm install localtunnel
    bash run.sh
"

# Cleanup on exit safely
cleanup() {
    echo "Shutting down services..."
    [ -n "$NEO4J_PID" ] && kill $NEO4J_PID
    [ -n "$NIM_PID" ] && kill $NIM_PID
}
trap cleanup EXIT
