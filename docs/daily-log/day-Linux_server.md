Day X – Production Deployment (Linux + systemd + Reverse Proxy)
Context

The backend was previously running locally on Windows using uvicorn --reload.
The goal was to migrate it to a dedicated Linux server and convert it into a
production-style service.

What Was Implemented

Installed PostgreSQL on Ubuntu 24.04

Created dedicated database and user

Migrated backend from Windows to Linux server

Created Python virtual environment

Installed required dependencies manually

Fixed missing email-validator dependency

Created systemd service for FastAPI backend

Enabled auto-start on boot

Locked backend to 127.0.0.1 (internal only)

Installed Nginx

Configured Nginx reverse proxy

Exposed backend through port 80 (LAN only)

Architectural Change

Before:

Windows PC
→ Uvicorn (direct exposure)
→ SQLite / PostgreSQL

After:

Client
→ Nginx (port 80)
→ Uvicorn (127.0.0.1:8000)
→ PostgreSQL

Clear separation between:

Web server

Application server

Database

Key Decisions

Do not expose backend directly to LAN

Use systemd instead of manual uvicorn execution

Separate process management from networking

Avoid internet exposure at this stage

Keep deployment LAN-only for development

What Was Learned

Clean environments expose hidden dependency assumptions

Production deployment requires explicit process management

Reverse proxies are architectural boundaries, not just routing tools

systemd ensures resilience and restart safety

Architecture clarity reduces future deployment risk

System Status

Backend running as systemd service

Nginx handling all external traffic

PostgreSQL running locally

Accessible via: http://192.168.29.70/docs

Not exposed to public internet

Hardening Addendum:

UFW enabled (22, 80 only)

PostgreSQL bound to localhost

Uvicorn bound to localhost

Nginx rate limiting configured

No public exposure