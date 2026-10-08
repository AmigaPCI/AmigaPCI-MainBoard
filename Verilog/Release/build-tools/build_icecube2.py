#!/usr/bin/env python3
"""Build the existing Synplify/iCEcube2 projects; never use Yosys.

Outputs and source snapshots live in BUILD_DIR, leaving supplied BINs intact.
Each target records the last completed stage and input hashes in status.json.
"""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(argv, cwd, env, log):
    print("Running: " + " ".join(map(str, argv)), flush=True)
    with log.open("w") as stream:
        result = subprocess.run(argv, cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        print("\n".join(log.read_text(errors="replace").splitlines()[-25:]), file=sys.stderr)
        raise RuntimeError(f"exit {result.returncode}; see {log}")


def launcher_home(args):
    # Installed binaries stay untouched. Vendor /bin/sh wrappers need Bash.
    home = args.output / 'synplify-launchers'
    home.mkdir(parents=True, exist_ok=True)
    for item in args.synplify.iterdir():
        dest = home / item.name
        if item.name == 'bin':
            shutil.copytree(item, dest, dirs_exist_ok=True)
            for script in dest.iterdir():
                if script.is_file():
                    data = script.read_bytes()
                    if data.startswith(b'#!/bin/sh\n'):
                        script.write_bytes(data.replace(b'#!/bin/sh\n', b'#!/bin/bash\n', 1))
        elif not dest.exists():
            dest.symlink_to(item, target_is_directory=item.is_dir())
    return home


def build(args, target):
    src = args.source / target
    projects = list(src.glob('*/*_syn.prj'))
    if len(projects) != 1:
        raise ValueError(f"Expected one Synplify project in {src}")
    prj = projects[0]
    base = prj.name.removesuffix('_syn.prj')
    sbt_project = prj.with_name(base + '_sbt.project')
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.optionxform = str
    cfg.read(sbt_project)
    impl = cfg['Project']['CurImplementation']
    settings = cfg[impl]
    top = settings['DesignCell']
    device = settings['DeviceFamily'] + settings['Device'] + '-' + settings['DevicePackage']
    pcf = (prj.parent / settings['PhysicalConstraintFile']).resolve()
    # These projects use the standard vendor backend defaults plus these
    # two explicit switches. Reject differing build options instead of silently
    # applying this preset to an incompatible project.
    expected = dict(PlacerEffortLevel='std', PlacerAutoLutCascade='yes',
                    PlacerAutoRamCascade='yes', PlacerPowerDriven='no', PlacerAreaDriven='no',
                    RouteWithTimingDriven='yes', RouteWithPinPermutation='yes',
                    BitmapSPIFlashMode='yes', BitmapRAM4KInit='yes', BitmapInitRamBank='1111',
                    BitmapOscillatorFR='low', BitmapEnableWarmBoot='yes',
                    BitmapDisableHeader='no', BitmapSetSecurity='no', BitmapSetNoUsedIONoPullup='yes')
    for key, value in expected.items():
        if cfg['tool options'].get(key) != value:
            raise ValueError(f"Unsupported {key} in {sbt_project}")
    inputs = sorted({*src.glob('*.v'), *src.glob('*.sdc'), *src.glob('*.pcf'), prj, sbt_project})
    hashes = {str(p): digest(p) for p in inputs}
    out = args.output / target
    work = out / prj.parent.name
    work.mkdir(parents=True, exist_ok=True)
    status_file = out / 'status.json'
    status = dict(target=target, device=device, top=top, stage='not_started',
                  inputs_sha256=hashes, synplify_path=str(args.synplify),
                  icecube2_root=str(args.icecube2), hardware_tested=False)
    edif = work / settings['NetlistFile']
    image = work / impl / 'sbt/outputs/bitmap' / (top + '_bitmap.bin')
    exported = out / (top + '_bitmap.bin')
    try:
        if args.stage == 'backend':
            previous = json.loads(status_file.read_text())
            if previous.get('inputs_sha256') != hashes or previous.get('edif_sha256') != digest(edif):
                raise RuntimeError('Synthesis inputs/output changed; run make synth first')
            status.update(stage='synthesis', edif=str(edif), edif_sha256=digest(edif))
        else:
            # Remove stale final artifacts before a fresh synthesis attempt.
            exported.unlink(missing_ok=True)
            edif.unlink(missing_ok=True)
            for p in inputs:
                dest = out / p.relative_to(src)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(p, dest)
            env = os.environ.copy()
            env['SYN_HOMEDIR'] = str(launcher_home(args))
            env['LD_LIBRARY_PATH'] = str(args.synplify / 'linux_a_64/lib')
            # Call the vendor 64-bit batch driver directly, avoiding synpwrap's
            # 32-bit launcher and the bundled /bin/sh script's bash syntax.
            batch = Path(env['SYN_HOMEDIR']) / 'linux_a_64/mbin/synbatch'
            run([str(batch), '-product', 'synplify_pro', '-batch', prj.name],
                work, env, out / 'synthesis.log')
            if not edif.is_file() or not edif.stat().st_size:
                raise RuntimeError('Synplify did not produce an EDIF netlist')
            status.update(stage='synthesis', edif=str(edif), edif_sha256=digest(edif))
        if args.stage != 'synth':
            exported.unlink(missing_ok=True)
            image.unlink(missing_ok=True)
            env = os.environ.copy()
            env.update(SBT_DIR=str(args.icecube2 / 'sbt_backend'),
                       BUILD_DEVICE=device, BUILD_TOP=top, BUILD_IMPL=impl, BUILD_BASE=base,
                       BUILD_PCF='../' + pcf.name, BACKEND_PRELOAD=args.preload)
            tcl = out / 'backend.tcl'
            tcl.write_text('''source [file join $::env(SBT_DIR) tcl sbt_backend_synpl.tcl]
set ::env(LD_PRELOAD) $::env(BACKEND_PRELOAD)
set options ":edifparser -y $::env(BUILD_PCF) :router --pin_permutation :bitmap --set_unused_io_nopullup"
if {[catch {
    set ok [run_sbt_backend_auto $::env(BUILD_DEVICE) $::env(BUILD_TOP) [pwd] $::env(BUILD_IMPL) $options $::env(BUILD_BASE)]
} message]} {
    puts stderr $message
    exit 1
}
if {!$ok} {exit 1}
exit 0
''')
            run([args.tclsh, str(tcl)], work, env, out / 'backend.log')
            if not image.is_file() or not image.stat().st_size:
                raise RuntimeError('iCEcube2 did not produce a bitmap')
            shutil.copy2(image, exported)
            status.update(stage='bitstream', bitstream=str(exported), bitstream_sha256=digest(exported))
        print(f"{target}: {status['stage']} complete ({out})", flush=True)
    except Exception as error:
        status['error'] = str(error)
        raise
    finally:
        status_file.write_text(json.dumps(status, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--synplify', type=Path, required=True)
    parser.add_argument('--icecube2', type=Path, required=True)
    parser.add_argument('--stage', choices=['all', 'synth', 'backend'], default='all')
    parser.add_argument('--targets', nargs='+', required=True)
    parser.add_argument('--tclsh', default='tclsh')
    parser.add_argument('--preload', default='')
    args = parser.parse_args()
    for key in ('source', 'output', 'synplify', 'icecube2'):
        setattr(args, key, getattr(args, key).resolve())
    if args.output == args.source or args.source in args.output.parents:
        parser.error('Output must be outside the source directory')
    failed = []
    for target in args.targets:
        if not target.startswith('U') or not target[1:].isdigit():
            parser.error('Targets must be chip designators, e.g. U109')
        try:
            build(args, target)
        except (OSError, ValueError, KeyError, RuntimeError, configparser.Error) as error:
            print(f'{target}: FAILED: {error}', file=sys.stderr, flush=True)
            failed.append(target)
    if failed:
        sys.exit('Failed targets: ' + ', '.join(failed))


if __name__ == '__main__':
    main()
