#!/usr/bin/env python3
"""Extract plain text from a PDF file for question bank preprocessing.

Usage:
  py scripts/extract_pdf_to_txt.py --pdf "题库/2.中文SAP-C02 - 含答案.pdf" --out "题库/SAP-C02 中文题库.txt"
"""

import argparse
from pathlib import Path

from pypdf import PdfReader


def extract_pdf_text(pdf_path: Path) -> str:
    reader = PdfReader(str(pdf_path))
    parts: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        text = text.replace("\r\n", "\n").replace("\r", "\n").strip()
        if text:
            parts.append(text)
    return "\n".join(parts).strip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract text from PDF into UTF-8 txt")
    parser.add_argument("--pdf", required=True, help="Input PDF path")
    parser.add_argument("--out", required=True, help="Output txt path")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    out_path = Path(args.out)

    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    text = extract_pdf_text(pdf_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text, encoding="utf-8")

    print(f"extracted_pages={len(PdfReader(str(pdf_path)).pages)}")
    print(f"output={out_path}")


if __name__ == "__main__":
    main()
