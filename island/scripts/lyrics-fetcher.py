#!/usr/bin/env python3
"""Lyrics fetcher for Cool-Shell: fetches time-synced lyrics from LRCLIB and outputs clean JSON.
Strictly filters to English, Kannada, and Hindi lyrics only.
Zero persistent footprint; runs once on track change and exits. Caches to /tmp/cool-shell-lyrics/."""

import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

CACHE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "cool-shell-lyrics")
os.makedirs(CACHE_DIR, exist_ok=True)

# Language detection regexes and dictionaries
KANNADA_RE = re.compile(r'[\u0C80-\u0CFF]')
DEVANAGARI_RE = re.compile(r'[\u0900-\u097F]')
DISALLOWED_SCRIPTS_RE = re.compile(r'[\u0400-\u04FF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF\u0600-\u06FF\u0370-\u03FF\u0E00-\u0E7F\u0B80-\u0BFF\u0C00-\u0C7F\u0D00-\u0D7F\u0980-\u09FF]')

FOREIGN_LATIN_ACCENTS = set('éèêëàâçîïôùûœñáíóú¿¡äöüßãõìòųłńśźż')

FOREIGN_STOPWORDS = {
    # French
    'le', 'la', 'les', 'des', 'du', 'une', 'dans', 'pour', 'avec', 'cest', "c'est", 'vous', 'nous', 'elle', 'elles',
    'tout', 'tous', 'pas', 'plus', 'mais', 'sur', 'comme', 'quand', 'ainsi', 'soir', 'sans', 'faire', 'mon', 'mes',
    # Spanish
    'el', 'los', 'las', 'del', 'por', 'para', 'con', 'sin', 'como', 'pero', 'que', 'mas', 'más', 'este', 'esta',
    'estos', 'estas', 'todo', 'toda', 'todos', 'todas', 'vida', 'corazon', 'corazón', 'amor', 'tiempo', 'noche', 'siempre',
    # German
    'der', 'die', 'das', 'und', 'ist', 'nicht', 'ein', 'eine', 'einer', 'mit', 'für', 'von', 'auf', 'zu', 'dass', 'sich',
    # Italian
    'perche', 'perché', 'sono', 'siamo', 'questo', 'questa', 'questi', 'queste', 'della', 'degli', 'nella'
}

ALLOWED_STOPWORDS = {
    # English
    'the', 'and', 'to', 'of', 'a', 'in', 'that', 'is', 'it', 'you', 'i', 'im', "i'm", 'my', 'me', 'he', 'she',
    'for', 'on', 'with', 'as', 'at', 'be', 'this', 'have', 'from', 'or', 'by', 'but', 'not', 'what', 'all', 'were',
    'we', 'when', 'your', 'can', 'cant', "can't", 'dont', "don't", 'wont', "won't", 'gonna', 'wanna', 'baby', 'yeah',
    'oh', 'know', 'feel', 'love', 'girl', 'boy', 'night', 'time', 'like', 'just', 'see', 'down', 'up', 'out', 'so',
    # Transliterated Hindi / Hinglish
    'dil', 'pyar', 'ishq', 'tere', 'teri', 'tera', 'meri', 'mera', 'mere', 'tum', 'hum', 'kya', 'hai', 'hain', 'ho',
    'kyun', 'saath', 'zindagi', 'jaan', 'pagal', 'main', 'mai', 'tha', 'thi', 'the', 'nahi', 'nahin', 'yeh', 'woh',
    'aaja', 'baat', 'yaara', 'rabba', 'rab', 'ankhon', 'ankhein', 'rang',
    # Transliterated Kannada / Kanglish
    'nange', 'ninge', 'naanu', 'neenu', 'alla', 'allava', 'illi', 'alli', 'hege', 'yake', 'thumba', 'chennagide',
    'olave', 'preethi', 'jeeva', 'baaro', 'baare', 'huduga', 'hudugi', 'nodu', 'manasa', 'hosa', 'mathu', 'kanasu'
}


def is_allowed_language(lyrics_text: str) -> bool:
    if not lyrics_text:
        return False
    # If Kannada script present -> Always allowed
    if KANNADA_RE.search(lyrics_text):
        return True
    # If Devanagari script present -> Always allowed
    if DEVANAGARI_RE.search(lyrics_text):
        return True
    # If other non-Latin foreign scripts present -> Disallowed
    if DISALLOWED_SCRIPTS_RE.search(lyrics_text):
        return False

    # Check for foreign European accents
    accent_count = sum(1 for ch in lyrics_text.lower() if ch in FOREIGN_LATIN_ACCENTS)
    if accent_count > 3:
        return False

    # Tokenize words for vocabulary comparison
    words = [w.lower() for w in re.findall(r"[a-zA-Z'’]+", lyrics_text)]
    if not words:
        return False

    foreign_hits = sum(1 for w in words if w in FOREIGN_STOPWORDS)
    allowed_hits = sum(1 for w in words if w in ALLOWED_STOPWORDS)

    if foreign_hits > allowed_hits and foreign_hits >= 2:
        return False

    return True


def clean_title(title: str) -> str:
    t = re.sub(r'\(.*?\)|\[.*?\]', '', title)
    t = re.sub(r'(?i)\b(feat|ft|slowed|reverb|hardtekk|official video|music video|audio|remix|edit)\b.*', '', t)
    return t.strip(' -–—: ')


def parse_lrc(lrc: str):
    lines = []
    for line in lrc.splitlines():
        m = re.match(r'\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)', line)
        if m:
            mins, secs, text = int(m.group(1)), float(m.group(2)), m.group(3).strip()
            if text:
                lines.append({'t': round(mins * 60 + secs, 2), 'text': text})
    lines.sort(key=lambda x: x['t'])
    return lines


def main():
    if len(sys.argv) < 2:
        print("[]")
        return

    raw_title = sys.argv[1].strip()
    raw_artist = sys.argv[2].strip() if len(sys.argv) > 2 else ""

    if not raw_title or raw_title == "No Media Playing":
        print("[]")
        return

    cache_key = hashlib.md5(f"{raw_title}:{raw_artist}".encode('utf-8')).hexdigest()
    cache_path = os.path.join(CACHE_DIR, f"{cache_key}.json")

    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                content = f.read()
                # Verify cached content respects language constraints
                cached_data = json.loads(content)
                combined = " ".join(item.get("text", "") for item in cached_data)
                if not combined or is_allowed_language(combined):
                    print(content)
                    return
        except Exception:
            pass

    clean_t = clean_title(raw_title)
    queries = []
    if raw_artist and raw_artist.lower() not in ("unknown", "unknown artist", "topic"):
        clean_a = re.sub(r'(?i)\b(topic|vevo)\b.*', '', raw_artist).strip(' -')
        if clean_a:
            queries.append(f"{clean_t} {clean_a}")
    queries.append(clean_t)

    result_lines = []
    for q in queries:
        if not q:
            continue
        url = f"https://lrclib.net/api/search?q={urllib.parse.quote(q)}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "CoolShell/1.0 (Linux; x86_64)"})
            with urllib.request.urlopen(req, timeout=3.5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for item in data:
                    raw_lyrics = item.get("syncedLyrics")
                    if raw_lyrics:
                        # Check language filter before adopting
                        if is_allowed_language(raw_lyrics):
                            result_lines = parse_lrc(raw_lyrics)
                            break
        except Exception:
            pass
        if result_lines:
            break

    payload = json.dumps(result_lines, ensure_ascii=False)
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            f.write(payload)
    except Exception:
        pass

    print(payload)


if __name__ == "__main__":
    main()
