#!/bin/bash
export PATH=$HOME/.local/bin:$PATH

# Wait for Neo4j to be ready (check bolt port, not just HTTP)
echo "Waiting for Neo4j to be ready..."
for i in $(seq 1 60); do
    if python -c "
from neo4j import GraphDatabase
import os
d = GraphDatabase.driver(
    os.getenv('NEO4J_URI', 'bolt://localhost:7687'),
    auth=(os.getenv('NEO4J_USER', 'neo4j'), os.getenv('NEO4J_PASSWORD', 'password123'))
)
d.verify_connectivity()
d.close()
print('connected')
" 2>/dev/null; then
        echo "Neo4j is ready!"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "WARNING: Neo4j may not be ready, continuing anyway..."
    fi
    sleep 2
done

# Seed the database
echo "Seeding database..."
python seed_db.py

# Kill any previous Streamlit/tunnel on port 8501
fuser -k 8501/tcp 2>/dev/null || true

# Start Pinggy tunnel on port 8501
echo "Starting Pinggy tunnel on port 8501..."
ssh -p 443 -R0:localhost:8501 -o StrictHostKeyChecking=no -o ConnectTimeout=10 a.pinggy.io > tunnel.log 2>&1 &
echo "Tunnel started. Waiting for URL to generate..."
for i in {1..15}; do
    if grep -q "http" tunnel.log; then
        grep "http" tunnel.log
        break
    fi
    sleep 1
done
cat tunnel.log

# Start Streamlit
echo "Starting Streamlit..."
python -m streamlit run app.py --server.address 0.0.0.0 --server.port 8501
