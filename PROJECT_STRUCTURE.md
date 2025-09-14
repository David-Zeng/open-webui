# Open WebUI Project Structure

This document outlines the project structure of Open WebUI, covering its frontend, backend, and deployment aspects.

## 1. Overview

Open WebUI is a web-based user interface for interacting with large language models, primarily Ollama. It features a SvelteKit frontend, a Python FastAPI backend, and Kubernetes-based deployment options.

## 2. Folder Structure

```
.
├── backend/
│   ├── .dockerignore
│   ├── .gitignore
│   ├── dev.sh
│   ├── requirements.txt
│   ├── data/
│   └── open_webui/
│       ├── __init__.py
│       ├── alembic.ini
│       ├── config.py
│       ├── constants.py
│       ├── env.py
│       ├── functions.py
│       ├── main.py
│       ├── tasks.py
│       ├── internal/
│       │   ├── db.py
│       │   └── wrappers.py
│       │   └── migrations/
│       │       └── ... (Alembic migration scripts)
│       ├── migrations/
│       │   └── ... (Alembic migration related files)
│       ├── models/
│       │   ├── auths.py
│       │   ├── channels.py
│       │   ├── chats.py
│       │   ├── ... (Other data models)
│       ├── retrieval/
│       │   ├── utils.py
│       │   ├── loaders/
│       │   │   └── ... (Document loaders)
│       │   ├── models/
│       │   │   └── ... (Reranker models)
│       │   ├── vector/
│       │   │   └── ... (Vector database integrations)
│       │   └── web/
│       │       └── ... (Web search integrations)
│       ├── routers/
│       │   ├── auths.py
│       │   ├── configs.py
│       │   ├── evaluations.py
│       │   ├── ... (Other API route definitions)
│       ├── socket/
│       │   ├── main.py
│       │   └── utils.py
│       ├── static/
│       │   └── ... (Static assets for backend)
│       ├── storage/
│       │   └── provider.py
│       ├── test/
│       │   └── ... (Backend tests)
│       └── utils/
│           ├── access_control.py
│           ├── auth.py
│           ├── chat.py
│           ├── ... (Other utility functions)
├── src/
│   ├── app.css
│   ├── app.d.ts
│   ├── app.html
│   ├── tailwind.css
│   ├── lib/
│   │   ├── constants.ts
│   │   ├── dayjs.js
│   │   ├── emoji-groups.json
│   │   ├── emoji-shortcodes.json
│   │   ├── index.ts
│   │   ├── apis/
│   │   │   └── ... (Frontend API clients)
│   │   ├── components/
│   │   │   └── ... (Reusable Svelte components)
│   │   ├── i18n/
│   │   │   └── ... (Internationalization files)
│   │   ├── pyodide/
│   │   │   └── ... (Pyodide integration files)
│   │   ├── stores/
│   │   │   └── ... (Svelte stores for state management)
│   │   ├── types/
│   │   │   └── ... (TypeScript type definitions)
│   │   ├── utils/
│   │   │   └── ... (Frontend utility functions)
│   │   └── workers/
│   │       └── ... (Web workers)
│   └── routes/
│       ├── +error.svelte
│       ├── +layout.js
│       ├── +layout.svelte
│       ├── (app)/
│       │   └── ... (Application routes)
│       ├── auth/
│       │   └── +page.svelte
│       └── ... (Other top-level routes)
├── kubernetes/
│   ├── helm/
│   │   └── README.md (References external Helm charts)
│   └── manifest/
│       ├── base/
│       │   ├── kustomization.yaml
│       │   ├── ollama-service.yaml
│       │   ├── ollama-statefulset.yaml
│       │   ├── open-webui.yaml
│       │   ├── webui-deployment.yaml
│       │   ├── webui-ingress.yaml
│       │   ├── webui-pvc.yaml
│       │   └── webui-service.yaml
│       └── gpu/
│           ├── kustomization.yaml
│           └── ollama-statefulset-gpu.yaml
└── ... (Other root level files like package.json, INSTALLATION.md, etc.)
```

## 3. Architectural Flowchart

```mermaid
graph TD
    A[User Interface - SvelteKit] --> B(Frontend API Calls - src/lib/apis)
    B --> C{Backend - FastAPI}
    C --> D[Database - SQLAlchemy/Alembic]
    C --> E[Ollama Service]
    C --> F[Retrieval Augmented Generation - RAG]
    C --> G[WebSockets - Real-time Communication]

    subgraph Frontend
        A
        B
        H[Pyodide - In-browser Python]
        A --> H
    end

    subgraph Backend
        C
        D
        E
        F
        G
    end

    subgraph Deployment Kubernetes
        I[Kustomize Base Manifests] --> J[WebUI Deployment]
        I --> K[Ollama Deployment]
        I --> L[WebUI Service]
        I --> M[Ollama Service]
        I --> N[WebUI Ingress]
        I --> O[WebUI PVC]
        P[Kustomize GPU Manifests] --> Q[Ollama GPU StatefulSet]
        I --> P
    end

    J --> A
    K --> E