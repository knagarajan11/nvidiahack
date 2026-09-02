import os
import base64
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

# Default to NVIDIA cloud API; override with NIM_API_BASE_URL for local NIM
API_BASE_URL = os.getenv("NIM_API_BASE_URL", "https://integrate.api.nvidia.com/v1")
# Use NGC_API_KEY for cloud, or NVIDIA_API_KEY for local NIM
API_KEY = os.getenv("NVIDIA_API_KEY") or os.getenv("NGC_API_KEY", "")

client = OpenAI(
    base_url=API_BASE_URL,
    api_key=API_KEY,
)

VISION_MODEL = "meta/llama-3.2-11b-vision-instruct"

def encode_image(image_bytes):
    return base64.b64encode(image_bytes).decode("utf-8")

def analyze_leaf(image_bytes):
    image_base64 = encode_image(image_bytes)

    prompt = """
You are an agricultural AI assistant specializing in tomato plant disease identification.

Analyze the tomato leaf image.

Possible classifications:
- Healthy
- Bacterial spot
- Early blight
- Late blight
- Leaf mold
- Septoria leaf spot
- Spider mites
- Target spot
- Tomato yellow leaf curl virus
- Tomato mosaic virus
- Uncertain

Return ONLY valid JSON:
{
  "disease": "",
  "confidence": 0,
  "severity": "",
  "visible_symptoms": [],
  "reasoning": ""
}

Rules:
1. Only report symptoms actually visible.
2. Do not invent symptoms.
3. If image quality is poor, use "Uncertain".
4. Confidence is an estimate, not a probability.
5. Do not recommend treatment yet.
"""

    response = client.chat.completions.create(
        model=VISION_MODEL,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{image_base64}"
                    },
                },
            ],
        }],
        temperature=0.1,
        max_tokens=700,
    )
    return response.choices[0].message.content
