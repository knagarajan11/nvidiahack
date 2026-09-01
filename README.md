# Plant Disease Identification MVP

This is an end-to-end AI application for plant disease identification, tailored to run on an NVIDIA DGX system. It provides farmers with a mobile-friendly web interface to upload pictures of plant leaves, analyzes them using an NVIDIA NIM microservice (Llama 3.2 Vision), and cross-references the findings against an agricultural knowledge base stored in Neo4j (GraphRAG).

## Architecture

*   **Frontend**: Streamlit (Mobile responsive, exposed to internet via localtunnel).
*   **AI Vision Model**: Local NVIDIA Inference Microservice (NIM) `llama-3.2-11b-vision-instruct` utilizing DGX GPUs.
*   **Graph Database**: Neo4j, populated with `disease_knowledge.json` and PlantVillage mappings.
*   **RAG Agent**: A multi-step Langchain/OpenAI-compatible agent that queries vision APIs, searches the graph database, and returns agricultural advice.

## Deployment on NVIDIA DGX (from GitHub)

1. **Clone the repository on your DGX system:**
   ```bash
   git clone <YOUR_GITHUB_REPO_URL>
   cd plant_disease_mvp
   ```

2. **Configure Environment:**
   Copy the example environment file and add your NGC API Key. The NGC key is required for the NIM container to pull the model weights.
   ```bash
   cp .env.example .env
   nano .env # Add your NGC_API_KEY
   ```

3. **Deploy using Docker Compose:**
   The `docker-compose.yml` is pre-configured to reserve all NVIDIA GPUs (`capabilities: [gpu]`).
   ```bash
   docker-compose up -d --build
   ```

4. **Access the application:**
   The application will automatically start `localtunnel` and output a public URL (e.g., `https://plant-disease-mvp-...loca.lt`) to the Streamlit container logs. Farmers can use this URL on their mobile phones.
   
   To find the URL, check the logs:
   ```bash
   docker-compose logs -f streamlit
   ```

## Development & Maintenance

*   **Database Seeding**: The Neo4j database is seeded automatically when the Streamlit container starts via `seed_db.py`.
*   **Customizing the Knowledge Base**: Edit `data/disease_knowledge.json` or `data/leaf-map.json` and restart the containers to update the Neo4j graph.
