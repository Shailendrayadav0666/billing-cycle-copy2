# Billing-Cycle

A baseline full-stack POC for a billing and task management dashboard. The app has a **React + Vite** frontend, a **FastAPI** backend, and uses in-memory mock data so no database is required.

## Features

- **Login / Sign-up page** with a split-screen product details panel.
- **Billing page** showing the current Standard plan, renewal date, usage cards, and on-demand usage tiles.
- **Tasks page** with a simple to-do list and a working **+** button to add new tasks.

## Tech Stack

- **Frontend:** React 19, Vite, React Router, plain CSS
- **Backend:** FastAPI (Python)
- **Data:** In-memory mock store (no database needed for this POC)

## Project Structure

```
Billing-Cycle/
├── backend/        # FastAPI app
│   ├── .gitignore
│   ├── main.py
│   └── requirements.txt
└── frontend/       # React + Vite app
    ├── .gitignore
    ├── package.json
    ├── vite.config.js
    └── src/
        ├── App.jsx
        ├── App.css
        ├── main.jsx
        ├── context/
        │   └── AuthContext.jsx
        └── pages/
            ├── Login.jsx
            ├── Billing.jsx
            └── Tasks.jsx
```

## Setup

### 1. Backend

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

### 2. Frontend

```bash
cd frontend
npm install
```

## Running the App

Start the backend and frontend in separate terminals.

### Backend

```bash
cd backend
.venv/bin/uvicorn main:app --host 127.0.0.1 --port 8000
```

The API will be available at `http://127.0.0.1:8000`.

### Frontend

```bash
cd frontend
npm run dev
```

The dev server will open at `http://localhost:5173`.

## Demo Login

Use the default mock account to sign in:

- **Email:** `tpg@example.com`
- **Password:** `password`

You can also create a new account via the sign-up form.

## API Routes

| Method | Route              | Description                 |
|--------|--------------------|-----------------------------|
| POST   | `/api/auth/login`  | Sign in and get a token     |
| POST   | `/api/auth/register` | Create a new mock account |
| GET    | `/api/users/me`    | Get current user details    |
| GET    | `/api/billing`     | Get billing and usage data  |
| GET    | `/api/tasks`       | Get task list               |
| POST   | `/api/tasks`       | Add a new task              |

## Build for Production

To build the frontend static files:

```bash
cd frontend
npm run build
```

The compiled assets are output to `frontend/dist/`. When `dist/` exists, the FastAPI backend will automatically serve the built frontend at `http://127.0.0.1:8000/`.
