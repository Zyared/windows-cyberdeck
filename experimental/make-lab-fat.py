"""Create a NEW FAT32 lab image with a lab EFI loader; never open host disks."""
import argparse
import hashlib
import struct
from pathlib import Path
from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('tree',type=Path)
p.add_argument('loader',type=Path)
p.add_argument('output',type=Path)
args=p.parse_args()
tree=args.tree.resolve();output=args.output.resolve()
if output.exists() or tree in output.parents or output.suffix!='.img':
    raise ValueError('Use a new .img file outside the source tree')
sources=[f for f in tree.rglob('*') if f.is_file() and f.relative_to(tree).parts[0].lower() in {'efi','boot','sources'}]
size=sum(f.stat().st_size for f in sources)+128*1024*1024
size=(size+65535)//65536*65536
output.touch(exist_ok=False)
offset=1024*1024
fat=PyFat(offset=offset);fat.mkfs(str(output),fat_type=PyFat.FAT_TYPE_FAT32,size=size,label='ARASAKA LAB');fat.close()
# Standard removable-media MBR/FAT32 layout. Windows boot libraries require a
# discoverable partition; a bare superfloppy can be readable in EFI yet fail.
with output.open('r+b') as disk:
    mbr=bytearray(512)
    struct.pack_into('<I',mbr,440,0xA7A54A20)
    mbr[446:462]=struct.pack('<B3sB3sII',0x80,b'\xfe\xff\xff',0x0c,b'\xfe\xff\xff',offset//512,size//512)
    mbr[510:512]=b'\x55\xaa'
    disk.write(mbr)
    for sector in (0,6):
        disk.seek(offset+sector*512+28);disk.write(struct.pack('<I',offset//512))
with PyFatFS(str(output),offset=offset) as fs:
    for path in sorted(sources):
        relative=path.relative_to(tree).as_posix()
        source=args.loader if relative.lower()=='efi/boot/bootx64.efi' else path
        parent=str(Path(relative).parent).replace('\\','/')
        if parent!='.':fs.makedirs(parent,recreate=True)
        with source.open('rb') as src,fs.openbin(relative,'w') as dst:
            while chunk:=src.read(16*1024*1024):dst.write(chunk)
        print(relative,flush=True)
    with fs.openbin('sources/boot.wim','r') as stream:
        actual=hashlib.file_digest(stream,'sha256').hexdigest()
    with (tree/'sources/boot.wim').open('rb') as stream:
        expected=hashlib.file_digest(stream,'sha256').hexdigest()
    if actual!=expected:raise RuntimeError('WIM readback hash mismatch')
print(f'Created and verified {output}: {output.stat().st_size} bytes',flush=True)
