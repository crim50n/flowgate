from fastapi import FastAPI, Request, Form, Depends, HTTPException, status
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.sessions import SessionMiddleware
from passlib.context import CryptContext
import pyotp
import yaml
import json
import os
import re
import secrets
import subprocess
from pathlib import Path
from typing import Optional

# --- Configuration ---
AUTH_FILE = Path("/var/lib/flowgate/auth.json")
CONFIG_FILE = Path("/etc/flowgate/flowgate.yaml")
SECRET_KEY = os.environ.get("FLOWGATE_WEB_SECRET", secrets.token_hex(32))

app = FastAPI(title="Flowgate Web")

# Session middleware for secure cookie-based sessions
app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY, session_cookie="flowgate_session", max_age=3600, same_site="strict", https_only=False)

app.mount("/static", StaticFiles(directory="/usr/share/flowgate/static"), name="static")
templates = Jinja2Templates(directory="/usr/share/flowgate/templates")

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- Input Validation ---
DOMAIN_REGEX = re.compile(r'^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$')
IP_REGEX = re.compile(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')

def validate_domain(domain: str) -> bool:
    """Validate domain name format."""
    if not domain or len(domain) > 253:
        return False
    return bool(DOMAIN_REGEX.match(domain))

def validate_ip(ip: str) -> bool:
    """Validate IPv4 address format."""
    if not ip:
        return True  # Optional field
    return bool(IP_REGEX.match(ip))

def validate_port(port: Optional[int]) -> bool:
    """Validate port number."""
    if port is None:
        return True
    return 1 <= port <= 65535

# --- Helpers ---

def generate_secure_password(length: int = 16) -> str:
    """Generate a cryptographically secure random password."""
    alphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def get_auth_data():
    if not AUTH_FILE.exists():
        # Generate random password instead of hardcoded default
        generated_password = generate_secure_password()
        default_data = {
            "username": "admin",
            "password_hash": pwd_context.hash(generated_password),
            "totp_secret": None,
            "password_change_required": True
        }
        save_auth_data(default_data)
        # Log generated password to stderr (visible in logs)
        import sys
        print(f"\n{'='*60}", file=sys.stderr)
        print(f"[SECURITY] FlowWeb initial credentials generated:", file=sys.stderr)
        print(f"  Username: admin", file=sys.stderr)
        print(f"  Password: {generated_password}", file=sys.stderr)
        print(f"  CHANGE THIS PASSWORD IMMEDIATELY!", file=sys.stderr)
        print(f"{'='*60}\n", file=sys.stderr)
        return default_data
    with open(AUTH_FILE, 'r') as f:
        return json.load(f)

def save_auth_data(data):
    AUTH_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(AUTH_FILE, 'w') as f:
        json.dump(data, f, indent=2)
    # Secure file permissions (owner read/write only)
    os.chmod(AUTH_FILE, 0o600)

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_hash(password):
    return pwd_context.hash(password)

def run_flowgate(args: list) -> tuple:
    """Run flowgate command with validated arguments."""
    cmd = ["/usr/bin/flowgate"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)

def get_current_user(request: Request) -> Optional[str]:
    """Get current user from session."""
    return request.session.get("user")

def require_auth(request: Request) -> str:
    """Require authentication, return username or raise redirect."""
    user = get_current_user(request)
    if not user:
        raise HTTPException(status_code=302, headers={"Location": "/login"})
    return user

def generate_csrf_token(request: Request) -> str:
    """Generate or retrieve CSRF token from session."""
    if "csrf_token" not in request.session:
        request.session["csrf_token"] = secrets.token_hex(32)
    return request.session["csrf_token"]

def verify_csrf_token(request: Request, token: str) -> bool:
    """Verify CSRF token."""
    session_token = request.session.get("csrf_token")
    if not session_token or not token:
        return False
    return secrets.compare_digest(session_token, token)

def load_domains_config():
    if not CONFIG_FILE.exists():
        return {"domains": {}}
    with open(CONFIG_FILE, 'r') as f:
        return yaml.safe_load(f) or {"domains": {}}

# --- Routes ---

@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login", status_code=302)

    config = load_domains_config()
    domains = config.get("domains", {})

    proxies = {k: v for k, v in domains.items() if v.get('type') == 'proxy'}
    services = {k: v for k, v in domains.items() if v.get('type') == 'service'}

    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "proxies": proxies,
        "services": services,
        "user": user,
        "csrf_token": generate_csrf_token(request)
    })

@app.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    auth = get_auth_data()
    return templates.TemplateResponse("login.html", {
        "request": request,
        "has_2fa": bool(auth.get("totp_secret"))
    })

@app.post("/login")
async def login(request: Request, username: str = Form(...), password: str = Form(...), totp: Optional[str] = Form(None)):
    auth = get_auth_data()

    # Check if this is a 2FA verification (pending_auth in session)
    pending_auth = request.session.get("pending_auth")

    if pending_auth:
        # Second step: verify 2FA code
        if not totp:
            return templates.TemplateResponse("login.html", {
                "request": request,
                "error": "2FA Code Required",
                "require_2fa": True
            })

        totp_obj = pyotp.TOTP(auth["totp_secret"])
        if not totp_obj.verify(totp):
            return templates.TemplateResponse("login.html", {
                "request": request,
                "error": "Invalid 2FA Code",
                "require_2fa": True
            })

        # Clear pending auth and set user session
        del request.session["pending_auth"]
        request.session["user"] = pending_auth["username"]

        # Check if password change is required
        if auth.get("password_change_required"):
            return RedirectResponse(url="/settings?change_password=1", status_code=302)

        return RedirectResponse(url="/", status_code=302)

    # First step: verify username/password
    if username != auth["username"] or not verify_password(password, auth["password_hash"]):
        return templates.TemplateResponse("login.html", {"request": request, "error": "Invalid credentials"})

    if auth.get("totp_secret"):
        # Store authenticated state in session, NOT in HTML form
        request.session["pending_auth"] = {"username": username, "verified": True}
        return templates.TemplateResponse("login.html", {
            "request": request,
            "error": "2FA Code Required",
            "require_2fa": True
        })

    # No 2FA - set session directly
    request.session["user"] = username

    # Check if password change is required
    if auth.get("password_change_required"):
        return RedirectResponse(url="/settings?change_password=1", status_code=302)

    return RedirectResponse(url="/", status_code=302)

@app.get("/logout")
async def logout(request: Request):
    request.session.clear()
    return RedirectResponse(url="/login", status_code=302)

@app.get("/settings", response_class=HTMLResponse)
async def settings_page(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)
    auth = get_auth_data()
    return templates.TemplateResponse("settings.html", {
        "request": request,
        "has_2fa": bool(auth.get("totp_secret")),
        "user": user,
        "csrf_token": generate_csrf_token(request)
    })

@app.post("/settings/update")
async def update_settings(request: Request, username: str = Form(...), password: str = Form(""), csrf_token: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)

    if not verify_csrf_token(request, csrf_token):
        return RedirectResponse("/settings?error=csrf", status_code=302)

    auth = get_auth_data()
    auth["username"] = username
    if password:
        auth["password_hash"] = get_hash(password)

    save_auth_data(auth)
    request.session["user"] = username

    return RedirectResponse(url="/settings", status_code=302)

@app.post("/settings/2fa/setup")
async def setup_2fa(request: Request):
    user = get_current_user(request)
    if not user:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    secret = pyotp.random_base32()
    auth = get_auth_data()
    auth["totp_secret_pending"] = secret
    save_auth_data(auth)

    uri = pyotp.totp.TOTP(secret).provisioning_uri(name=auth["username"], issuer_name="Flowgate")

    return {"secret": secret, "uri": uri}

@app.post("/settings/2fa/verify")
async def verify_2fa_setup(request: Request, code: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    auth = get_auth_data()
    pending_secret = auth.get("totp_secret_pending")

    if not pending_secret:
        return {"success": False, "error": "No pending 2FA setup"}

    totp = pyotp.TOTP(pending_secret)
    if totp.verify(code):
        auth["totp_secret"] = pending_secret
        if "totp_secret_pending" in auth:
            del auth["totp_secret_pending"]
        save_auth_data(auth)
        return {"success": True}

    return {"success": False, "error": "Invalid code"}

@app.post("/settings/2fa/disable")
async def disable_2fa(request: Request, password: str = Form(...), csrf_token: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)

    if not verify_csrf_token(request, csrf_token):
        return RedirectResponse("/settings?error=csrf", status_code=302)

    # Require password confirmation to disable 2FA
    auth = get_auth_data()
    if not verify_password(password, auth["password_hash"]):
        return RedirectResponse("/settings?error=invalid_password", status_code=302)

    auth["totp_secret"] = None
    save_auth_data(auth)
    return RedirectResponse(url="/settings", status_code=302)

# --- Actions ---

@app.post("/action/add")
async def add_domain(request: Request, domain: str = Form(...), type: str = Form(...), port: Optional[int] = Form(None), ip: Optional[str] = Form(None), csrf_token: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)

    if not verify_csrf_token(request, csrf_token):
        return RedirectResponse("/?error=csrf", status_code=302)

    # Validate inputs
    if not validate_domain(domain):
        return RedirectResponse("/?error=invalid_domain", status_code=302)

    if type == "proxy":
        success, msg = run_flowgate(["add", domain])
    elif type == "service":
        if not validate_port(port):
            return RedirectResponse("/?error=invalid_port", status_code=302)
        if not validate_ip(ip):
            return RedirectResponse("/?error=invalid_ip", status_code=302)

        cmd = ["service", domain, str(port)]
        if ip:
            cmd += ["--ip", ip]
        success, msg = run_flowgate(cmd)
    else:
        return RedirectResponse("/?error=invalid_type", status_code=302)

    return RedirectResponse(url="/", status_code=302)

@app.post("/action/remove")
async def remove_domain(request: Request, domain: str = Form(...), csrf_token: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)

    if not verify_csrf_token(request, csrf_token):
        return RedirectResponse("/?error=csrf", status_code=302)

    if not validate_domain(domain):
        return RedirectResponse("/?error=invalid_domain", status_code=302)

    run_flowgate(["remove", domain])
    return RedirectResponse(url="/", status_code=302)

@app.post("/action/sync")
async def sync_config(request: Request, csrf_token: str = Form(...)):
    user = get_current_user(request)
    if not user:
        return RedirectResponse("/login", status_code=302)

    if not verify_csrf_token(request, csrf_token):
        return RedirectResponse("/?error=csrf", status_code=302)

    run_flowgate(["sync"])
    return RedirectResponse(url="/", status_code=302)
