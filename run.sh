#!/bin/bash
# Start localtunnel in the background
echo "Starting localtunnel on port 8501..."
lt --port 8501 --subdomain plant-disease-mvp-$RANDOM > localtunnel.log 2>&1 &
echo "Localtunnel started. Checking log for URL..."
sleep 2
cat localtunnel.log

# Ensure the DB is seeded before app starts
python seed_db.py

# Start Streamlit
echo "Starting Streamlit..."
streamlit run app.py --server.address 0.0.0.0 --server.port 8501
