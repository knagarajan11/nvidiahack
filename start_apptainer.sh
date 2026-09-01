#!/bin/bash
# Start script for DGX systems using Apptainer instead of Docker

echo "Starting Neo4j via Apptainer..."
export NEO4J_AUTH=neo4j/${NEO4J_PASSWORD:-password123}
apptainer run --env NEO4J_AUTH=$NEO4J_AUTH docker://neo4j:5-community > neo4j.log 2>&1 &
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
apptainer exec docker://nikolaik/python-nodejs:python3.10-nodejs18 bash -c "
    pip install -r requirements.txt
    npm install -g localtunnel
    bash run.sh
"

# Cleanup on exit
trap "kill $NEO4J_PID $NIM_PID" EXIT
