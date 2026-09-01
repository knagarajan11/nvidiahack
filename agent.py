import json
from nvidia_client import client
from neo_retriever import DiseaseRAG

# We use the same vision instruct model for text tasks
TEXT_MODEL = "meta/llama-3.2-11b-vision-instruct"

def run_agent(disease_result, user_question=""):
    rag = DiseaseRAG()
    try:
        diagnosis = json.loads(
            disease_result.replace("```json", "").replace("```", "").strip()
        )
    except Exception:
        diagnosis = {
            "disease": "Uncertain",
            "confidence": 0,
            "visible_symptoms": [],
            "reasoning": disease_result,
        }

    disease = diagnosis.get("disease", "Uncertain")
    query = (
        disease + " " +
        " ".join(diagnosis.get("visible_symptoms", [])) + " " +
        user_question
    )

    retrieved = rag.search(query, top_k=3)
    knowledge = [item["document"] for item in retrieved]
    
    rag.close()

    agent_prompt = f"""
You are the Tomato Plant Health Agent.

VISION RESULT:
{json.dumps(diagnosis, indent=2)}

RETRIEVED TOMATO DISEASE KNOWLEDGE FROM NEO4J:
{json.dumps(knowledge, indent=2)}

USER QUESTION:
{user_question}

Tasks:
1. Evaluate the vision result.
2. Use retrieved knowledge.
3. Do not invent agricultural facts.
4. If confidence is low, say the diagnosis is uncertain.
5. Provide practical next steps.
6. Answer the user's question if supplied.
7. Never claim the diagnosis is definitive.

Return ONLY valid JSON:
{{
  "final_diagnosis": "",
  "confidence": 0,
  "severity": "",
  "why": "",
  "symptoms": [],
  "recommendations": [],
  "prevention": [],
  "follow_up": "",
  "sources_used": []
}}
"""

    response = client.chat.completions.create(
        model=TEXT_MODEL,
        messages=[
            {"role": "system", "content": "You are a careful agricultural AI agent."},
            {"role": "user", "content": agent_prompt},
        ],
        temperature=0.1,
        max_tokens=1200,
    )
    return response.choices[0].message.content
