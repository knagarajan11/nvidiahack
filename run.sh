#!/bin/bash
export PATH=$HOME/.local/bin:$PATH

echo "Starting localtunnel on port 8501..."
npx localtunnel --port 8501 --subdomain plant-disease-mvp-$RANDOM > localtunnel.log 2>&1 &
echo "Localtunnel started. Checking log for URL..."
sleep 2
cat localtunnel.log

# Ensure the DB is seeded before app starts
echo "Waiting 15 seconds for Neo4j to fully boot..."
sleep 15
python seed_db.py

# Start Streamlit
echo "Starting Streamlit..."
python -m streamlit run app.py --server.address 0.0.0.0 --server.port 8501
