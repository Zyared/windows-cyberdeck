"""Build a lab-only UEFI Windows RE ISO from a prepared tree (pycdlib)."""
import argparse
import re
from pathlib import Path
import pycdlib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tree', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    tree, output = args.tree.resolve(), args.output.resolve()
    if output.exists() or tree in output.parents:
        raise ValueError('Output must be a new file outside the input tree')
    for needed in ['efisys.bin', 'bootmgr.efi', 'sources/boot.wim', 'Boot/BCD']:
        if not (tree / needed).is_file():
            raise FileNotFoundError(needed)
    iso = pycdlib.PyCdlib()
    iso.new(interchange_level=3, joliet=3, udf='2.60', vol_ident='ARASAKA_LAB')
    allowed = {'efi', 'boot', 'sources', 'bootmgr.efi', 'efisys.bin'}
    for path in sorted(tree.rglob('*'), key=lambda p: (len(p.parts), str(p))):
        relative = path.relative_to(tree)
        if relative.parts[0].lower() not in allowed:
            continue
        name = '/' + relative.as_posix()
        iso_parts = [re.sub(r'[^A-Z0-9_]', '_', p.upper()) for p in relative.parts]
        if path.is_dir():
            iso.add_directory(iso_path='/'+'/'.join(iso_parts), joliet_path=name, udf_path=name)
        else:
            stem, dot, suffix = relative.name.rpartition('.')
            iso_parts[-1] = (re.sub(r'[^A-Z0-9_]', '_', stem.upper())+'.'+suffix.upper()
                             if dot else iso_parts[-1])
            iso.add_file(str(path), iso_path='/'+'/'.join(iso_parts)+';1', joliet_path=name, udf_path=name)
    iso.add_eltorito('/EFISYS.BIN;1', platform_id=0xEF, efi=True)
    try:
        iso.write(str(output))
    finally:
        iso.close()
    # Check the large WIM's directory record without loading it into RAM.
    check = pycdlib.PyCdlib()
    check.open(str(output))
    record = check.get_record(udf_path='/sources/boot.wim')
    if record.get_data_length() != (tree/'sources/boot.wim').stat().st_size:
        raise RuntimeError('WIM size mismatch in ISO')
    check.close()
    print(f'Lab-only ISO: {output} ({output.stat().st_size} bytes)')


if __name__ == '__main__':
    main()
