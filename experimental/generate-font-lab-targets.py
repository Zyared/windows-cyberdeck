"""Generate exact PE fingerprints for the isolated WinRE experiment only."""
import argparse
import hashlib
import json
from pathlib import Path
import pefile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('bootmgr',type=Path)
p.add_argument('winload',type=Path)
p.add_argument('output',type=Path)
p.add_argument('--host',action='store_true',help='Exact reviewed laptop winload 26100.9949')
args=p.parse_args()
args.output.mkdir(parents=True,exist_ok=True)
lines=['// Generated lab fingerprints. No original binary content beyond prologues.',
       'typedef struct {UINT32 timestamp,checksum,size,font_rva,path_rva;UINT8 font_bytes[32];} Target;']
manifest=[]
known={'bootmgr':'d8d85f707b4c1da37642a91bc3860c405e8022a066dafd36348d515ad915ce43',
       'winload':'d270736e3e81898a5ac5838aa8c38155ace63b1619d91bc58fca42cb016303c5'}
if args.host:
    known['winload']='cd736797b74b87714cd53d78e5724de3bc7263c3db91e4f9eeb66969ad795443'
lines.append('#define TARGET_HOST '+str(int(args.host)))
for name,path,rva in [('bootmgr',args.bootmgr,0x1c88d0),('winload',args.winload,0x19ef2c)]:
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    if digest!=known[name]:raise ValueError(f'Unreviewed {name} build: {digest}')
    pe=pefile.PE(str(path))
    prologue=pe.get_data(rva,32)
    # Both inspected verifiers have this register-saving prologue. Keep the exact
    # complete fingerprint in the output; do not search and patch unknown builds.
    if not prologue.startswith(bytes.fromhex('4055')) and not prologue.startswith(bytes.fromhex('55535657')):
        raise ValueError(f'Unexpected verifier prologue in {path}: {prologue.hex()}')
    path_bytes=('\\boot\\fonts\\segoe_slboot.ttf\0').encode('utf-16le')
    data=path.read_bytes()
    if data.count(path_bytes)!=1:raise ValueError('Spinner font path is not unique')
    path_rva=pe.get_rva_from_offset(data.index(path_bytes))
    values=[pe.FILE_HEADER.TimeDateStamp,pe.OPTIONAL_HEADER.CheckSum,pe.OPTIONAL_HEADER.SizeOfImage,rva,path_rva]
    lines.append('static const Target '+name+'_target={'+','.join(hex(x) for x in values)+',{'+','.join(hex(b) for b in prologue)+'}};')
    manifest.append({'component':name,'path':str(path.resolve()),'sha256':digest,
                     'font_verifier_rva':hex(rva),'spinner_path_rva':hex(path_rva),'prologue':prologue.hex()})
    if name=='bootmgr':
        transfer=0x1cf028
        lines.append(f'#define TRANSFER_RVA {transfer:#x}')
        lines.append('static const UINT8 transfer_bytes[32]={'+','.join(hex(b) for b in pe.get_data(transfer,32))+'};')
(args.output/'font-lab-targets.h').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(args.output/'targets.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
