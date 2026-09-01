import os
from neo4j import GraphDatabase

NEO4J_URI = os.getenv("NEO4J_URI", "bolt://localhost:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password123")

class DiseaseRAG:
    def __init__(self):
        self.driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))

    def search(self, disease_query, top_k=3):
        # In a real Neo4j vector setup we'd use vector indexes.
        # For this MVP, we perform a text-based/graph traversal search
        # based on the disease name to retrieve context.
        query = """
        MATCH (d:Disease)
        WHERE toLower(d.name) CONTAINS toLower($query) OR toLower($query) CONTAINS toLower(d.name)
        RETURN d.name AS disease, d.symptoms AS symptoms, d.causes AS causes, 
               d.recommendations AS recommendations, d.prevention AS prevention
        LIMIT $limit
        """
        
        results = []
        with self.driver.session() as session:
            records = session.run(query, query=disease_query, limit=top_k)
            for record in records:
                results.append({
                    "score": 1.0, # Dummy score since it's an exact/partial match
                    "document": {
                        "disease": record["disease"],
                        "symptoms": record["symptoms"],
                        "causes": record["causes"],
                        "recommendations": record["recommendations"],
                        "prevention": record["prevention"]
                    }
                })
        
        # Fallback if no exact graph match found
        if not results:
            fallback_query = """
            MATCH (d:Disease)
            RETURN d.name AS disease, d.symptoms AS symptoms, d.causes AS causes, 
                   d.recommendations AS recommendations, d.prevention AS prevention
            """
            with self.driver.session() as session:
                records = session.run(fallback_query)
                all_docs = [dict(record) for record in records]
                # Simple python-based fallback search (in production use Neo4j Vector Search)
                scored = []
                for doc in all_docs:
                    score = 0
                    if doc["disease"].lower() in disease_query.lower(): score += 10
                    scored.append({"score": score, "document": doc})
                scored.sort(key=lambda x: x["score"], reverse=True)
                results = scored[:top_k]
                
        return results

    def close(self):
        self.driver.close()
