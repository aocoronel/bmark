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
cur.execute("PRAGMA foreign_keys = ON")

seen_urls = set()

with open('staged.txt', 'r') as f:
    for line in f:
        parts = line.strip().split('│')
        if len(parts) < 4:
            continue
        url, tags, title, note = parts
        seen_urls.add(url)

        cur.execute("""
            INSERT INTO bookmarks (url, title, note, created_at, updated_at)
            VALUES (?, ?, ?, strftime('%s','now'), strftime('%s','now'))
            ON CONFLICT(url) DO UPDATE SET
                title = excluded.title,
                note = excluded.note,
                updated_at = strftime('%s','now')
        """, (url, title, note))

        bookmark_id = cur.execute("SELECT id FROM bookmarks WHERE url = ?", (url,)).fetchone()[0]

        cur.execute("DELETE FROM bookmark_tags WHERE bookmark_id = ?", (bookmark_id,))

        for tag in tags.split(','):
            tag = tag.strip()
            if not tag:
                continue
            cur.execute("INSERT OR IGNORE INTO tags (tag) VALUES (?)", (tag,))
            tag_id = cur.execute("SELECT id FROM tags WHERE tag = ?", (tag,)).fetchone()[0]
            cur.execute("INSERT INTO bookmark_tags (bookmark_id, tag_id) VALUES (?, ?)", (bookmark_id, tag_id))

cur.execute("""
    DELETE FROM bookmarks WHERE url NOT IN ({})
""".format(','.join('?' * len(seen_urls))), tuple(seen_urls))

cur.execute("DELETE FROM tags WHERE id NOT IN (SELECT DISTINCT tag_id FROM bookmark_tags)")
cur.execute("DELETE FROM bookmark_tags WHERE bookmark_id NOT IN (SELECT id FROM bookmarks)")

conn.commit()
print(f"Synced {len(seen_urls)} bookmarks")
conn.close()
