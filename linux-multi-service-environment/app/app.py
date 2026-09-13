#!/usr/bin/env python3

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)


HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <title>Fouad's App</title>

    <style>
        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            background: #f5f7f9;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI",
                         Roboto, Helvetica, Arial, sans-serif;
            color: #1f2937;
        }

        .container {
            max-width: 760px;
            min-height: 100vh;
            margin: 0 auto;
            padding: 42px 32px 24px;
            background: #ffffff;
        }

        h1 {
            margin: 0 0 28px;
            font-size: 32px;
            font-weight: 700;
            color: #111827;
        }

        .status {
            display: inline-block;
            margin-bottom: 34px;
            padding: 6px 14px;
            border-radius: 999px;
            background: #dcfce7;
            color: #166534;
            font-size: 14px;
            font-weight: 600;
        }

        .description {
            margin-bottom: 30px;
            color: #4b5563;
            font-size: 15px;
            line-height: 1.6;
        }

        .details {
            width: 100%;
        }

        .row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 12px 0;
            border-bottom: 1px solid #edf0f2;
            font-size: 14px;
        }

        .label {
            color: #111827;
            font-weight: 600;
        }

        .value {
            color: #4b5563;
            text-align: right;
        }

        .health {
            margin-top: 30px;
            color: #374151;
            font-size: 14px;
        }

        .health a {
            color: #2563eb;
            text-decoration: none;
        }

        .health a:hover {
            text-decoration: underline;
        }

        footer {
            margin-top: 24px;
            color: #9ca3af;
            font-size: 12px;
        }
    </style>
</head>

<body>

<div class="container">

    <h1>Fouad's App</h1>

    <div class="status">
        • Online
    </div>

    <div class="description">
        A Flask application running on a Linux server,
        provisioned and managed with automated infrastructure tooling.
    </div>

    <div class="details">

        <div class="row">
            <span class="label">Application</span>
            <span class="value">Flask</span>
        </div>

        <div class="row">
            <span class="label">Process Manager</span>
            <span class="value">systemd</span>
        </div>

        <div class="row">
            <span class="label">Reverse Proxy</span>
            <span class="value">Nginx</span>
        </div>

        <div class="row">
            <span class="label">Transport</span>
            <span class="value">HTTPS / TLS</span>
        </div>

        <div class="row">
            <span class="label">Firewall</span>
            <span class="value">UFW</span>
        </div>

        <div class="row">
            <span class="label">Intrusion Protection</span>
            <span class="value">Fail2ban</span>
        </div>

        <div class="row">
            <span class="label">Monitoring</span>
            <span class="value">Cron health checks</span>
        </div>

        <div class="row">
            <span class="label">Backups</span>
            <span class="value">Automated daily backups</span>
        </div>

    </div>

    <div class="health">
        Backend health:
        <a href="/health">Check health endpoint →</a>
    </div>

    <footer>
        Deployed on Linux · Provisioned with Bash
    </footer>

</div>

</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(HTML)


@app.route("/health")
def health():
    return jsonify({
        "service": "backend",
        "status": "healthy"
    })


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=3000
    )