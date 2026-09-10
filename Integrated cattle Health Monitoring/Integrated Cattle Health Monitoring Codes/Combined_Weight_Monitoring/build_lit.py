
import os, sys, re, docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

OUT_DIR = r'C:\Users\GITAM\Downloads\Input'
DOCX_PATH = os.path.join(OUT_DIR, 'Comprehensive_Literature_Review_and_Bibliography_KisanPro.docx')
MD_PATH = os.path.join(OUT_DIR, 'LITERATURE_REVIEW_AND_BIBLIOGRAPHY.md')
os.makedirs(OUT_DIR, exist_ok=True)
