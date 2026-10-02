# JanSampark AI — Smart Civic Infrastructure 🏛️🤖

A modular, AI-powered civic issue reporting and administration platform. JanSampark AI connects citizens reporting municipal issues (e.g., potholes, garbage overflow, broken streetlights) directly to administrative departments through automated verification and routing.

---

## 🏗️ Architecture Overview

The system is built across three primary tiers:
1. **AI Pipeline & Backend**: Core computer vision and classification engine with automated departmental routing.
2. **Admin Dashboard**: Real-time management portal for civic authorities to triage, inspect AI confidence scores, and resolve reports.
3. **Citizen Application**: Mobile interface for capturing geotagged, authenticated civic complaints.

```mermaid
graph TD
    subgraph "Core AI & Backend"
        AI[AI Engine - Schemas & Routing]
        API[FastAPI Inference Endpoints]
        Runner[run_local_api.py Entrypoint]
    end

    subgraph "Admin & Citizen Portals"
        Admin[Civic Admin Dashboard - React/Vite]
        Citizen[Citizen Mobile Client]
    end

    Citizen --> API
    API --> AI
    Admin --> API
```

---

## 🚀 AI Backend & Local Inference Server

The Python backend provides a high-throughput FastAPI service powered by CLIP zero-shot classification and custom civic issue routing rules.

### Running the Local API Server
```bash
# Activate your virtual environment
.\venv\Scripts\activate

# Launch the FastAPI inference server
python run_local_api.py
```
The server will start on `http://127.0.0.1:8000`.

---

## 🖥️ Smart Civic Admin Web App

The administrative dashboard provides civic authorities with real-time issue streams, department-wise task allocation, and automated AI image analysis.

### Running the Admin Dashboard
```bash
cd smart-civic-system-ak6/smart-civic-admin

# Install dependencies
npm install

# Start Vite development server
npm run dev
```
The dashboard runs at `http://localhost:5173`.

---

## 📁 Repository Structure

```text
├── configs/               # Model classifier, detector, and routing configurations
├── jansampark_ai/         # Core AI & backend package
├── smart-civic-system-ak6/
│   └── smart-civic-admin/ # React + Vite Admin Web Dashboard
│       ├── public/
│       ├── src/
│       │   ├── components/ # AdminLayout, SharedUI, ViewComplaint
│       │   ├── pages/      # Dashboard, Complaints, Analytics, Users, LoginPage
│       │   └── firebase.js # Firestore & Auth configuration
│       └── package.json
├── tests/                 # Unit and integration test suite
├── demo_garbage.png       # Test fixture image (garbage)
├── demo_test_image.png    # Test fixture image (civic issue)
├── run_local_api.py       # Entry point runner script
├── .gitignore
├── README.md
└── requirements.txt
```
