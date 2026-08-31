#!/usr/bin/env python3
"""Exit successfully when an 8-bit PNG has transparency at every corner."""

import struct
import sys
import zlib


def chunks(data):
    pos = 8
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + length]
        yield kind, payload
        pos += length + 12


def main(path):
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return 2
    parts = list(chunks(data))
    ihdr = next(payload for kind, payload in parts if kind == b"IHDR")
    width, height, depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", ihdr)
    if depth != 8 or color_type not in (4, 6) or interlace != 0:
        return 2
    channels = 2 if color_type == 4 else 4
    packed = zlib.decompress(b"".join(payload for kind, payload in parts if kind == b"IDAT"))
    stride = width * channels
    rows = []
    prev = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = packed[offset]
        raw = bytearray(packed[offset + 1 : offset + 1 + stride])
        offset += stride + 1
        for x in range(stride):
            left = raw[x - channels] if x >= channels else 0
            up = prev[x]
            upper_left = prev[x - channels] if x >= channels else 0
            if filter_type == 1:
                raw[x] = (raw[x] + left) & 255
            elif filter_type == 2:
                raw[x] = (raw[x] + up) & 255
            elif filter_type == 3:
                raw[x] = (raw[x] + ((left + up) // 2)) & 255
            elif filter_type == 4:
                p = left + up - upper_left
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - upper_left)
                predictor = left if pa <= pb and pa <= pc else up if pb <= pc else upper_left
                raw[x] = (raw[x] + predictor) & 255
            elif filter_type != 0:
                return 2
        rows.append(raw)
        prev = raw
    alpha_offset = channels - 1
    corners = ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))
    return 0 if all(rows[y][x * channels + alpha_offset] < 255 for x, y in corners) else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
