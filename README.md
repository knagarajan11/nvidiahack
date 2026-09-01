# Plant Disease Identification MVP

This is an end-to-end AI application for plant disease identification, tailored to run on an NVIDIA DGX system. It provides farmers with a mobile-friendly web interface to upload pictures of plant leaves, analyzes them using an NVIDIA NIM microservice (Llama 3.2 Vision), and cross-references the findings against an agricultural knowledge base stored in Neo4j (GraphRAG).

## Architecture

*   **Frontend**: Streamlit (Mobile responsive, exposed to internet via localtunnel).
*   **AI Vision Model**: Local NVIDIA Inference Microservice (NIM) `llama-3.2-11b-vision-instruct` utilizing DGX GPUs.
*   **Graph Database**: Neo4j, populated with `disease_knowledge.json` and PlantVillage mappings.
*   **RAG Agent**: A multi-step Langchain/OpenAI-compatible agent that queries vision APIs, searches the graph database, and returns agricultural advice.

## Deployment on NVIDIA DGX (Docker)

If your system supports Docker Compose:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/knagarajan11/nvidiahack.git
   cd nvidiahack
   ```

2. **Configure Environment:**
   Copy the example environment file and add your NGC API Key.
   ```bash
   cp .env.example .env
   nano .env # Add your NGC_API_KEY
   ```

3. **Deploy using Docker Compose:**
   The `docker-compose.yml` is pre-configured to reserve NVIDIA GPUs.
   ```bash
   docker-compose up -d --build
   ```

## Deployment on NVIDIA DGX (Apptainer / HPC SIF)

If you are on a shared DGX cluster (like SLURM) where Docker is not available and you use **Apptainer**:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/knagarajan11/nvidiahack.git
   cd nvidiahack
   ```

2. **Configure your environment variables:**
   ```bash
   export NGC_API_KEY="your_api_key_here"
   export NEO4J_PASSWORD="password123"
   ```

3. **Ensure you have your NIM SIF file:**
   Make sure your NIM container image (e.g., `llama32-vision.sif`) is located in the `nvidiahack` directory. If it is named differently, update the filename in `start_apptainer.sh`.

4. **Run the startup script:**
   ```bash
   chmod +x start_apptainer.sh
   ./start_apptainer.sh
   ```
   This script will automatically pull Neo4j and a Python/Node environment using Apptainer, start them in the background, and launch the Streamlit frontend with your public URL.

4. **Access the application:**
   The application will automatically start `localtunnel` and output a public URL (e.g., `https://plant-disease-mvp-...loca.lt`) to the Streamlit container logs. Farmers can use this URL on their mobile phones.
   
   To find the URL, check the logs:
   ```bash
   docker-compose logs -f streamlit
   ```

## Development & Maintenance

*   **Database Seeding**: The Neo4j database is seeded automatically when the Streamlit container starts via `seed_db.py`.
*   **Customizing the Knowledge Base**: Edit `data/disease_knowledge.json` or `data/leaf-map.json` and restart the containers to update the Neo4j graph.
