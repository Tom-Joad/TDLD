#!/usr/bin/env python3
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

LISTS_DIR = os.environ.get("LISTS_DIR", "/app/data/config/lists")
CONFIG_DIR = os.environ.get("YTDLP_CONFIG_DIR", "/app/data/config/ytdlpconfig")
LOGS_DIR = os.environ.get("LOGS_DIR", "/app/data/logs")
LISTS = {
    "audioonly": "Audio Only",
    "channels": "Channels",
    "playlists": "Playlists",
}
MAX_BODY_SIZE = 1024 * 1024  # 1 MiB, more than enough for a list of URLs
LOG_FILES = {f"{key}.log": f"{label} (scheduled)" for key, label in LISTS.items()}
LOG_FILES.update({f"{key}-manual.log": f"{label} (manual)" for key, label in LISTS.items()})
LOG_TAIL_LINES = 500

PAGE_TEMPLATE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>ytdl Download Lists</title>
<style>
  body {{ font-family: sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; background:#111; color:#eee; }}
  h1 {{ margin-bottom: 0.25rem; }}
  .banner {{ background:#2ecc71; color:#000; padding:0.5rem 1rem; border-radius:4px; margin-bottom:1rem; }}
  fieldset {{ border:1px solid #444; border-radius:6px; margin-bottom:1.25rem; }}
  legend {{ padding:0 0.5rem; font-weight:bold; }}
  textarea {{ width:100%; box-sizing:border-box; min-height:180px; font-family:monospace; font-size:0.9rem;
             background:#1a1a1a; color:#eee; border:1px solid #333; border-radius:4px; padding:0.5rem; }}
  button {{ background:#2ecc71; color:#000; border:none; padding:0.6rem 1.2rem; border-radius:4px; font-size:1rem; cursor:pointer; }}
  button:hover {{ background:#3ee684; }}
  .log-links {{ display:flex; flex-wrap:wrap; gap:0.5rem; }}
  .log-links a {{ color:#2ecc71; text-decoration:none; border:1px solid #333; border-radius:4px;
                 padding:0.4rem 0.8rem; }}
  .log-links a:hover {{ background:#1a1a1a; }}
  pre {{ background:#1a1a1a; color:#eee; border:1px solid #333; border-radius:4px; padding:0.75rem;
        overflow-x:auto; white-space:pre-wrap; word-break:break-all; }}
</style>
</head>
<body>
<h1>ytdl Download Lists</h1>
{banner}
<fieldset>
  <legend>Download a single link now</legend>
  <form method="post" action="/download">
    <input type="url" name="url" placeholder="https://..." required
           style="width:100%; box-sizing:border-box; font-size:0.9rem; background:#1a1a1a; color:#eee;
                  border:1px solid #333; border-radius:4px; padding:0.5rem; margin-bottom:0.5rem;">
    <div style="display:flex; gap:0.5rem; align-items:center;">
      <select name="profile" style="flex:1; background:#1a1a1a; color:#eee; border:1px solid #333;
              border-radius:4px; padding:0.5rem;">
        {profile_options}
      </select>
      <button type="submit">Download Now</button>
    </div>
  </form>
</fieldset>
<form method="post" action="/save">
{fields}
<button type="submit">Save All</button>
</form>
<fieldset>
  <legend>Logs</legend>
  <div class="log-links">
    {log_links}
  </div>
</fieldset>
</body>
</html>
"""

LOG_LINK_TEMPLATE = '<a href="/log?name={name}" target="_blank">{label}</a>'

LOG_PAGE_TEMPLATE = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>{name} - ytdl Logs</title>
<style>
  body {{ font-family: sans-serif; max-width: 1100px; margin: 2rem auto; padding: 0 1rem; background:#111; color:#eee; }}
  pre {{ background:#1a1a1a; color:#eee; border:1px solid #333; border-radius:4px; padding:0.75rem;
        overflow-x:auto; white-space:pre-wrap; word-break:break-all; font-size:0.85rem; }}
</style>
</head>
<body>
<h1>{name}</h1>
<pre>{content}</pre>
</body>
</html>
"""

FIELD_TEMPLATE = """
<fieldset>
  <legend>{label} ({filename})</legend>
  <textarea name="{key}" placeholder="One URL per line">{content}</textarea>
</fieldset>
"""

PROFILE_OPTION_TEMPLATE = '<option value="{key}">{label}</option>'


def list_path(key):
    return os.path.join(LISTS_DIR, f"{key}.list")


def read_list(key):
    path = list_path(key)
    if not os.path.exists(path):
        return ""
    with open(path, "r") as f:
        return f.read()


def write_list(key, content):
    lines = [line.rstrip() for line in content.replace("\r\n", "\n").split("\n")]
    while lines and lines[-1] == "":
        lines.pop()
    with open(list_path(key), "w") as f:
        for line in lines:
            f.write(line + "\n")


def escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def read_log_tail(name):
    path = os.path.join(LOGS_DIR, name)
    if not os.path.exists(path):
        return "(no log yet)"
    with open(path, "r", errors="replace") as f:
        lines = f.readlines()
    return "".join(lines[-LOG_TAIL_LINES:])


def start_download(profile, url):
    config_path = os.path.join(CONFIG_DIR, f"{profile}.config")
    log_path = os.path.join(LOGS_DIR, f"{profile}-manual.log")
    os.makedirs(LOGS_DIR, exist_ok=True)
    with open(log_path, "a") as log:
        log.write(f"[webui] Manual download requested: {url}\n")
        log.flush()
        subprocess.Popen(
            [
                "yt-dlp",
                "--config-locations", config_path,
                "--batch-file", "/dev/null",
                url,
            ],
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )


class Handler(BaseHTTPRequestHandler):
    def _render(self, banner=""):
        fields = "".join(
            FIELD_TEMPLATE.format(
                label=label, filename=f"{key}.list", key=key, content=escape(read_list(key))
            )
            for key, label in LISTS.items()
        )
        profile_options = "".join(
            PROFILE_OPTION_TEMPLATE.format(key=key, label=label) for key, label in LISTS.items()
        )
        log_links = "".join(
            LOG_LINK_TEMPLATE.format(name=name, label=label) for name, label in LOG_FILES.items()
        )
        return PAGE_TEMPLATE.format(
            banner=banner, fields=fields, profile_options=profile_options, log_links=log_links
        ).encode("utf-8")

    def do_GET(self):
        path = urlsplit(self.path)
        if path.path == "/log":
            self._handle_log_view(parse_qs(path.query))
            return

        if "saved=1" in self.path:
            banner = '<div class="banner">Saved.</div>'
        elif "downloading=1" in self.path:
            banner = '<div class="banner">Download started, check the logs for progress.</div>'
        else:
            banner = ""
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(self._render(banner))

    def _handle_log_view(self, query):
        name = query.get("name", [""])[0]
        if name not in LOG_FILES:
            self.send_response(404)
            self.end_headers()
            return
        content = escape(read_log_tail(name))
        page = LOG_PAGE_TEMPLATE.format(name=escape(name), content=content).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(page)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        if length > MAX_BODY_SIZE:
            self.send_response(413)
            self.end_headers()
            return
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        data = parse_qs(body, keep_blank_values=True)

        if self.path == "/download":
            self._handle_download(data)
            return

        for key in LISTS:
            if key in data:
                write_list(key, data[key][0])
        self.send_response(303)
        self.send_header("Location", "/?saved=1")
        self.end_headers()

    def _handle_download(self, data):
        url = data.get("url", [""])[0].strip()
        profile = data.get("profile", [""])[0].strip()
        if url and profile in LISTS:
            start_download(profile, url)
        self.send_response(303)
        self.send_header("Location", "/?downloading=1")
        self.end_headers()

    def log_message(self, format, *args):
        print("[webui] " + (format % args))


if __name__ == "__main__":
    os.makedirs(LISTS_DIR, exist_ok=True)
    port = int(os.environ.get("WEBUI_PORT", "8083"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"[webui] listening on 0.0.0.0:{port}, editing lists in {LISTS_DIR}")
    server.serve_forever()
