from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from datetime import datetime, timedelta

app = FastAPI(title="Billing & Tasks POC")

# Story 1.1 -- Mid-Cycle Subscription Upgrade (Standard -> Premium)
PLANS: dict = {
    "Standard": {"price": 20.0, "label": "$20/month"},
    "Premium": {"price": 40.0, "label": "$40/month"},
}
PREMIUM_QUOTA_TOTALS = {
    "chat-credits": 10000,
    "chatbots": 10,
    "documents-pages": 5000,
}
DAYS_IN_CYCLE = 30
PREMIUM_ON_DEMAND_NOTICE = "On-demand credit is available on your Premium plan."

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory mock store (no database)
users: dict = {
    "tpg@example.com": {
        "id": 1,
        "name": "TPG",
        "email": "tpg@example.com",
        "password": "password",
        "plan": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=30)).strftime("%b %d, %Y"),
    }
}

billing_data: dict = {
    "tpg@example.com": {
        "plan_name": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=30)).strftime("%b %d, %Y"),
        "usages": [
            {
                "id": "chat-credits",
                "label": "Chat credits",
                "used": 100,
                "total": 2000,
                "help": "Messages used this billing cycle.",
            },
            {
                "id": "chatbots",
                "label": "Chatbots",
                "used": 1,
                "total": 3,
                "help": "Active chatbot agents out of the included limit.",
            },
            {
                "id": "documents-pages",
                "label": "Documents pages",
                "used": 15,
                "total": 1000,
                "help": "You can add 985 more pages of your documents.",
            },
        ],
        "included_usage": {
            "title": "Your included usage",
            "items": [
                {"id": "daily", "label": "Daily quota", "used_percent": 5, "resets_in": "23 hours"},
                {"id": "weekly", "label": "Weekly quota", "used_percent": 10, "resets_in": "5 days"},
            ],
            "help": "Usage included in your plan.",
        },
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$18.00",
            "your_usage": "$0.00",
            "help": "Additional usage charges beyond your included quota.",
            "notice": "On-demand credit is not available in standard plan for usage beyond your included quota.",
        },
    }
}

tasks_data = {
    "tpg@example.com": [
        {"id": 1, "title": "Review monthly invoice", "status": "pending", "due": "Today"},
        {"id": 2, "title": "Add team member", "status": "completed", "due": "Yesterday"},
        {"id": 3, "title": "Update billing address", "status": "pending", "due": "In 2 days"},
    ]
}


class LoginRequest(BaseModel):
    email: str
    password: str


class RegisterRequest(BaseModel):
    name: str
    email: str
    password: str


class TokenRequest(BaseModel):
    token: str


class TaskCreateRequest(BaseModel):
    email: str
    title: str


class UpgradeRequest(BaseModel):
    email: str


@app.post("/api/auth/login")
def login(payload: LoginRequest):
    user = users.get(payload.email)
    if not user or user["password"] != payload.password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    return {"access_token": payload.email, "user": {k: v for k, v in user.items() if k != "password"}}


@app.post("/api/auth/register")
def register(payload: RegisterRequest):
    if payload.email in users:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Account already exists")
    users[payload.email] = {
        "id": len(users) + 1,
        "name": payload.name,
        "email": payload.email,
        "password": payload.password,
        "plan": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=30)).strftime("%b %d, %Y"),
    }
    billing_data[payload.email] = {
        "plan_name": "Standard",
        "price": "$20/month",
        "renew_at": (datetime.today() + timedelta(days=30)).strftime("%b %d, %Y"),
        "usages": [
            {
                "id": "chat-credits",
                "label": "Chat credits",
                "used": 0,
                "total": 2000,
                "help": "Messages used this billing cycle.",
            },
            {
                "id": "chatbots",
                "label": "Chatbots",
                "used": 0,
                "total": 3,
                "help": "Active chatbot agents out of the included limit.",
            },
            {
                "id": "documents-pages",
                "label": "Documents pages",
                "used": 0,
                "total": 1000,
                "help": "You can add 1000 more pages of your documents.",
            },
        ],
        "included_usage": {
            "title": "Your included usage",
            "items": [
                {"id": "daily", "label": "Daily quota", "used_percent": 5, "resets_in": "23 hours"},
                {"id": "weekly", "label": "Weekly quota", "used_percent": 10, "resets_in": "5 days"},
            ],
            "help": "Usage included in your plan.",
        },
        "on_demand_usage": {
            "title": "On-demand usage",
            "remaining_balance": "$0.00",
            "your_usage": "$0.00",
            "help": "Additional usage charges beyond your included quota.",
            "notice": "On-demand credit is not available in standard plan for usage beyond your included quota.",
        },
    }
    tasks_data[payload.email] = [
        {"id": 1, "title": "Explore the dashboard", "status": "completed", "due": "Today"},
    ]
    return {"access_token": payload.email, "user": {k: v for k, v in users[payload.email].items() if k != "password"}}


@app.get("/api/users/me")
def me(email: str):
    user = users.get(email)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return {k: v for k, v in user.items() if k != "password"}


@app.get("/api/billing")
def billing(email: str):
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return billing_data.get(email, billing_data["tpg@example.com"])


def charge_card(email: str, amount: float) -> dict:
    """Deterministic dummy payment gateway (REQ-NF-01, ARCH-02).

    Pure function of the email prefix only -- no randomness, no network call,
    no clock read -- so the success and card_declined paths are both
    reproducible on demand for a demo.
    """
    if email.startswith("fail"):
        return {"status": "card_declined", "message": "Your card was declined."}
    return {"status": "success"}


def _calculate_proration(renew_at: str) -> tuple[int, float]:
    """Server-side-only proration (REQ-F-04, ARCH-01). Returns (days_remaining, prorated_charge)."""
    renew_at_date = datetime.strptime(renew_at, "%b %d, %Y")
    days_remaining = max(1, (renew_at_date - datetime.today()).days)
    daily_delta = (PLANS["Premium"]["price"] - PLANS["Standard"]["price"]) / DAYS_IN_CYCLE
    prorated_charge = round(daily_delta * days_remaining, 2)
    return days_remaining, prorated_charge


@app.get("/api/billing/upgrade-preview")
def upgrade_preview(email: str):
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    data = billing_data.get(email, billing_data["tpg@example.com"])
    # Already-Premium guard runs before any proration logic (REQ-F-10, ARCH-04)
    if data["plan_name"] == "Premium":
        return JSONResponse(status_code=status.HTTP_409_CONFLICT, content={"detail": "already_premium"})
    days_remaining, prorated_charge = _calculate_proration(data["renew_at"])
    return {
        "current_plan": data["plan_name"],
        "new_plan": "Premium",
        "days_remaining": days_remaining,
        "prorated_charge": prorated_charge,
        "next_renewal_price": PLANS["Premium"]["price"],
        "renew_at": data["renew_at"],
    }


@app.post("/api/billing/upgrade")
def upgrade(payload: UpgradeRequest):
    email = payload.email
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    data = billing_data.get(email, billing_data["tpg@example.com"])
    # Already-Premium guard runs before any mutation (REQ-F-10, ARCH-04)
    if data["plan_name"] == "Premium":
        return JSONResponse(status_code=status.HTTP_409_CONFLICT, content={"detail": "already_premium"})

    _, prorated_charge = _calculate_proration(data["renew_at"])
    result = charge_card(email, prorated_charge)

    # Failure path: no mutation to users or billing_data before this point, and none after
    # this check either (REQ-F-08, REQ-NF-02, ARCH-03).
    if result["status"] != "success":
        return JSONResponse(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            content={"detail": "card_declined", "message": result["message"]},
        )

    # Success path: atomically flip plan, price and quotas (REQ-F-07).
    users[email]["plan"] = "Premium"
    users[email]["price"] = PLANS["Premium"]["label"]
    data["plan_name"] = "Premium"
    data["price"] = PLANS["Premium"]["label"]
    for usage in data["usages"]:
        if usage["id"] in PREMIUM_QUOTA_TOTALS:
            usage["total"] = PREMIUM_QUOTA_TOTALS[usage["id"]]
    data["on_demand_usage"]["notice"] = PREMIUM_ON_DEMAND_NOTICE

    return {"status": "success", "plan": "Premium", "charge": prorated_charge}


@app.get("/api/tasks")
def tasks(email: str):
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return tasks_data.get(email, [])


@app.post("/api/tasks")
def add_task(payload: TaskCreateRequest):
    if payload.email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user_tasks = tasks_data.setdefault(payload.email, [])
    new_id = max((t["id"] for t in user_tasks), default=0) + 1
    new_task = {"id": new_id, "title": payload.title, "status": "pending", "due": "Today"}
    user_tasks.append(new_task)
    return new_task


# Serve the built frontend if it exists (production build)
dist_dir = Path(__file__).resolve().parent.parent / "frontend" / "dist"
if dist_dir.is_dir():
    app.mount("/", StaticFiles(directory=dist_dir, html=True), name="static")
