from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from datetime import datetime, timedelta

app = FastAPI(title="Billing & Tasks POC")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory mock store (no database)
users = {
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

billing_data = {
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

PLANS = {
    "Standard": {"price": 20.0, "label": "$20/month"},
    "Premium": {"price": 40.0, "label": "$40/month"},
}
DAYS_IN_CYCLE = 30
PREMIUM_USAGES = [
    {
        "id": "chat-credits",
        "label": "Chat credits",
        "used": 0,
        "total": 10000,
        "help": "Messages used this billing cycle.",
    },
    {
        "id": "chatbots",
        "label": "Chatbots",
        "used": 0,
        "total": 10,
        "help": "Active chatbot agents out of the included limit.",
    },
    {
        "id": "documents-pages",
        "label": "Documents pages",
        "used": 0,
        "total": 5000,
        "help": "You can add 5000 more pages of your documents.",
    },
]
PREMIUM_ON_DEMAND_NOTICE = "On-demand credit is available on your Premium plan."

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


def charge_card(email: str, amount: float) -> dict:
    """Deterministic dummy payment gateway (no external service, no randomness).

    Any email starting with "fail" simulates a declined card; every other
    email simulates a successful charge. Keyed only on the email prefix so
    both paths are reproducible on demand.
    """
    if email.startswith("fail"):
        return {"status": "card_declined", "message": "Your card was declined."}
    return {"status": "success"}


def _compute_prorated_charge(email: str) -> dict:
    """Server-side proration math shared by the preview and upgrade endpoints."""
    renew_at_date = datetime.strptime(billing_data[email]["renew_at"], "%b %d, %Y")
    days_remaining = max(1, (renew_at_date - datetime.today()).days)
    daily_delta = (PLANS["Premium"]["price"] - PLANS["Standard"]["price"]) / DAYS_IN_CYCLE
    prorated_charge = round(daily_delta * days_remaining, 2)
    return {
        "days_remaining": days_remaining,
        "prorated_charge": prorated_charge,
    }


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


@app.get("/api/billing/upgrade-preview")
def billing_upgrade_preview(email: str):
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    record = billing_data.get(email, billing_data["tpg@example.com"])
    if record["plan_name"] == "Premium":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="already_premium")

    proration = _compute_prorated_charge(email)
    return {
        "current_plan": "Standard",
        "new_plan": "Premium",
        "days_remaining": proration["days_remaining"],
        "prorated_charge": proration["prorated_charge"],
        "next_renewal_price": PLANS["Premium"]["price"],
        "renew_at": record["renew_at"],
    }


@app.post("/api/billing/upgrade")
def billing_upgrade(payload: UpgradeRequest):
    email = payload.email
    if email not in users:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    record = billing_data.get(email, billing_data["tpg@example.com"])
    if record["plan_name"] == "Premium":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="already_premium")

    proration = _compute_prorated_charge(email)
    charge_result = charge_card(email, proration["prorated_charge"])
    if charge_result["status"] != "success":
        return JSONResponse(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            content={"detail": "card_declined", "message": charge_result["message"]},
        )

    users[email]["plan"] = "Premium"
    users[email]["price"] = PLANS["Premium"]["label"]
    record["plan_name"] = "Premium"
    record["price"] = PLANS["Premium"]["label"]
    record["usages"] = [dict(item) for item in PREMIUM_USAGES]
    record["on_demand_usage"]["notice"] = PREMIUM_ON_DEMAND_NOTICE

    return {"status": "success", "plan": "Premium", "charge": proration["prorated_charge"]}


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
