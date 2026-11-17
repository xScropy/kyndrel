"""Writes a minimal PGS (.sup) subtitle stream: one caption shown from
`start` to `end` seconds, rendered with Pillow. Used to test image subtitles."""
import struct, sys
from PIL import Image, ImageDraw, ImageFont

def seg(pts, typ, data):
    ticks = int(pts * 90000)
    return b'PG' + struct.pack('>IIBH', ticks, ticks, typ, len(data)) + data

def rle(img):
    w, h = img.size
    px = img.load()
    out = bytearray()
    for y in range(h):
        x = 0
        while x < w:
            c = px[x, y]
            n = 1
            while x + n < w and px[x + n, y] == c and n < 16383:
                n += 1
            if c != 0:
                if n == 1:
                    out += bytes([c])
                elif n < 64:
                    out += bytes([0, 0x80 | n, c])
                else:
                    out += bytes([0, 0xC0 | (n >> 8), n & 0xFF, c])
            else:
                if n < 64:
                    out += bytes([0, n])
                else:
                    out += bytes([0, 0x40 | (n >> 8), n & 0xFF])
            x += n
        out += b'\x00\x00'
    return bytes(out)

def caption(text, vw, vh, start, end, comp):
    font = ImageFont.load_default(size=40)
    tmp = ImageDraw.Draw(Image.new('L', (1, 1)))
    l, t, r, b = tmp.textbbox((0, 0), text, font=font)
    w, h = r - l + 24, b - t + 24
    img = Image.new('P', (w, h), 0)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=2)          # box
    d.text((12 - l, 12 - t), text, font=font, fill=1)  # text
    x, y = (vw - w) // 2, vh - h - 60
    # palette: 0 transparent, 1 yellow text, 2 dark box (Y Cr Cb A)
    pal = bytes([0, 0]) + bytes([0, 16, 128, 128, 0]) + bytes([1, 210, 146, 16, 255]) + bytes([2, 30, 128, 128, 200])
    data = rle(img)
    ods = struct.pack('>HBB', 1, 0, 0xC0) + struct.pack('>I', len(data) + 4)[1:] + struct.pack('>HH', w, h) + data
    pcs_on = struct.pack('>HHBHBBBB', vw, vh, 0x10, comp, 0x80, 0, 0, 1) + struct.pack('>HBBHH', 1, 0, 0, x, y)
    wds = struct.pack('>BBHHHH', 1, 0, x, y, w, h)
    out = seg(start, 0x16, pcs_on) + seg(start, 0x17, wds) + seg(start, 0x14, pal) + seg(start, 0x15, ods) + seg(start, 0x80, b'')
    pcs_off = struct.pack('>HHBHBBBB', vw, vh, 0x10, comp + 1, 0x00, 0, 0, 0)
    out += seg(end, 0x16, pcs_off) + seg(end, 0x17, wds) + seg(end, 0x80, b'')
    return out

if __name__ == '__main__':
    path, vw, vh = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    with open(path, 'wb') as f:
        f.write(caption('PGS image subtitle (bitmap)', vw, vh, 0.5, 59.0, 0))
