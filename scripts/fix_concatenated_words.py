#!/usr/bin/env python3
"""
Fix concatenated English words in text files using `wordsegment`.

Usage:
  python scripts/fix_concatenated_words.py input.txt output.txt

Heuristics:
- For letter-only tokens longer than a threshold, run `wordsegment.segment`.
- Preserve punctuation and spacing as much as possible.
"""
import argparse
import re
from wordsegment import load, segment


def should_split(token, min_len=8):
    letters = re.sub(r'[^A-Za-z]', '', token)
    if len(letters) < min_len:
        return False
    # if token already contains spaces, skip
    if ' ' in token:
        return False
    # if token contains numbers, likely ids or sizes, skip
    if re.search(r'\d', token):
        return False
    return True


def split_letters_token(token):
    # extract contiguous letters
    letters = re.sub(r'[^A-Za-z]', '', token)
    if not letters:
        return token
    segs = segment(letters.lower())
    if not segs:
        return token
    joined = ' '.join(segs)
    # preserve initial capitalization if present
    if token[0].isupper():
        joined = joined.capitalize()
    # replace the letters part inside token with the spaced version
    # this preserves surrounding punctuation
    return re.sub(re.escape(letters), joined, token, count=1, flags=re.IGNORECASE)


def process_line(line, min_len=8):
    parts = re.findall(r"[A-Za-z]+|[^A-Za-z]+", line)
    out = []
    for p in parts:
        if re.fullmatch(r'[A-Za-z]+', p) and should_split(p, min_len=min_len):
            out.append(split_letters_token(p))
        else:
            out.append(p)
    return ''.join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', help='Input text file path')
    parser.add_argument('output', help='Output text file path')
    parser.add_argument('--min-len', type=int, default=8, help='Minimum token length to attempt splitting')
    args = parser.parse_args()

    load()

    # open input in binary and decode per-line with replacement to tolerate unknown encodings
    with open(args.input, 'rb') as f_in, open(args.output, 'w', encoding='utf-8') as f_out:
        for raw in f_in:
            try:
                line = raw.decode('utf-8')
            except Exception:
                line = raw.decode('utf-8', errors='replace')
            # quick heuristic: if the line contains no spaces but many letters, try to segment
            if line.strip() and (line.count(' ') == 0 and len(re.sub(r'[^A-Za-z]', '', line)) > args.min_len):
                fixed = process_line(line, min_len=args.min_len)
            else:
                # split tokens within the line where applicable
                fixed = process_line(line, min_len=args.min_len)
            f_out.write(fixed)


if __name__ == '__main__':
    main()
