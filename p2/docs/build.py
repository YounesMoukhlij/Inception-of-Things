# -*- coding: utf-8 -*-
import os, sys
BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
from reportlab.pdfgen import canvas
from sketch import W, H, register_fonts
import pages_a, pages_b

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(BASE, "out.pdf")
register_fonts(BASE)

c = canvas.Canvas(OUT, pagesize=(W, H))
c.setTitle("Inception-of-Things p2 -- K3s system design")
c.setAuthor("ynassibi")
c.setSubject("How the p2 K3s cluster is built, and why")

pages = [pages_a.page1, pages_a.page2, pages_a.page3, pages_a.page4,
         pages_b.page5, pages_b.page6, pages_b.page7]
for i, fn in enumerate(pages, 1):
    fn(c, i, len(pages))
    c.showPage()
c.save()
print("wrote", OUT, os.path.getsize(OUT), "bytes")
