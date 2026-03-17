#!/usr/bin/env python3
"""
news_pipeline.py — Miniflux → pgvector embedding pipeline.

Called by the News agent's OpenClaw cron job every 15 minutes via the /hooks/agent webhook.
The agent receives the message, then executes:
  exec: python3 /home/clawuser/personal-os/scripts/news_pipeline.py

Setup (one-time):
    pip3 install model2vec psycopg2-binary requests python-dotenv
"""

import os, sys, requests, psycopg2
from datetime import datetime, timezone
from pathlib import Path
from dotenv import load_dotenv

MEMORY_DIR = Path(__file__).parent.parent / 'agents' / 'news' / 'memory'


def log_error(msg):
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    with open(MEMORY_DIR / 'pipeline-errors.md', 'a') as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

MINIFLUX_URL = os.getenv('MINIFLUX_URL', 'http://localhost:8080')
MINIFLUX_API_KEY = os.getenv('MINIFLUX_API_KEY')
DATABASE_URL = os.getenv('MINIFLUX_DATABASE_URL')


def get_new_entries(after_id=0):
    r = requests.get(
        f'{MINIFLUX_URL}/v1/entries',
        headers={'X-Auth-Token': MINIFLUX_API_KEY},
        params={'status': 'unread', 'limit': 100,
                'after_entry_id': after_id, 'direction': 'asc'},
        timeout=10
    )
    r.raise_for_status()
    return r.json().get('entries', [])


def get_last_id(conn):
    with conn.cursor() as cur:
        cur.execute("SELECT COALESCE(MAX(miniflux_entry_id), 0) FROM article_embeddings")
        return cur.fetchone()[0]


def embed(texts):
    from model2vec import StaticModel
    model = StaticModel.from_pretrained("minishlab/potion-base-8M")
    return model.encode(texts, show_progress_bar=False).tolist()


def store(conn, entries, embeddings):
    with conn.cursor() as cur:
        for e, emb in zip(entries, embeddings):
            cur.execute("""
                INSERT INTO article_embeddings
                  (miniflux_entry_id, feed_title, article_title, article_url,
                   published_at, summary, embedding)
                VALUES (%s,%s,%s,%s,%s,%s,%s::vector)
                ON CONFLICT (miniflux_entry_id) DO NOTHING
            """, (e['id'], e.get('feed',{}).get('title',''), e.get('title',''),
                  e.get('url',''), e.get('published_at'),
                  e.get('content','')[:500], str(emb)))
    conn.commit()


def main():
    if not MINIFLUX_API_KEY or not DATABASE_URL:
        msg = "ERROR: MINIFLUX_API_KEY or MINIFLUX_DATABASE_URL not set"
        print(msg, file=sys.stderr)
        log_error(msg)
        sys.exit(1)

    try:
        conn = psycopg2.connect(DATABASE_URL)
    except Exception as e:
        msg = f"DB connection failed: {e}"
        print(msg, file=sys.stderr)
        log_error(msg)
        sys.exit(1)

    try:
        last_id = get_last_id(conn)
        entries = get_new_entries(after_id=last_id)
        if not entries:
            print(f"[{datetime.now(timezone.utc).isoformat()}] No new entries.")
            return
        print(f"Processing {len(entries)} entries...")
        embeddings = embed([e.get('title','') for e in entries])
        store(conn, entries, embeddings)
        print(f"Stored. Highest ID: {entries[-1]['id']}")
    except Exception as e:
        msg = f"Pipeline error: {e}"
        print(msg, file=sys.stderr)
        log_error(msg)
        sys.exit(1)
    finally:
        conn.close()


if __name__ == '__main__':
    main()
