import sqlite3
import os

BMARK_DB_DIR = os.getenv("BMARK_DB_DIR")
BMARK_FILE = os.getenv("BMARK_FILE")

if BMARK_DB_DIR is None:
    if BMARK_FILE is None:
        DATABASE_PATH = "~/.local/share/bookmarks/bookmark.db"
    else:
        DATABASE_PATH = f"~/.local/share/bookmarks/{BMARK_FILE}"
else:
    if BMARK_FILE is None:
        DATABASE_PATH = f"{BMARK_DB_DIR}/bookmark.db"
    else:
        DATABASE_PATH = f"{BMARK_DB_DIR}/{BMARK_FILE}"

DATABASE_PATH = os.path.expanduser(os.path.expandvars(DATABASE_PATH))

conn = sqlite3.connect(DATABASE_PATH)
cur = conn.cursor()

with open('staged.txt', 'r') as f:
    for line in f:
        parts = line.strip().split('|')
        if len(parts) < 5:
            continue
        id_, url, tags, title, note = parts
        id_ = int(id_)

        cur.execute("""
            UPDATE bookmarks
            SET url = ?, title = ?, note = ?, updated_at = strftime('%s','now')
            WHERE id = ?
        """, (url, title, note, id_))

        for tag in tags.split(','):
            tag = tag.strip()
            if not tag:
                continue
            cur.execute("INSERT OR IGNORE INTO tags (tag) VALUES (?)", (tag,))
            cur.execute("SELECT id FROM tags WHERE tag = ?", (tag,))
            tag_id = cur.fetchone()[0]
            cur.execute("INSERT OR IGNORE INTO bookmark_tags (bookmark_id, tag_id) VALUES (?, ?)", (id_, tag_id))

conn.commit()
conn.close()
