#!/usr/bin/env python3
"""Helper utilities for podcast-downloader.sh

Usage:
  podcast_helper.py daterange
  podcast_helper.py list_episodes <feed_file> <after YYYY-MM-DD> <before YYYY-MM-DD>

Outputs:
  - daterange: prints "<after> <before>" (YYYY-MM-DD)
  - list_episodes: prints one JSON object per matching episode to stdout
"""
import sys
from datetime import datetime, timedelta
import json
from xml.etree import ElementTree as ET
from email.utils import parsedate_to_datetime


def daterange():
    today = datetime.now().date()
    before = today + timedelta(days=1)
    after = today - timedelta(days=8)
    print(after.strftime('%Y-%m-%d'), before.strftime('%Y-%m-%d'))


def first_text(elem, tag):
    if elem is None:
        return None
    t = elem.find(tag)
    if t is not None and t.text:
        return t.text.strip()
    return None


def list_episodes(feed_path, after_s, before_s):
    after = datetime.strptime(after_s, '%Y-%m-%d').date()
    before = datetime.strptime(before_s, '%Y-%m-%d').date()
    tree = ET.parse(feed_path)
    root = tree.getroot()
    for item in root.findall('.//item'):
        pub = first_text(item, 'pubDate')
        if not pub:
            continue
        try:
            dt = parsedate_to_datetime(pub)
        except Exception:
            continue
        d = dt.date()
        if d < after or d > before:
            continue

        title = first_text(item, 'title') or ''
        link = first_text(item, 'link') or ''
        enclosure = None
        enc = item.find('enclosure')
        if enc is not None and 'url' in enc.attrib:
            enclosure = enc.attrib.get('url')
        image = None
        for child in item:
            tag = child.tag.lower()
            if 'image' in tag and ('href' in child.attrib):
                image = child.attrib.get('href')

        out = {'title': title, 'link': link, 'pubDate': pub, 'enclosure': enclosure, 'image': image}
        print(json.dumps(out))


def daterange_mmdd():
    today = datetime.now().date()
    before = today + timedelta(days=1)
    after = today - timedelta(days=8)
    print(after.strftime('%m/%d/%Y'), before.strftime('%m/%d/%Y'))


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == 'daterange':
        daterange()
    elif cmd == 'daterange_mmdd':
        daterange_mmdd()
    elif cmd == 'list_episodes':
        if len(sys.argv) != 5:
            print('Usage: list_episodes <feed_file> <after> <before>')
            sys.exit(2)
        list_episodes(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print('Unknown command:', cmd)
        sys.exit(3)


if __name__ == '__main__':
    main()
