# 🧠 DocuMind AI

[![Backend CI](https://github.com/AvishkaGihan/documind-ai/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/AvishkaGihan/documind-ai/actions/workflows/backend-ci.yml)
[![Mobile CI](https://github.com/AvishkaGihan/documind-ai/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/AvishkaGihan/documind-ai/actions/workflows/mobile-ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**DocuMind AI** is a secure, high-performance RAG (Retrieval-Augmented Generation) platform that allows users to securely upload PDFs and engage in contextual chat conversations. It guarantees **strict user data isolation** for enterprise-grade safety.

---

## 🚀 Key Features

- 🔒 **Secure Data Isolation**: ChromaDB collections partitioned per user/document pair.
- ⚡ **Lightning Fast Inference**: Powered by LLama 3.3 70B on Groq API.
- 📈 **No API Cost Embeddings**: Uses local `Sentence-Transformers` for vector search offline.
- 🔗 **Citation Tracing**: Every answer includes clickable source page references.
- 📱 **Cross-Platform Mobile**: Beautiful Material 3 experience via Flutter with Riverpod state.

---

## 📐 Architecture & Data Flow

This diagram illustrates how users securely interact with their data, avoiding physical commingling of vectors between documents.

```mermaid
graph TD
    User([📱 User App]) -->|1. Upload PDF| API[🐍 FastAPI Backend]
    API -->|2. Store File| S3[(Storage - S3/Cloud)]
    
    API -->|3. Process| Process[⚙️ Extraction & Chunking]
    Process -->|4. Generate Vectors| Embed[🧠 Sentence Transformers <br> (Local)]
    Embed -->|5. Isolate| VDB[(🗄️ ChromaDB <br> user_X_doc_Y)]

    User -->|6. Ask Question| API
    API -->|7. Query| VDB
    VDB -->|8. Relevant Chunks| API
    API -->|9. Context + Prompt| Groq[🚀 Groq API <br> LLaMA 3.3 70B]
    Groq -->|10. Stream Answer| API
    API -->|11. stream Response| User
```

---

## 🛠️ Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Mobile** | [Flutter 3.41](https://flutter.dev) | Material 3, Riverpod 3, go_router, Dio |
| **Backend** | [FastAPI](https://fastapi.tiangolo.com) | Python 3.12+, Pydantic v2, SQLAlchemy 2.0 |
| **Storage**| ChromaDB, SQLite/Postgres | Isolated collections, relational models |
| **AI/ML**  | LangChain, Sentence Transformers | RAG orchestration, local vector creation |
| **Inference**| [Groq API](https://groq.com) | Ultra-fast LLaMA 3.3 70B processing |

---

## 📂 Project Structure

- **[`/mobile`](file:///home/avishkagihan/Documents/documind-ai/mobile)**: Flutter client application for iOS and Android.
- **[`/backend`](file:///home/avishkagihan/Documents/documind-ai/backend)**: Python business logic server, ML interfaces, and endpoints.
- **[`/docs`](file:///home/avishkagihan/Documents/documind-ai/docs)**: Context guides, rules, and system details for reference.

---

## ⚙️ Getting Started

To explore the workspace components, choose your area of interest and follow the setup guide there:

1.  **Backend Setup**: Go to [/backend](file:///home/avishkagihan/Documents/documind-ai/backend) and read instructions to manage ChromaDB and endpoints.
2.  **Mobile Setup**: Go to [/mobile](file:///home/avishkagihan/Documents/documind-ai/mobile) and follow guidelines on building the Flutter environment.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](file:///home/avishkagihan/Documents/documind-ai/CONTRIBUTING.md) for branch naming conventions and styling rules before submitting a PR.
