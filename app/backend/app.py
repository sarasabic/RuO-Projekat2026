"""Emoji Movie Quiz - backend"""

import os
import re
import socket

import psycopg
from flask import Flask, jsonify, request

app = Flask(__name__)

DB_SETTINGS = {
    "host": os.environ.get("DB_HOST", "db"),
    "port": int(os.environ.get("DB_PORT", "5432")),
    "dbname": os.environ.get("DB_NAME", "quiz"),
    "user": os.environ.get("DB_USER", "quiz_app"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "connect_timeout": 3,
}
POINTS_PER_CORRECT_GUESS = 10


def db():
    """Open a new connection for one request. Simple, and enough for a demo app."""
    return psycopg.connect(**DB_SETTINGS)


def normalize(title):
    """Make guessing forgiving: 'The Lion King' == 'lion king!' == 'LionKing'."""
    text = title.lower().strip()
    text = re.sub(r"^the\s+", "", text)    # ignore a leading "the"
    return re.sub(r"[^a-z0-9]", "", text)  # keep only letters and digits


@app.get("/api/health")
def health():
    """Liveness: the web process answers. Used by the Docker HEALTHCHECK (does not touch the DB)."""
    return jsonify(status="ok")


@app.get("/api/ready")
def ready():
    """Readiness: can we reach the database right now?"""
    try:
        with db() as conn:
            conn.execute("SELECT 1")
    except psycopg.Error:
        return jsonify(status="database unavailable"), 503
    return jsonify(status="ok")


@app.get("/api/info")
def info():
    """Shown in the page footer: proves the chain browser -> frontend -> backend -> database."""
    with db() as conn:
        version = conn.execute("SHOW server_version").fetchone()[0]
    return jsonify(backend=socket.gethostname(), database=f"PostgreSQL {version}", db_host=DB_SETTINGS["host"])


@app.get("/api/puzzle")
def puzzle():
    """A random movie the player has not seen in this game (?exclude=1,2,3). The title is NOT sent."""
    exclude = [int(x) for x in request.args.get("exclude", "").split(",") if x.isdigit()]
    with db() as conn:
        row = conn.execute(
            "SELECT id, emojis, year FROM quiz.movies WHERE NOT (id = ANY(%s)) ORDER BY random() LIMIT 1",
            (exclude,),
        ).fetchone()
    if row is None:
        return jsonify(error="no more puzzles"), 404
    return jsonify(id=row[0], emojis=row[1], year=row[2])


@app.post("/api/guess")
def guess():
    """Check a guess. The answer is revealed either way, so the player learns something."""
    data = request.get_json(silent=True) or {}
    try:
        movie_id = int(data.get("id"))
    except (TypeError, ValueError):
        return jsonify(error="id must be a number"), 400
    with db() as conn:
        row = conn.execute("SELECT title FROM quiz.movies WHERE id = %s", (movie_id,)).fetchone()
    if row is None:
        return jsonify(error="unknown puzzle"), 404
    correct = normalize(str(data.get("guess", ""))) == normalize(row[0])
    return jsonify(correct=correct, title=row[0], points=POINTS_PER_CORRECT_GUESS if correct else 0)


@app.get("/api/scores")
def top_scores():
    """Leaderboard: top 10, the earlier score wins a tie."""
    with db() as conn:
        rows = conn.execute(
            "SELECT player, points, played_at FROM quiz.scores ORDER BY points DESC, played_at LIMIT 10"
        ).fetchall()
    return jsonify([{"player": p, "points": pts, "played_at": t.isoformat()} for p, pts, t in rows])


@app.post("/api/scores")
def save_score():
    """Save a finished game. Validation here AND in the table constraints (defense in depth)."""
    data = request.get_json(silent=True) or {}
    player = str(data.get("player", "")).strip()[:20]
    points = data.get("points")
    if not player or type(points) is not int or points < 0:
        return jsonify(error="player (1-20 characters) and points (integer >= 0) are required"), 400
    with db() as conn:
        conn.execute("INSERT INTO quiz.scores (player, points) VALUES (%s, %s)", (player, points))
    return jsonify(player=player, points=points), 201