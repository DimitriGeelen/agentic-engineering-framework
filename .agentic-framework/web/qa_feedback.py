"""Q&A feedback storage — SQLite-backed thumbs up/down tracking (T-267).

Stores user ratings on Q&A answers for quality tracking and prompt iteration.
DB lives in .context/working/ — persistent but not version-controlled.
"""

import sqlite3
import time
from pathlib import Path

from web.shared import PROJECT_ROOT

DB_PATH = PROJECT_ROOT / ".context" / "working" / "qa_feedback.db"


def _get_db() -> sqlite3.Connection:
    """Get a SQLite connection, creating the table if needed."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("""
        CREATE TABLE IF NOT EXISTS feedback (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT NOT NULL,
            answer_preview TEXT,
            model TEXT,
            rating INTEGER NOT NULL,
            comment TEXT,
            created_at REAL NOT NULL
        )
    """)
    conn.commit()
    return conn


def save_feedback(query: str, answer_preview: str, model: str,
                  rating: int, comment: str = "") -> int:
    """Save a feedback entry. Returns the row ID."""
    conn = _get_db()
    try:
        cur = conn.execute(
            "INSERT INTO feedback (query, answer_preview, model, rating, comment, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (query, answer_preview[:500], model, rating, comment, time.time()),
        )
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


def get_analytics() -> dict:
    """Return feedback analytics summary."""
    conn = _get_db()
    try:
        total = conn.execute("SELECT COUNT(*) FROM feedback").fetchone()[0]
        positive = conn.execute("SELECT COUNT(*) FROM feedback WHERE rating = 1").fetchone()[0]
        negative = conn.execute("SELECT COUNT(*) FROM feedback WHERE rating = -1").fetchone()[0]
        recent = conn.execute(
            "SELECT query, answer_preview, model, rating, comment, created_at "
            "FROM feedback ORDER BY created_at DESC LIMIT 20"
        ).fetchall()

        return {
            "total": total,
            "positive": positive,
            "negative": negative,
            "ratio": round(positive / total, 2) if total > 0 else 0,
            "recent": [
                {
                    "query": r[0],
                    "answer_preview": r[1],
                    "model": r[2],
                    "rating": r[3],
                    "comment": r[4],
                    "created_at": r[5],
                }
                for r in recent
            ],
        }
    finally:
        conn.close()
