"""Boot only a lab ISO in headless QEMU, capture evidence, then stop the guest.

No network adapter, host disks, USB passthrough, or shared folders are attached.
Requires Pillow for diagnostic screenshot conversion.
"""
import argparse
import json
import queue
import shutil
import subprocess
import threading
import time
from pathlib import Path
from PIL import Image


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('lab', type=Path)
    p.add_argument('iso', type=Path)
    p.add_argument('--seconds', type=int, default=120)
    p.add_argument('--name', default='baseline')
    p.add_argument('--efi-tree', type=Path)
    p.add_argument('--record', action='store_true', help='Capture actual guest frames every 0.5 s from 10 to 50 s')
    p.add_argument('--secure-vars', type=Path, help='Lab-only enrolled OVMF variable store')
    args = p.parse_args()
    lab, iso = args.lab.resolve(), args.iso.resolve()
    if not iso.is_file() or iso.suffix.lower() not in ('.iso','.img') or lab not in iso.parents:
        raise ValueError('Use an existing ISO/IMG inside the lab; host block devices are forbidden')
    if not args.name.replace('-', '').isalnum() or not 10 <= args.seconds <= 600:
        raise ValueError('Invalid run name or duration')
    run = lab / (args.name+'-'+time.strftime('%Y%m%d-%H%M%S'))
    run.mkdir()
    qemu = lab / 'qemu'
    var_source=qemu/'share/edk2-i386-vars.fd'
    firmware=qemu/'share/edk2-x86_64-code.fd'
    if args.secure_vars:
        var_source=args.secure_vars.resolve()
        if not var_source.is_file() or lab not in var_source.parents:
            raise ValueError('Secure variables must be a regular file inside the lab')
        firmware=qemu/'share/edk2-x86_64-secure-code.fd'
    shutil.copyfile(var_source, run/'vars.fd')
    command = [str(qemu/'qemu-system-x86_64.exe'), '-L', str(qemu/'share'),
               '-machine', 'q35,smm=on', '-accel', 'tcg,thread=multi', '-cpu', 'max',
               '-smp', '2', '-m', '2560',
               '-drive', f'if=pflash,format=raw,readonly=on,file={firmware}',
               '-drive', f'if=pflash,format=raw,file={run}/vars.fd',
               '-nic', 'none', '-display', 'none', '-qmp', 'stdio', '-no-reboot',
               '-debugcon',f'file:{run}/efi-debug.log']
    if args.secure_vars:
        command += ['-global','driver=cfi.pflash01,property=secure,value=on']
    if iso.suffix.lower()=='.iso':
        command += ['-cdrom', str(iso)]
    else:
        command += ['-drive',f'file={iso},format=raw,if=ide,snapshot=on','-boot','order=c']
    if args.efi_tree:
        tree=args.efi_tree.resolve()
        if not tree.is_dir() or lab not in tree.parents:
            raise ValueError('EFI tree must be a lab subdirectory')
        # FAT backing is read-only; a disposable overlay accepts guest BCD writes.
        command += ['-drive',f'file=fat:{tree},format=raw,if=none,id=labefi,snapshot=on',
                    '-device','ide-hd,drive=labefi,bootindex=0']
    (run/'command.json').write_text(json.dumps(command, indent=2), encoding='utf-8')
    incoming = queue.Queue()
    with (run/'stderr.log').open('w', encoding='utf-8') as err:
        proc = subprocess.Popen(command, cwd=lab, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=err, text=True, creationflags=subprocess.CREATE_NO_WINDOW)
        def reader():
            for line in proc.stdout:
                incoming.put(line)
            incoming.put(None)
        threading.Thread(target=reader, daemon=True).start()
        def receive():
            value = incoming.get(timeout=30)
            if value is None:
                raise RuntimeError('QEMU exited; inspect stderr.log')
            with (run/'qmp.jsonl').open('a', encoding='utf-8') as log:
                log.write(value)
            return json.loads(value)
        def request(execute, arguments=None):
            message = {'execute': execute}
            if arguments is not None:
                message['arguments'] = arguments
            proc.stdin.write(json.dumps(message)+'\n')
            proc.stdin.flush()
            while True:
                response = receive()
                if 'error' in response:
                    raise RuntimeError(response['error'])
                if 'return' in response:
                    return response['return']
        try:
            receive()
            request('qmp_capabilities')
            start = time.monotonic()
            times=[5,15,30,60,args.seconds]
            if args.record:times += [n/2 for n in range(20,100)]
            for elapsed in sorted(set(times)):
                if elapsed > args.seconds:
                    continue
                time.sleep(max(0, start+elapsed-time.monotonic()))
                if proc.poll() is not None:
                    print(f'Guest exited with code {proc.returncode}; inspect last captured frame.',flush=True)
                    break
                ppm = run/(f'frame-{int(elapsed*1000):06d}.ppm' if args.record else f'{elapsed:03d}.ppm')
                request('screendump', {'filename': str(ppm)})
                Image.open(ppm).save(ppm.with_suffix('.png'))
                ppm.unlink() # This exact disposable screenshot, never a directory.
                if not args.record or elapsed in (5,15,30,60,args.seconds):
                    print(f'{elapsed}s: {ppm.with_suffix(".png")}', flush=True)
                debug=run/'efi-debug.log'
                if debug.exists() and 'Windows boot application returned' in debug.read_text(errors='replace'):
                    print('Boot application returned early; stopping this guest.',flush=True)
                    break
            if proc.poll() is None:
                request('quit')
        finally:
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.terminate()
                proc.wait(timeout=5)
    print(f'Guest stopped. Evidence: {run}', flush=True)


if __name__ == '__main__':
    main()
