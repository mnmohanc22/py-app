# Flask Production Setup — RHEL Linux + systemd

Production-ready Flask application with:
- **Gunicorn** WSGI server (Unix socket)
- **Nginx** reverse proxy (HTTP / HTTPS)
- **systemd** service with hardening
- **logrotate** for log management

---

## Project Structure

```
flaskapp_project/
├── app/                        # Flask application source
│   ├── __init__.py             # App factory
│   ├── config.py               # Config classes
│   └── routes.py               # Blueprints / routes
├── wsgi.py                     # Gunicorn entry point
├── gunicorn.conf.py            # Gunicorn settings
├── requirements.txt            # Python dependencies
└── .env.example                # Environment variable template
```

---

## Manual Service Management

```bash
# Status
systemctl status flaskapp

# Start / Stop / Restart
systemctl start   flaskapp
systemctl stop    flaskapp
systemctl restart flaskapp

# Zero-downtime reload (gunicorn re-forks workers)
systemctl reload flaskapp

# View logs
journalctl -u flaskapp -f
tail -f /opt/flaskapp/logs/app.log
tail -f /opt/flaskapp/logs/gunicorn-access.log

# Health check
curl http://localhost/health
```

---

## Architecture

```
Client
  │  HTTP :80 / HTTPS :443
  ▼
nginx  (reverse proxy + SSL termination)
  │  Unix socket: /run/flaskapp/flaskapp.sock
  ▼
gunicorn  (WSGI server — N worker processes)
  │
  ▼
Flask application  (wsgi:application)
  │
  ├── /opt/flaskapp/logs/app.log
  ├── /opt/flaskapp/logs/gunicorn-access.log
  └── journalctl -u flaskapp
```

---

## SSL / HTTPS

Set `flaskapp_ssl_enabled: true` in `group_vars/all.yml` and provide cert paths:

```yaml
flaskapp_ssl_enabled:   true
flaskapp_ssl_cert_path: "/etc/pki/tls/certs/flaskapp.crt"
flaskapp_ssl_key_path:  "/etc/pki/tls/private/flaskapp.key"
```

---

## Security Notes

- gunicorn binds to a Unix socket only — never exposed directly
- systemd service runs as unprivileged `flaskapp` user
- `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem` enabled in service unit
- `.env` file deployed with mode `0600`
- Secrets should never be stored in plaintext

---

## Tested On

- RHEL 8.x
- RHEL 9.x
- Rocky Linux 8 / 9
