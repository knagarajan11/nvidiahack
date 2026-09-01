import os
import json
from neo4j import GraphDatabase
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password123")

def get_driver():
    return GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

def seed_database():
    driver = get_driver()
    
    # Load data
    knowledge_path = os.path.join(os.path.dirname(__file__), "data", "disease_knowledge.json")
    leaf_map_path = os.path.join(os.path.dirname(__file__), "data", "leaf-map.json")
    
    if not os.path.exists(knowledge_path):
        logger.warning(f"Knowledge file not found at {knowledge_path}")
        return
        
    with open(knowledge_path, "r", encoding="utf-8") as f:
        knowledge_data = json.load(f)
        
    leaf_map_data = {}
    if os.path.exists(leaf_map_path):
        with open(leaf_map_path, "r", encoding="utf-8") as f:
            leaf_map_data = json.load(f)

    with driver.session() as session:
        # Clear existing data for simplicity in MVP
        session.run("MATCH (n) DETACH DELETE n")
        
        # Create Disease nodes and basic properties
        for d in knowledge_data:
            disease_name = d["disease"]
            query = """
            MERGE (d:Disease {name: $name})
            SET d.symptoms = $symptoms,
                d.causes = $causes,
                d.recommendations = $recommendations,
                d.prevention = $prevention
            """
            session.run(query, name=disease_name, 
                        symptoms=d["symptoms"], 
                        causes=d["causes"], 
                        recommendations=d["recommendations"], 
                        prevention=d["prevention"])
            
            logger.info(f"Seeded knowledge for {disease_name}")

        # Map PlantVillage data
        # leaf-map.json format: {"image_id": ["Crop___Disease:::value"]}
        # We will parse this to create Crop nodes and link them to Diseases
        count = 0
        for img_id, labels in leaf_map_data.items():
            for label in labels:
                if "___" in label:
                    parts = label.split("___")
                    crop_name = parts[0].replace("_", " ")
                    disease_part = parts[1].split(":::")[0].replace("_", " ")
                    
                    # Mapping PlantVillage disease names to our knowledge names roughly
                    # For a real MVP we'd map these accurately. Here we just create generic links.
                    session.run("""
                        MERGE (c:Crop {name: $crop})
                        MERGE (d:PlantVillageDisease {name: $disease_part})
                        MERGE (c)-[:SUSCEPTIBLE_TO]->(d)
                    """, crop=crop_name, disease_part=disease_part)
                    count += 1
                    
            if count > 1000:
                # Limit for MVP seeding speed
                break
                
        logger.info("Database seeding complete.")

if __name__ == "__main__":
    try:
        seed_database()
    except Exception as e:
        logger.error(f"Failed to seed database: {e}")
