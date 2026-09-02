#!/bin/bash
export PATH=$HOME/.local/bin:$PATH

echo "Starting Pinggy tunnel on port 8501..."
ssh -p 443 -R0:localhost:8501 -o StrictHostKeyChecking=no a.pinggy.io > tunnel.log 2>&1 &
echo "Tunnel started. Waiting for URL to generate..."
for i in {1..15}; do
    if grep -q "http" tunnel.log; then
        grep "http" tunnel.log
        break
    fi
    sleep 1
done
cat tunnel.log

# Ensure the DB is seeded before app starts
echo "Waiting 15 seconds for Neo4j to fully boot..."
sleep 15
python seed_db.py

# Start Streamlit
echo "Starting Streamlit..."
python -m streamlit run app.py --server.address 0.0.0.0 --server.port 8501
