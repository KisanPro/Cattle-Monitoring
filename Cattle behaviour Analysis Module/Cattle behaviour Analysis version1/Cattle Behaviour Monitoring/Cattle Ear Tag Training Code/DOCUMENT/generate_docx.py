"""
Automated Word (.docx) Document Compiler for Technical Documentation.
Compiles:
1. 01_CONSOLIDATED_SYSTEM_DESIGN_DOCUMENT.md -> 01_CONSOLIDATED_SYSTEM_DESIGN_DOCUMENT.docx
2. 02_USER_MANUAL_AND_REIMPLEMENTATION_GUIDE.md -> 02_USER_MANUAL_AND_REIMPLEMENTATION_GUIDE.docx
"""

import base64
import os
import re
import sys
from pathlib import Path
import urllib.request
import ssl

# Fix Windows console encoding for print output
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import docx
    from docx import Document
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn, nsdecls
    from docx.oxml import parse_xml
except ImportError:
    print("[*] Installing python-docx...")
    os.system(f"{sys.executable} -m pip install python-docx")
    import docx
    from docx import Document
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    from docx.enum.table import WD_TABLE_ALIGNMENT
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn, nsdecls
    from docx.oxml import parse_xml


def create_element(name):
    return OxmlElement(name)


def add_page_number(run):
    """Adds dynamic page number to footer."""
    fldSimple = create_element('w:fldSimple')
    fldSimple.set(qn('w:instr'), 'PAGE')
    run._r.append(fldSimple)


def add_total_pages(run):
    """Adds total page number to footer."""
    fldSimple = create_element('w:fldSimple')
    fldSimple.set(qn('w:instr'), 'NUMPAGES')
    run._r.append(fldSimple)


def set_cell_background(cell, fill_hex):
    """Sets background color of a table cell."""
    tcPr = cell._tc.get_or_add_tcPr()
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{fill_hex}"/>')
    tcPr.append(shd)


def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Sets cell padding."""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)


def fetch_mermaid_image(mermaid_code: str, output_path: Path) -> bool:
    """Fetches high-res PNG image from mermaid.ink."""
    try:
        cleaned_code = mermaid_code.strip()
        encoded = base64.b64encode(cleaned_code.encode("utf-8")).decode("ascii")
        url = f"https://mermaid.ink/img/{encoded}"

        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

        with urllib.request.urlopen(req, timeout=15, context=ctx) as response, open(output_path, "wb") as out_file:
            out_file.write(response.read())

        return True
    except Exception as e:
        print(f"   [!] Failed to render Mermaid diagram via API: {e}")
        return False


def get_safe_output_path(base_path: Path) -> Path:
    """Handles Word file-lock by appending version counter."""
    if not base_path.exists():
        return base_path

    try:
        with open(base_path, "a+"):
            pass
        return base_path
    except IOError:
        parent = base_path.parent
        stem = base_path.stem
        ext = base_path.suffix
        counter = 2
        while True:
            new_path = parent / f"{stem}_v{counter}{ext}"
            try:
                if not new_path.exists():
                    return new_path
                with open(new_path, "a+"):
                    pass
                return new_path
            except IOError:
                counter += 1


def clean_md_text(text: str) -> str:
    """Strips markdown bold, italics, math delimiters, and backticks."""
    text = re.sub(r"\*\*(.*?)\*\*", r"\1", text)
    text = re.sub(r"\*(.*?)\*", r"\1", text)
    text = re.sub(r"`(.*?)`", r"\1", text)
    text = re.sub(r"\$(.*?)\$", r"\1", text)
    return text.strip()


def compile_docx(markdown_path: Path, output_docx_path: Path):
    print(f"\n=======================================================")
    print(f"[*] Compiling: {markdown_path.name}")
    print(f"=======================================================")

    with open(markdown_path, "r", encoding="utf-8") as f:
        content = f.read()

    doc = Document()

    # Configure Standard Margins (1 inch)
    for section in doc.sections:
        section.top_margin = Inches(1.0)
        section.bottom_margin = Inches(1.0)
        section.left_margin = Inches(1.0)
        section.right_margin = Inches(1.0)
        
        # Configure Footer Page Numbering
        footer = section.footer
        footer_p = footer.paragraphs[0]
        footer_p.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        footer_run = footer_p.add_run("Page ")
        footer_run.font.name = "Calibri"
        footer_run.font.size = Pt(9)
        footer_run.font.color.rgb = RGBColor(128, 128, 128)
        add_page_number(footer_p.add_run())
        footer_p.add_run(" of ")
        add_total_pages(footer_p.add_run())

    lines = content.splitlines()
    i = 0
    total_lines = len(lines)
    diagram_count = 0
    img_dir = markdown_path.parent / "temp_diagrams"
    img_dir.mkdir(parents=True, exist_ok=True)

    while i < total_lines:
        line = lines[i].rstrip()

        # Handle Level 1 Heading (Chapter)
        if line.startswith("# "):
            if i > 5:
                doc.add_page_break()
            title_text = line[2:].strip()
            p = doc.add_paragraph()
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            run = p.add_run(clean_md_text(title_text))
            run.font.name = "Calibri"
            run.font.size = Pt(20)
            run.font.bold = True
            run.font.color.rgb = RGBColor(27, 54, 93)  # Corporate Dark Blue
            p.paragraph_format.space_before = Pt(12)
            p.paragraph_format.space_after = Pt(10)
            i += 1
            continue

        # Handle Level 2 Heading
        if line.startswith("## "):
            title_text = line[3:].strip()
            p = doc.add_paragraph()
            run = p.add_run(clean_md_text(title_text))
            run.font.name = "Calibri"
            run.font.size = Pt(15)
            run.font.bold = True
            run.font.color.rgb = RGBColor(41, 128, 185)  # Medium Blue
            p.paragraph_format.space_before = Pt(12)
            p.paragraph_format.space_after = Pt(6)
            i += 1
            continue

        # Handle Level 3 Heading
        if line.startswith("### "):
            title_text = line[4:].strip()
            p = doc.add_paragraph()
            run = p.add_run(clean_md_text(title_text))
            run.font.name = "Calibri"
            run.font.size = Pt(12.5)
            run.font.bold = True
            run.font.color.rgb = RGBColor(51, 51, 51)
            p.paragraph_format.space_before = Pt(8)
            p.paragraph_format.space_after = Pt(4)
            i += 1
            continue

        # Handle Mermaid Code Blocks
        if line.startswith("```mermaid"):
            mermaid_lines = []
            i += 1
            while i < total_lines and not lines[i].startswith("```"):
                mermaid_lines.append(lines[i])
                i += 1
            i += 1  # Skip closing ```

            mermaid_code = "\n".join(mermaid_lines)
            diagram_count += 1
            img_path = img_dir / f"{markdown_path.stem}_diag_{diagram_count}.png"

            print(f"   [+] Rendering Mermaid Diagram #{diagram_count}...")
            if fetch_mermaid_image(mermaid_code, img_path):
                if "graph TD" in mermaid_code or "flowchart TD" in mermaid_code:
                    width = Inches(3.6)
                elif "sequenceDiagram" in mermaid_code:
                    width = Inches(4.6)
                elif "classDiagram" in mermaid_code:
                    width = Inches(4.8)
                else:
                    width = Inches(5.2)

                p = doc.add_paragraph()
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
                p.paragraph_format.space_before = Pt(8)
                p.paragraph_format.space_after = Pt(8)
                run = p.add_run()
                run.add_picture(str(img_path), width=width)
            continue

        # Handle Regular Code Blocks or ASCII Tables
        if line.startswith("```"):
            code_lines = []
            i += 1
            while i < total_lines and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            i += 1

            code_text = "\n".join(code_lines)
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(6)
            p.paragraph_format.space_after = Pt(6)
            run = p.add_run(code_text)
            run.font.name = "Courier New"
            run.font.size = Pt(8.5)
            run.font.color.rgb = RGBColor(40, 40, 40)
            continue

        # Handle Markdown Tables (| Header | Header |)
        if line.startswith("|") and line.endswith("|"):
            table_lines = []
            while i < total_lines and lines[i].startswith("|") and lines[i].endswith("|"):
                table_lines.append(lines[i])
                i += 1

            if len(table_lines) >= 2:
                rows_data = []
                for tline in table_lines:
                    if re.match(r"^\|(\s*:?-+:?\s*\|)+$", tline.strip()):
                        continue
                    cells = [c.strip() for c in tline.strip().strip("|").split("|")]
                    rows_data.append(cells)

                if rows_data:
                    num_rows = len(rows_data)
                    num_cols = max(len(r) for r in rows_data)
                    table = doc.add_table(rows=num_rows, cols=num_cols)
                    table.alignment = WD_TABLE_ALIGNMENT.CENTER
                    table.autofit = True

                    for r_idx, row in enumerate(rows_data):
                        for c_idx, cell_value in enumerate(row):
                            if c_idx < num_cols:
                                cell = table.cell(r_idx, c_idx)
                                cell.text = clean_md_text(cell_value)
                                set_cell_margins(cell, 80, 80, 120, 120)
                                p = cell.paragraphs[0]
                                p.paragraph_format.space_before = Pt(2)
                                p.paragraph_format.space_after = Pt(2)

                                if r_idx == 0:
                                    set_cell_background(cell, "1B365D")
                                    for crun in p.runs:
                                        crun.font.name = "Calibri"
                                        crun.font.bold = True
                                        crun.font.size = Pt(9.5)
                                        crun.font.color.rgb = RGBColor(255, 255, 255)
                                else:
                                    bg_color = "F9FAFB" if r_idx % 2 == 1 else "FFFFFF"
                                    set_cell_background(cell, bg_color)
                                    for crun in p.runs:
                                        crun.font.name = "Calibri"
                                        crun.font.size = Pt(9)
                                        crun.font.color.rgb = RGBColor(50, 50, 50)
            continue

        # Handle Bullet Points
        if line.startswith("- ") or line.startswith("* "):
            p = doc.add_paragraph(style='List Bullet')
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            run = p.add_run(clean_md_text(line[2:].strip()))
            run.font.name = "Calibri"
            run.font.size = Pt(10.5)
            i += 1
            continue

        # Handle Numbered Lists
        if re.match(r"^\d+\.\s+", line):
            p = doc.add_paragraph(style='List Number')
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after = Pt(2)
            text = re.sub(r"^\d+\.\s+", "", line)
            run = p.add_run(clean_md_text(text))
            run.font.name = "Calibri"
            run.font.size = Pt(10.5)
            i += 1
            continue

        # Handle Plain Paragraphs
        if line.strip():
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after = Pt(4)
            run = p.add_run(clean_md_text(line))
            run.font.name = "Calibri"
            run.font.size = Pt(10.5)
            run.font.color.rgb = RGBColor(40, 40, 40)

        i += 1

    safe_output_path = get_safe_output_path(output_docx_path)
    doc.save(str(safe_output_path))
    print(f"[+] Successfully compiled Word document to: {safe_output_path.name}")


if __name__ == "__main__":
    current_dir = Path(__file__).resolve().parent
    md_files = [
        current_dir / "01_CONSOLIDATED_SYSTEM_DESIGN_DOCUMENT.md",
        current_dir / "02_USER_MANUAL_AND_REIMPLEMENTATION_GUIDE.md"
    ]

    for md_file in md_files:
        if md_file.exists():
            docx_output = current_dir / f"{md_file.stem}.docx"
            compile_docx(md_file, docx_output)
