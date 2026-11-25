#!/usr/bin/env python3
"""Generate HTML, PDF and DOCX versions of docs/manual.md.

Usage:
    python scripts/build_manual.py

Requirements:
    - Python 3.10+
    - python-docx (only for the DOCX output): pip install python-docx
    - Google Chrome or Microsoft Edge (only for the PDF output)

The Markdown file is the single source of truth; the generated files are
derived artifacts and can be regenerated at any time with this script.
"""

from __future__ import annotations

import html
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "manual.md"
HTML_OUT = ROOT / "docs" / "manual.html"
PDF_OUT = ROOT / "docs" / "manual.pdf"
DOCX_OUT = ROOT / "docs" / "manual.docx"

BROWSER_CANDIDATES = [
    os.environ.get("CHROME_PATH", ""),
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
]


# ---------------------------------------------------------------------------
# Markdown -> HTML (small subset tailored to docs/manual.md)
# ---------------------------------------------------------------------------

def inline(text: str) -> str:
    """Render inline Markdown (code, bold, italic, links) to HTML."""
    escaped = html.escape(text, quote=False)
    codes: list[str] = []

    def stash(match: re.Match[str]) -> str:
        codes.append(match.group(1))
        return f"\x00CODE{len(codes) - 1}\x00"

    escaped = re.sub(r"`([^`]+)`", stash, escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    escaped = re.sub(r"(?<!\S)\*([^*]+)\*(?!\S)", r"<em>\1</em>", escaped)
    escaped = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        r'<a href="\2">\1</a>',
        escaped,
    )
    for index, code in enumerate(codes):
        escaped = escaped.replace(
            f"\x00CODE{index}\x00", f"<code>{html.escape(code)}</code>"
        )
    return escaped


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator(line: str) -> bool:
    return bool(re.fullmatch(r"\s*\|(?:\s*:?-{3,}:?\s*\|)+\s*", line))


def markdown_to_html(md: str) -> str:
    lines = md.splitlines()
    out: list[str] = []
    i = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # Fenced code block
        if stripped.startswith("```"):
            language = stripped[3:].strip()
            i += 1
            block: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                block.append(lines[i])
                i += 1
            i += 1
            css_class = f' class="language-{html.escape(language)}"' if language else ""
            out.append(
                f"<pre><code{css_class}>{html.escape(chr(10).join(block))}</code></pre>"
            )
            continue

        # ATX heading
        heading = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if heading:
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
            i += 1
            continue

        # Horizontal rule
        if re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", stripped):
            out.append("<hr>")
            i += 1
            continue

        # Table
        if stripped.startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1]):
            header = split_table_row(stripped)
            i += 2
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            out.append("<table>")
            out.append("<thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in header) + "</tr></thead>")
            out.append("<tbody>")
            for row in rows:
                out.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>")
            out.append("</tbody></table>")
            continue

        # Blockquote
        if stripped.startswith(">"):
            quote: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip().lstrip(">").strip())
                i += 1
            out.append(f"<blockquote>{inline(' '.join(quote))}</blockquote>")
            continue

        # Lists (with one nesting level)
        list_match = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if list_match:
            items: list[tuple[int, str, str]] = []
            while i < len(lines):
                m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if not m:
                    if lines[i].strip() == "" and i + 1 < len(lines) and re.match(
                        r"^\s+([-*]|\d+\.)\s+", lines[i + 1]
                    ):
                        i += 1
                        continue
                    break
                items.append((len(m.group(1)), m.group(2), m.group(3)))
                i += 1

            out.append("<ul>")
            depth = 0
            for indent, marker, text in items:
                level = 1 if indent >= 2 else 0
                ordered = marker.endswith(".")
                if level != depth:
                    if level > depth:
                        out.append("<ul>" if not ordered else "<ol>")
                    else:
                        out.append("</ul>" if not ordered else "</ol>")
                    depth = level
                out.append(f"<li>{inline(text)}</li>")
            while depth >= 0:
                out.append("</ul>")
                depth -= 1
            continue

        # Paragraph: join consecutive plain lines
        paragraph: list[str] = []
        while i < len(lines):
            candidate = lines[i].strip()
            if not candidate:
                break
            if (
                candidate.startswith("```")
                or candidate.startswith("|")
                or candidate.startswith(">")
                or re.match(r"^#{1,6}\s", candidate)
                or re.match(r"^(\s*)([-*]|\d+\.)\s+", lines[i])
                or re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", candidate)
            ):
                break
            paragraph.append(candidate)
            i += 1
        if paragraph:
            out.append(f"<p>{inline(' '.join(paragraph))}</p>")

    css = """
    @page { size: A4; margin: 18mm 16mm 18mm 16mm; }
    * { box-sizing: border-box; }
    body {
      font-family: "Segoe UI", "Calibri", Arial, sans-serif;
      color: #1f2933; font-size: 10.5pt; line-height: 1.45; margin: 0;
    }
    h1 { font-size: 22pt; color: #0b4f6c; margin: 0 0 6pt; }
    h2 { font-size: 16pt; color: #0b4f6c; margin: 20pt 0 8pt;
         border-bottom: 2px solid #d6e6ee; padding-bottom: 4pt;
         page-break-after: avoid; }
    h3 { font-size: 12.5pt; color: #14506b; margin: 14pt 0 6pt;
         page-break-after: avoid; }
    h4 { font-size: 11pt; color: #14506b; margin: 10pt 0 4pt;
         page-break-after: avoid; }
    p { margin: 5pt 0; orphans: 2; widows: 2; }
    ul, ol { margin: 5pt 0 5pt 18pt; padding-left: 8pt; }
    li { margin: 2pt 0; }
    table { border-collapse: collapse; width: 100%; margin: 8pt 0;
            font-size: 9.2pt; page-break-inside: avoid; }
    th { background: #0b4f6c; color: white; text-align: left;
         padding: 5pt 6pt; border: 1px solid #0b4f6c; }
    td { padding: 4pt 6pt; border: 1px solid #c8d6de; vertical-align: top; }
    tr:nth-child(even) td { background: #f2f7fa; }
    pre { background: #f3f5f7; border: 1px solid #d7dee3; border-left: 3px solid #0b4f6c;
          padding: 8pt 10pt; font-size: 8.6pt; line-height: 1.3;
          white-space: pre-wrap; word-break: break-word; margin: 8pt 0;
          page-break-inside: avoid; }
    code { font-family: Consolas, "Courier New", monospace; font-size: 0.92em; }
    p code, li code, td code { background: #edf2f5; padding: 0 2pt; border-radius: 2pt; }
    blockquote { border-left: 3px solid #d99a2b; background: #fff8e8;
                 margin: 8pt 0; padding: 6pt 10pt; color: #5c4a25; }
    hr { border: none; border-top: 1px solid #d6e6ee; margin: 14pt 0; }
    a { color: #0b6a9c; text-decoration: none; }
    .cover { page-break-after: always; padding-top: 45mm; text-align: center; }
    .cover h1 { font-size: 30pt; }
    .cover .subtitle { font-size: 15pt; color: #3d6b80; margin-top: 8pt; }
    .cover .meta { font-size: 10pt; color: #64748b; margin-top: 45mm; }
    """

    body = "\n".join(out)
    # First h1 becomes a cover page.
    first_h1 = re.search(r"<h1>(.*?)</h1>", body)
    cover = ""
    if first_h1:
        title = first_h1.group(1)
        meta = (
            '<div class="meta">Proyecto ECO300 · Grupo 99<br>'
            "Documentación de usuario y desarrollador<br>"
            "Generado desde docs/manual.md</div>"
        )
        cover = f'<div class="cover"><h1>{title}</h1><div class="subtitle">Manual del Simulador Microeconómico</div>{meta}</div>'
        body = body[: first_h1.start()] + body[first_h1.end() :]

    return (
        "<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\">"
        "<title>Manual — Simulador Microeconómico ECO300</title>"
        f"<style>{css}</style></head><body>{cover}{body}</body></html>"
    )


# ---------------------------------------------------------------------------
# Markdown -> DOCX
# ---------------------------------------------------------------------------

def add_inline_docx(paragraph, text: str) -> None:
    """Add inline Markdown to a python-docx paragraph."""
    tokens = re.split(
        r"(`[^`]+`|\*\*[^*]+\*\*|(?<!\S)\*[^*]+\*(?!\S)|\[[^\]]+\]\([^)]+\))", text
    )
    for token in tokens:
        if not token:
            continue
        if token.startswith("`") and token.endswith("`"):
            run = paragraph.add_run(token[1:-1])
            run.font.name = "Consolas"
        elif token.startswith("**") and token.endswith("**"):
            run = paragraph.add_run(token[2:-2])
            run.bold = True
        elif token.startswith("*") and token.endswith("*") and len(token) > 2:
            run = paragraph.add_run(token[1:-1])
            run.italic = True
        else:
            link = re.fullmatch(r"\[([^\]]+)\]\(([^)]+)\)", token)
            if link:
                paragraph.add_run(link.group(1))
            else:
                paragraph.add_run(token)


def markdown_to_docx(md: str, destination: Path) -> None:
    from docx import Document
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.shared import Pt

    doc = Document()
    doc.core_properties.title = "Manual — Simulador Microeconómico ECO300"
    doc.core_properties.subject = "Manual de usuario y documentación técnica"
    doc.core_properties.author = "Proyecto ECO300 · Grupo 99"

    normal = doc.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(10.5)

    lines = md.splitlines()
    i = 0
    in_code = False
    code_lines: list[str] = []
    first_h1_done = False

    def flush_code() -> None:
        nonlocal code_lines
        if not code_lines:
            return
        p = doc.add_paragraph()
        p.paragraph_format.left_indent = Pt(14)
        run = p.add_run("\n".join(code_lines))
        run.font.name = "Consolas"
        run.font.size = Pt(8.5)
        code_lines = []

    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()

        if stripped.startswith("```"):
            if in_code:
                flush_code()
            in_code = not in_code
            i += 1
            continue
        if in_code:
            code_lines.append(raw)
            i += 1
            continue

        if not stripped:
            flush_code()
            i += 1
            continue

        heading = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if heading:
            flush_code()
            level = len(heading.group(1))
            text = heading.group(2)
            if level == 1 and not first_h1_done:
                first_h1_done = True
                p = doc.add_paragraph()
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                r = p.add_run(text)
                r.bold = True
                r.font.size = Pt(26)
            else:
                doc.add_heading(text, level=min(level, 4))
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and is_separator(lines[i + 1]):
            flush_code()
            header = split_table_row(stripped)
            i += 2
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_table_row(lines[i]))
                i += 1
            table = doc.add_table(rows=1, cols=len(header))
            table.style = "Table Grid"
            for cell, value in zip(table.rows[0].cells, header):
                cell.text = ""
                add_inline_docx(cell.paragraphs[0], value)
                for run in cell.paragraphs[0].runs:
                    run.bold = True
            for row in rows:
                cells = table.add_row().cells
                for cell, value in zip(cells, row):
                    cell.text = ""
                    add_inline_docx(cell.paragraphs[0], value)
            i += 1
            continue

        if stripped.startswith(">"):
            flush_code()
            quote: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip().lstrip(">").strip())
                i += 1
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Pt(18)
            add_inline_docx(p, " ".join(quote))
            for run in p.runs:
                run.italic = True
            continue

        list_match = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", raw)
        if list_match:
            flush_code()
            style = "List Number" if list_match.group(2).endswith(".") else "List Bullet"
            p = doc.add_paragraph(style=style)
            if len(list_match.group(1)) >= 2:
                p.paragraph_format.left_indent = Pt(36)
            add_inline_docx(p, list_match.group(3))
            i += 1
            continue

        if re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", stripped):
            flush_code()
            doc.add_paragraph("─" * 40)
            i += 1
            continue

        flush_code()
        paragraph: list[str] = []
        while i < len(lines):
            candidate = lines[i].strip()
            if (
                not candidate
                or candidate.startswith("```")
                or candidate.startswith("|")
                or candidate.startswith(">")
                or re.match(r"^#{1,6}\s", candidate)
                or re.match(r"^(\s*)([-*]|\d+\.)\s+", lines[i])
                or re.fullmatch(r"(-{3,}|\*{3,}|_{3,})", candidate)
            ):
                break
            paragraph.append(candidate)
            i += 1
        if paragraph:
            add_inline_docx(doc.add_paragraph(), " ".join(paragraph))

    flush_code()
    doc.save(destination)


def find_browser() -> str | None:
    for candidate in BROWSER_CANDIDATES:
        if candidate and Path(candidate).is_file():
            return candidate
    return shutil.which("chrome") or shutil.which("msedge") or shutil.which("chromium")


def main() -> int:
    if not SOURCE.is_file():
        print(f"ERROR: no existe {SOURCE}")
        return 1

    md = SOURCE.read_text(encoding="utf-8")
    HTML_OUT.write_text(markdown_to_html(md), encoding="utf-8")
    print(f"OK  {HTML_OUT.relative_to(ROOT)}")

    browser = find_browser()
    if browser:
        command = [
            browser,
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--virtual-time-budget=10000",
            f"--print-to-pdf={PDF_OUT}",
            "--no-pdf-header-footer",
            HTML_OUT.as_uri(),
        ]
        result = subprocess.run(command, capture_output=True, text=True, timeout=120)
        if result.returncode == 0 and PDF_OUT.is_file():
            print(f"OK  {PDF_OUT.relative_to(ROOT)}")
        else:
            print("ERROR al generar el PDF:", result.stderr.strip()[-800:])
    else:
        print("AVISO: no se encontró Chrome/Edge; se omite el PDF.")

    try:
        markdown_to_docx(md, DOCX_OUT)
        print(f"OK  {DOCX_OUT.relative_to(ROOT)}")
    except ImportError:
        print("AVISO: python-docx no está instalado; se omite el DOCX.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
