#!/bin/bash
# Quick deploy script: pull latest code and run
set -e

echo "=== Fetching latest from GitHub ==="
git fetch origin main
git reset --hard origin/main

echo "=== Setting executable permissions ==="
chmod +x start_apptainer.sh run.sh

echo "=== Starting application ==="
./start_apptainer.sh
