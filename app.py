import json
import streamlit as st
from nvidia_client import analyze_leaf
from agent import run_agent

st.set_page_config(
    page_title="Plant Disease MVP",
    page_icon="🌿",
    layout="centered",
)

st.markdown("""
<style>
    .reportview-container {
        background: #f0f8ff;
    }
    .stButton>button {
        background-color: #4CAF50;
        color: white;
        border-radius: 8px;
        padding: 10px 24px;
        font-size: 16px;
    }
    .stMetric {
        background-color: #ffffff;
        padding: 15px;
        border-radius: 10px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
</style>
""", unsafe_allow_html=True)

st.title("🌿 Plant Disease AI Agent")
st.caption("Powered by NVIDIA DGX, local NIM, and Neo4j GraphRAG")

st.write(
    "Welcome Farmer! Upload a picture of a leaf from your mobile phone. "
    "Our AI will analyze the image, consult the Neo4j agricultural knowledge graph, "
    "and provide actionable insights."
)

uploaded_file = st.file_uploader(
    "📷 Upload leaf image",
    type=["jpg", "jpeg", "png"],
)

question = st.text_input(
    "💬 Optional question",
    placeholder="e.g., How can I stop this from spreading?",
)

if uploaded_file:
    st.image(
        uploaded_file,
        caption="Uploaded Image",
        use_container_width=True,
    )

    if st.button("🔍 Analyze Plant", type="primary"):
        with st.spinner("Vision AI analyzing leaf via Local NIM..."):
            diagnosis = analyze_leaf(uploaded_file.getvalue())

        with st.spinner("AI Agent retrieving knowledge from Neo4j..."):
            final_result = run_agent(diagnosis, question)

        try:
            result = json.loads(
                final_result.replace("```json", "").replace("```", "").strip()
            )
        except Exception:
            st.error("Agent returned unexpected output.")
            st.code(final_result)
            st.stop()

        st.success("Analysis complete")
        st.header("🌱 Diagnosis")
        st.subheader(result.get("final_diagnosis", "Uncertain"))

        c1, c2 = st.columns(2)
        with c1:
            st.metric("AI Confidence", f'{result.get("confidence", 0)}%')
        with c2:
            st.metric("Severity", result.get("severity", "Unknown"))

        st.header("🔎 Why?")
        st.write(result.get("why", ""))

        st.header("🍃 Symptoms")
        for item in result.get("symptoms", []):
            st.write("• " + item)

        st.header("🌿 Recommended Actions")
        for item in result.get("recommendations", []):
            st.write("• " + item)

        st.header("🛡️ Prevention")
        for item in result.get("prevention", []):
            st.write("• " + item)

        st.header("🤖 Agent Recommendation")
        st.info(result.get("follow_up", ""))

        sources = result.get("sources_used", [])
        if sources:
            st.caption("Knowledge used:")
            for source in sources:
                st.write("• " + source)

        st.warning(
            "AI-assisted identification only. Verify important crop-management "
            "decisions with reliable agricultural guidance."
        )
