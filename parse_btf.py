#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Parse a raw BTF blob (/sys/kernel/btf/vmlinux) and print struct offsets."""
import struct, sys

BTF = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\patri\Desktop\Nova pasta\work\fw\btf.bin"
b = open(BTF, "rb").read()
print("[i] btf size", len(b), "magic", b[:4].hex())
magic, version, flags, hdr_len = struct.unpack_from("<HBBI", b, 0)
type_off, type_len, str_off, str_len = struct.unpack_from("<IIII", b, 8)
print(f"[i] version={version} hdr_len={hdr_len} type_off={type_off} type_len={type_len} str_off={str_off} str_len={str_len}")
types = b[hdr_len + type_off: hdr_len + type_off + type_len]
strs = b[hdr_len + str_off: hdr_len + str_off + str_len]

def sname(x):
    end = strs.find(b"\0", x)
    return strs[x:end].decode("utf-8", "replace") if end >= 0 else ""

i = 0
results = []
while i < len(types):
    name_off, info, size = struct.unpack_from("<III", types, i)
    i += 12
    vlen = info & 0xffff
    kind = (info >> 24) & 0x1f
    tn = sname(name_off)
    if kind == 4 or kind == 5:  # STRUCT / UNION
        members = []
        if vlen:
            for m in range(vlen):
                mn, mt, mo = struct.unpack_from("<III", types, i)
                i += 12
                members.append((sname(mn), mt, mo))
        if tn in ("task_struct", "cred", "task_security_struct", "kernel_cap_struct"):
            results.append((tn, size, members))
    elif kind == 3:            # ARRAY: one btf_array (12 bytes)
        i += 12
    elif kind == 6:            # ENUM: vlen * 8
        i += vlen * 8
    elif kind in (13, 15, 19): # FUNC_PROTO / DATASEC / ENUM64: vlen * 12
        i += vlen * 12
    elif kind in (1, 14, 17):  # INT has 4 extra bytes (encoding/bits); VAR/DECL_TAG too
        i += 4

for tn, size, members in results:
    print(f"=== struct {tn} (size={size}, {len(members)} members)")
    if tn == "task_struct":
        for mn, mt, mo in members:
            if mn in ("security", "cred", "real_cred", "seccomp", "thread", "comm", "tasks", "pid", "tgid"):
                print(f"   {mn:20s} 0x{mo//8:x}")
    else:
        for mn, mt, mo in members:
            print(f"   {mn:24s} 0x{mo//8:x}")
