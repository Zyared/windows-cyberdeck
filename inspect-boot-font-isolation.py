"""Read-only PE inspection of saved boot components; never patch or install them.

Requires pefile and capstone. Candidates are static evidence, not verified hooks.
"""
import argparse
import bisect
import hashlib
import json
import struct
from pathlib import Path

import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone.x86 import X86_OP_IMM, X86_OP_MEM


def inspect(path):
    original = path.read_bytes()
    pe = pefile.PE(data=original)
    if pe.FILE_HEADER.Machine != 0x8664:
        raise ValueError(f"Expected x64: {path}")
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    md.detail = True
    base = pe.OPTIONAL_HEADER.ImageBase
    result = {"path": str(path), "sha256": hashlib.sha256(original).hexdigest(),
              "fontpath_readers": [], "font_verifier_candidates": [],
              "boot_application_transfer_candidates": [], "font_path_strings": []}
    for value in (r'\EFI\Microsoft\Boot\Fonts', r'\Windows\Boot\Fonts'):
        encoded = (value + '\0').encode('utf-16le')
        offset = original.find(encoded)
        while offset != -1:
            result['font_path_strings'].append({'value': value,
                                                'rva': hex(pe.get_rva_from_offset(offset))})
            offset = original.find(encoded, offset+1)
    needles = [struct.pack('<I', x) for x in (0x1200004A, 0xC00002C4, 0xD0000009)]
    seen = set()
    for entry in pe.DIRECTORY_ENTRY_EXCEPTION:
        start, end = entry.struct.BeginAddress, entry.struct.EndAddress
        if (start, end) in seen:
            continue
        seen.add((start, end))
        code = pe.get_data(start, end-start)
        if not any(n in code for n in needles):
            continue
        instructions = list(md.disasm(code, base+start))
        immediates = {op.imm & 0xFFFFFFFF for i in instructions
                      for op in i.operands if op.type == X86_OP_IMM}
        displacements = {op.mem.disp for i in instructions
                         for op in i.operands if op.type == X86_OP_MEM}
        categories = []
        if 0x1200004A in immediates:
            categories.append('fontpath_readers')
        # Matches the inspected Boot Manager verifier's error, algorithm and policy
        # constants. This is intentionally called a candidate without exact symbols.
        if {0xC00002C4, 0x165} <= immediates and -0x800C in displacements:
            categories.append('font_verifier_candidates')
        if any(i.mnemonic == 'mov' and i.op_str == 'r8d, 0xd0000009'
               for i in instructions):
            categories.append('boot_application_transfer_candidates')
        for category in categories:
            result[category].append({
                "rva": hex(start), "end_rva": hex(end),
                "instructions": [f"{i.address-base:#x}: {i.mnemonic} {i.op_str}"
                                 for i in instructions],
                "direct_calls": [hex(i.operands[0].imm-base) for i in instructions
                                 if i.mnemonic == 'call' and i.operands[0].type == X86_OP_IMM]})
    # Resolve call sites to each verifier candidate using exception-table bounds
    # and verify instruction boundaries, instead of guessing from byte matches.
    ranges = sorted((e.struct.BeginAddress, e.struct.EndAddress)
                    for e in pe.DIRECTORY_ENTRY_EXCEPTION)
    starts = [start for start, _ in ranges]
    for candidate in result['font_verifier_candidates']:
        target = int(candidate['rva'], 16)
        candidate['callers'] = []
        for section in pe.sections:
            if not section.Characteristics & 0x20000000:
                continue
            data = section.get_data()
            pos = data.find(b'\xe8')
            while pos != -1 and pos+5 <= len(data):
                call_rva = section.VirtualAddress+pos
                relative = struct.unpack_from('<i', data, pos+1)[0]
                if call_rva+5+relative == target:
                    index = bisect.bisect_right(starts, call_rva)-1
                    if index >= 0:
                        start, end = ranges[index]
                        insns = list(md.disasm(pe.get_data(start, end-start), base+start))
                        for n, ins in enumerate(insns):
                            if ins.address == base+call_rva and ins.mnemonic == 'call':
                                candidate['callers'].append({
                                    'function_rva': hex(start), 'call_rva': hex(call_rva),
                                    'context': [f'{i.address-base:#x}: {i.mnemonic} {i.op_str}'
                                                for i in insns[max(0,n-3):n+6]]})
                pos = data.find(b'\xe8', pos+1)
    if hashlib.sha256(path.read_bytes()).hexdigest() != result['sha256']:
        raise RuntimeError(f"Input changed during inspection: {path}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    inputs = [args.snapshot / 'efi-bootmgfw.efi', args.snapshot / 'windows-winload.efi']
    if args.output.resolve() in {p.resolve() for p in inputs}:
        raise ValueError('Output must not overwrite input')
    reports = [inspect(p) for p in inputs]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"installed": False, "boot_tested": False,
                                      "components": reports}, indent=2), encoding='utf-8')
    for report in reports:
        print(Path(report['path']).name, {key: [x['rva'] for x in report[key]]
              for key in ('fontpath_readers', 'font_verifier_candidates',
                          'boot_application_transfer_candidates')})


if __name__ == '__main__':
    main()
