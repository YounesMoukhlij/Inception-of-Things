# -*- coding: utf-8 -*-
"""Hand-drawn ('rough') drawing helpers on top of reportlab."""
import math, random
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

W, H = 842.0, 595.0            # A4 landscape

INK    = HexColor(0x1B2430)
PAPER  = HexColor(0xFDFBF4)
RED    = HexColor(0xC8394B)
BLUE   = HexColor(0x2B6CB0)
GREEN  = HexColor(0x2F855A)
AMBER  = HexColor(0xB7791F)
GREY   = HexColor(0x7A8290)
PURPLE = HexColor(0x6B46C1)
TEAL   = HexColor(0x2C7A7B)

FILL_BLUE  = HexColor(0xEAF2FB)
FILL_GREEN = HexColor(0xE8F5EE)
FILL_AMBER = HexColor(0xFDF3E0)
FILL_RED   = HexColor(0xFBEBED)
FILL_GREY  = HexColor(0xF1F2F4)
FILL_PURP  = HexColor(0xF0EAFB)

HAND = "AD"        # Architects Daughter - body
SCRIPT = "Caveat"  # Caveat - titles / margin notes


def register_fonts(base):
    pdfmetrics.registerFont(TTFont(HAND, base + "/fonts/ArchitectsDaughter.ttf"))
    pdfmetrics.registerFont(TTFont(SCRIPT, base + "/fonts/Caveat.ttf"))


def sw(txt, font, size):
    return pdfmetrics.stringWidth(txt, font, size)


# ---------------------------------------------------------------- primitives
def rough_line(c, x1, y1, x2, y2, color=INK, lw=1.2, passes=2, amp=1.3, seed=None):
    """A straight line drawn by a slightly unsteady hand."""
    if seed is None:
        seed = int(abs(x1 * 7 + y1 * 13 + x2 * 3 + y2 * 5))
    rnd = random.Random(seed)
    c.setStrokeColor(color); c.setLineWidth(lw); c.setLineCap(1); c.setLineJoin(1)
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy)
    if L < 0.5:
        return
    nx, ny = -dy / L, dx / L
    segs = max(2, int(L / 16))
    for _ in range(passes):
        p = c.beginPath()
        for i in range(segs + 1):
            t = i / segs
            a = amp * math.sin(math.pi * t)      # pinned at both ends
            j = rnd.uniform(-a, a)
            px, py = x1 + dx * t + nx * j, y1 + dy * t + ny * j
            (p.moveTo if i == 0 else p.lineTo)(px, py)
        c.drawPath(p)


def rough_rect(c, x, y, w, h, color=INK, lw=1.3, passes=2, amp=1.1, seed=7, over=2.5):
    """Four strokes that overshoot at the corners, the way people actually draw boxes."""
    rough_line(c, x - over, y, x + w + over, y, color, lw, passes, amp, seed + 1)
    rough_line(c, x + w, y - over, x + w, y + h + over, color, lw, passes, amp, seed + 2)
    rough_line(c, x + w + over, y + h, x - over, y + h, color, lw, passes, amp, seed + 3)
    rough_line(c, x, y + h + over, x, y - over, color, lw, passes, amp, seed + 4)


def rough_poly(c, cx, cy, r, n, color=INK, lw=1.2, rot=0.0, fill=None, seed=11):
    pts = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    if fill is not None:
        c.setFillColor(fill)
        p = c.beginPath(); p.moveTo(*pts[0])
        for q in pts[1:]:
            p.lineTo(*q)
        p.close(); c.drawPath(p, stroke=0, fill=1)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        rough_line(c, a[0], a[1], b[0], b[1], color, lw, 2, 0.7, seed + i)


def rough_circle(c, cx, cy, r, color=INK, lw=1.2, fill=None, seed=5):
    rough_poly(c, cx, cy, r, 20, color, lw, 0.3, fill, seed)


def rough_arrow(c, x1, y1, x2, y2, color=INK, lw=1.4, head=8.0, seed=3, amp=1.0, dash=False):
    if dash:
        c.setDash(4, 3)
    rough_line(c, x1, y1, x2, y2, color, lw, 2, amp, seed)
    if dash:
        c.setDash()
    ang = math.atan2(y2 - y1, x2 - x1)
    for s in (+1, -1):
        a = ang + s * 2.6
        rough_line(c, x2, y2, x2 + head * math.cos(a), y2 + head * math.sin(a),
                   color, lw, 2, 0.5, seed + 30 + s)


def rough_curve_arrow(c, x1, y1, x2, y2, bend=30.0, color=RED, lw=1.3, head=7.0, seed=9):
    """A curved pointer, like an arrow scribbled in a margin."""
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy) or 1
    cx, cy = mx - dy / L * bend, my + dx / L * bend
    rnd = random.Random(seed)
    c.setStrokeColor(color); c.setLineWidth(lw); c.setLineCap(1)
    for _ in range(2):
        p = c.beginPath(); p.moveTo(x1, y1)
        N = 22
        for i in range(1, N + 1):
            t = i / N
            bx = (1 - t) ** 2 * x1 + 2 * (1 - t) * t * cx + t ** 2 * x2
            by = (1 - t) ** 2 * y1 + 2 * (1 - t) * t * cy + t ** 2 * y2
            e = 1.0 * math.sin(math.pi * t)
            p.lineTo(bx + rnd.uniform(-e, e), by + rnd.uniform(-e, e))
        c.drawPath(p)
    tang = math.atan2(y2 - cy, x2 - cx)
    for s in (+1, -1):
        a = tang + s * 2.6
        rough_line(c, x2, y2, x2 + head * math.cos(a), y2 + head * math.sin(a), color, lw, 2, 0.4, seed + 40 + s)


def check(c, x, y, s=9, color=GREEN, lw=2.0, seed=61):
    rough_line(c, x, y + s * 0.35, x + s * 0.38, y, color, lw, 2, 0.5, seed)
    rough_line(c, x + s * 0.38, y, x + s, y + s, color, lw, 2, 0.5, seed + 1)


def cross(c, x, y, s=9, color=RED, lw=2.0, seed=71):
    rough_line(c, x, y, x + s, y + s, color, lw, 2, 0.5, seed)
    rough_line(c, x, y + s, x + s, y, color, lw, 2, 0.5, seed + 1)


# ------------------------------------------------------------------ text bits
def txt(c, x, y, s, font=HAND, size=10.5, color=INK):
    c.setFont(font, size); c.setFillColor(color); c.drawString(x, y, s)
    return y


def ctxt(c, cx, y, s, font=HAND, size=10.5, color=INK):
    c.setFont(font, size); c.setFillColor(color); c.drawCentredString(cx, y, s)
    return y


def wrap(c, x, y, s, width, font=HAND, size=10.5, leading=15, color=INK):
    """Naive word wrap; returns the y below the last line."""
    c.setFont(font, size); c.setFillColor(color)
    line = ""
    for word in s.split():
        trial = (line + " " + word).strip()
        if sw(trial, font, size) <= width:
            line = trial
        else:
            c.drawString(x, y, line); y -= leading; line = word
    if line:
        c.drawString(x, y, line); y -= leading
    return y


def sketch_box(c, x, y, w, h, title=None, color=INK, fill=None, seed=7,
               lw=1.3, title_size=11.5, title_color=None, radius=7):
    if fill is not None:
        c.setFillColor(fill); c.roundRect(x, y, w, h, radius, stroke=0, fill=1)
    rough_rect(c, x, y, w, h, color, lw, 2, 1.0, seed)
    if title:
        txt(c, x + 10, y + h - 16, title, HAND, title_size, title_color or color)
    return (x + w / 2, y + h / 2)


def note(c, x, y, lines, color=RED, size=15, leading=17, font=SCRIPT):
    for i, ln in enumerate(lines):
        txt(c, x, y - i * leading, ln, font, size, color)
    return y - len(lines) * leading


def page_bg(c):
    c.setFillColor(PAPER)
    c.rect(0, 0, W, H, stroke=0, fill=1)


def header(c, title, sub=None, num=None, total=None):
    page_bg(c)
    txt(c, 46, H - 64, title, SCRIPT, 33, INK)
    tw = sw(title, SCRIPT, 33)
    rough_line(c, 46, H - 74, 46 + tw * 0.98, H - 74, RED, 2.2, 2, 1.7, 101)
    if sub:
        txt(c, 48, H - 96, sub, HAND, 11, GREY)
    if num:
        txt(c, W - 92, 26, "%d / %d" % (num, total), HAND, 10, GREY)
    txt(c, 46, 26, "Inception-of-Things  .  p2  .  ynassibiS", HAND, 9, HexColor(0xB4BAC4))


def pod_shape(c, cx, cy, r, label=None, color=BLUE, fill=FILL_BLUE, seed=17, lsize=8):
    """Kubernetes draws pods as heptagons; so do we."""
    rough_poly(c, cx, cy, r, 7, color, 1.2, math.pi / 2, fill, seed)
    if label:
        ctxt(c, cx, cy - 3, label, HAND, lsize, color)
