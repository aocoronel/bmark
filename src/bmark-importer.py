#!/usr/bin/env python3

import sys
import os
import re
import sqlite3
import time
import html
from pathlib import Path


class Bookmark:
    __slots__ = ("uri", "title", "created_at", "updated_at", "tags", "note")

    def __init__(self, uri, title, created_at, updated_at, tags, note):
        self.uri = uri
        self.title = title
        self.created_at = created_at
        self.updated_at = updated_at
        self.tags = tags
        self.note = note


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  bmark-importer import <bookmark.html>")
        print("  bmark-importer export [output.html]")
        sys.exit(1)

    mode = sys.argv[1]
    db_file = Path.home() / ".local" / "share" / "bookmarks" / "bookmark.db"
    db_file.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(db_file), timeout=5)
    conn.execute("PRAGMA journal_mode=WAL")

    try:
        initialize_database(conn)

        if mode == "import":
            if len(sys.argv) < 3:
                print("Usage: importer-exporter import <bookmark.html>")
                sys.exit(1)
            import_bookmarks(conn, sys.argv[2])
        elif mode == "export":
            output_file = sys.argv[2] if len(sys.argv) >= 3 else "exported_bookmarks.html"
            export_bookmarks(conn, output_file)
        else:
            print("Invalid mode. Use 'import' or 'export'.")
            sys.exit(1)
    finally:
        conn.close()


RE_ANCHOR = re.compile(r'<A\s+([^>]+)>(.*?)</A>', re.IGNORECASE)
RE_HREF = re.compile(r'HREF="([^"]+)"')
RE_ADD_DATE = re.compile(r'ADD_DATE="(\d+)"')
RE_LAST_MOD = re.compile(r'LAST_MODIFIED="(\d+)"')
RE_TAGS = re.compile(r'TAGS="([^"]+)"')
RE_DESC = re.compile(r'<DD>([^<]+)', re.IGNORECASE)


def import_bookmarks(conn, bookmarks_file):
    with open(bookmarks_file, "r", encoding="utf-8") as f:
        content = f.read()

    blocks = content.split("<DT>")
    now = int(time.time())
    success_count = 0

    for block in blocks:
        block = block.strip()
        if not block:
            continue

        anchor_match = RE_ANCHOR.search(block)
        if not anchor_match or anchor_match.lastindex < 2:
            continue

        attr_str = anchor_match.group(1)
        title = html.unescape(anchor_match.group(2).strip())

        uri = _extract_group(RE_HREF, attr_str)
        if not uri:
            continue

        created_at = _extract_timestamp(RE_ADD_DATE, attr_str, now)
        updated_at = _extract_timestamp(RE_LAST_MOD, attr_str, created_at)
        tags = _extract_tags(RE_TAGS, attr_str)
        note = _extract_description(RE_DESC, block)

        try:
            bookmark_id = insert_bookmark(conn, uri, title, note, created_at, updated_at)
            insert_tags(conn, bookmark_id, tags)
            conn.commit()
            success_count += 1
        except Exception as e:
            conn.rollback()
            print(f"Error: failed to insert bookmark {uri}: {e}", file=sys.stderr)

    print(f"{success_count} bookmarks successfully imported!")


def _extract_group(pattern, text):
    m = pattern.search(text)
    return m.group(1) if m else ""


def _extract_timestamp(pattern, text, default_value):
    m = pattern.search(text)
    if m:
        try:
            return int(m.group(1))
        except ValueError:
            pass
    return default_value


def _extract_tags(pattern, text):
    m = pattern.search(text)
    if not m or not m.group(1):
        return []
    return [t.strip() for t in m.group(1).split(",") if t.strip()]


def _extract_description(pattern, block):
    m = pattern.search(block)
    if m:
        return html.unescape(m.group(1).strip())
    return ""


def insert_bookmark(conn, uri, title, note, created_at, updated_at):
    cur = conn.execute(
        "INSERT OR IGNORE INTO bookmarks (url, title, note, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
        (uri, title, note, created_at, updated_at),
    )
    if cur.rowcount > 0:
        return cur.lastrowid
    return conn.execute("SELECT id FROM bookmarks WHERE url = ?", (uri,)).fetchone()[0]


def insert_tags(conn, bookmark_id, tags):
    for tag in tags:
        if not tag:
            continue
        row = conn.execute("SELECT id FROM tags WHERE tag = ?", (tag,)).fetchone()
        if row is None:
            cur = conn.execute("INSERT OR IGNORE INTO tags (tag) VALUES (?)", (tag,))
            tag_id = cur.lastrowid
            if tag_id == 0:
                tag_id = conn.execute("SELECT id FROM tags WHERE tag = ?", (tag,)).fetchone()[0]
        else:
            tag_id = row[0]
        conn.execute(
            "INSERT OR IGNORE INTO bookmark_tags (bookmark_id, tag_id) VALUES (?, ?)",
            (bookmark_id, tag_id),
        )


def export_bookmarks(conn, output_file):
    rows = conn.execute("""
        SELECT b.url, b.title, b.created_at, b.updated_at, b.note,
               GROUP_CONCAT(t.tag, ',') as tags
        FROM bookmarks b
        LEFT JOIN bookmark_tags bt ON b.id = bt.bookmark_id
        LEFT JOIN tags t ON bt.tag_id = t.id
        GROUP BY b.id
    """)

    with open(output_file, "w", encoding="utf-8") as f:
        f.write('<!DOCTYPE NETSCAPE-Bookmark-file-1>\n')
        f.write('\n')
        f.write('<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">\n')
        f.write('<TITLE>Bookmarks</TITLE>\n')
        f.write('<H1>Bookmarks</H1>\n')
        f.write('<DL><p>\n')

        bookmark_count = 0
        for row in rows:
            uri, title, created_at, updated_at, note, tags = row
            title_esc = html.escape(title or "")
            note_esc = html.escape(note or "")
            uri_esc = html.escape(uri or "")
            tags_esc = html.escape(tags) if tags else ""

            attr = f'HREF="{uri_esc}" ADD_DATE="{created_at}" LAST_MODIFIED="{updated_at}"'
            if tags_esc:
                attr += f' TAGS="{tags_esc}"'

            f.write(f'<DT><A {attr}>{title_esc}</A>')
            if note_esc:
                f.write(f'<DD>{note_esc}')
            f.write("\n")
            bookmark_count += 1

        f.write('</DL><p>\n')

    if bookmark_count == 0:
        print("No bookmarks found in database.")
    else:
        print(f"Exported {bookmark_count} bookmarks to: {output_file}")


def initialize_database(conn):
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY NOT NULL,
            url TEXT NOT NULL UNIQUE,
            title TEXT,
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY NOT NULL,
            tag TEXT NOT NULL UNIQUE
        );
        CREATE TABLE IF NOT EXISTS bookmark_tags (
            bookmark_id INTEGER,
            tag_id INTEGER,
            PRIMARY KEY (bookmark_id, tag_id),
            FOREIGN KEY (bookmark_id) REFERENCES bookmarks(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        );
    """)
    conn.executescript("""
        CREATE INDEX IF NOT EXISTS idx_url ON bookmarks (url);
        CREATE INDEX IF NOT EXISTS idx_tag ON tags (tag);
        CREATE INDEX IF NOT EXISTS idx_bookmark_id ON bookmark_tags (bookmark_id);
        CREATE INDEX IF NOT EXISTS idx_tag_id ON bookmark_tags (tag_id);
    """)


main()
