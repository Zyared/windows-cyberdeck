"""Build resource-only DLLs for Resource Redirect; never modify Windows DLLs.

IDs are from this PC's original HKLM CLSID DefaultIcon and saved desktop.ini.
Requires Python 3 and Windhawk's LLVM linker. No third-party Python packages.
"""
import argparse
import struct
import subprocess
from pathlib import Path

def record(kind, identifier, data):
    header = struct.pack('<IIHHHHIHHII', len(data), 32, 0xffff, kind,
                         0xffff, identifier, 0, 0x1030, 0, 0, 0)
    return header + data + bytes((-len(data)) % 4)

def build(icons, output, mapping, linker):
    result = record(0, 0, b'')
    next_id = 1
    for group_id, name in sorted(mapping.items()):
        ico = (icons / (name + '.ico')).read_bytes()
        reserved, kind, count = struct.unpack_from('<HHH', ico)
        if reserved != 0 or kind != 1 or not count:
            raise ValueError(f'Invalid icon: {name}')
        group = struct.pack('<HHH', 0, 1, count)
        for i in range(count):
            entry = ico[6 + 16*i:22 + 16*i]
            length, offset = struct.unpack_from('<II', entry, 8)
            payload = ico[offset:offset+length]
            if len(payload) != length:
                raise ValueError(f'Truncated icon: {name}')
            result += record(3, next_id, payload)
            group += entry[:12] + struct.pack('<H', next_id)
            next_id += 1
        result += record(14, group_id, group)
    res = output.with_suffix('.res')
    res.write_bytes(result)
    subprocess.run([str(linker), '-flavor', 'link', '/dll', '/noentry',
                    '/machine:x64', '/out:' + str(output), str(res)], check=True)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--icons', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--linker', type=Path, default=Path(r'C:\Program Files\Windhawk\Compiler\bin\ld.lld.exe'))
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    build(a.icons, a.output/'arasaka-imageres.dll', {
        25:'network', 54:'recyclefull', 55:'recycle', 108:'music',
        109:'thispc', 112:'documents', 113:'pictures', 183:'desktop',
        184:'downloads', 189:'videos'}, a.linker)
    build(a.icons, a.output/'arasaka-shell32.dll', {51380:'home',51586:'gallery'}, a.linker)
    (a.output/'theme.ini').write_text(
        '[redirections]\n%SystemRoot%\\System32\\imageres.dll=arasaka-imageres.dll\n'
        '%SystemRoot%\\System32\\shell32.dll=arasaka-shell32.dll\n', encoding='utf-8')
