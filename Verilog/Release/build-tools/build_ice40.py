#!/usr/bin/env python3
"""Build the AmigaPCI LBC040 RTL with Yosys, nextpnr, and IceStorm.

Usage: python3 build_ice40.py --source VERILOG_DIR --output BUILD_DIR [--target U111|U400]
Requires Python 3, Yosys, nextpnr-ice40, and IceStorm. Does not program hardware.
Preserves bidirectional IO and PCF pullups; validates the mapped netlist and pins.
Timing checks cover supplied clock constraints, not external board timing.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


DEVICES = {name: ("hx4k", "tq144") for name in ("U109", "U110", "U409", "U712", "U111")}
DEVICES["U400"] = ("hx1k", "vq100")


def run(command, logfile, cwd):
    print("Running:", " ".join(map(str, command)), flush=True)
    with logfile.open("w") as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print("\n".join(logfile.read_text(errors="replace").splitlines()[-35:]), file=sys.stderr)
        raise RuntimeError(f"Command failed ({result.returncode}); see {logfile}")


def pcf_path(source, target):
    return source / ({"U409": "U409.pcf", "U712": "U712.pcf"}.get(target, f"{target}_TOP.pcf"))


def constraints(source, target):
    """Translate the project's small PCF/SDC subset, rejecting unknown syntax."""
    pins = {}
    pullups = {}
    used_pins = set()
    lines = []
    for number, raw in enumerate(pcf_path(source, target).read_text().splitlines(), 1):
        words = raw.split("#", 1)[0].split("//", 1)[0].split()
        if not words:
            continue
        if len(words) not in (3, 5) or words[0] != "set_io":
            raise ValueError(f"Unsupported PCF syntax on line {number}: {raw}")
        _, port, pin, *options = words
        if options and (options[0] != "-pullup" or options[1] not in ("yes", "no")):
            raise ValueError(f"Unsupported PCF option on line {number}: {raw}")
        if port in pins or pin in used_pins:
            raise ValueError(f"Duplicate port/pin on PCF line {number}: {raw}")
        pins[port] = pin
        if options:
            pullups[port] = options[1] == "yes"
        used_pins.add(pin)
        # nextpnr requires options BEFORE the signal and pin; iCEcube accepts
        # them after. Leaving them after silently drops the requested pullups.
        lines.append(" ".join(["set_io", *options, port, pin]))

    clocks = {}
    for raw in (source / f"{target}_TOP.sdc").read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        match = re.fullmatch(r"create_clock\s+(?:-name\s+\S+\s+)?-period\s+([\d.]+)\s+\[get_(ports|nets)\s+\{?([^{}\] ]+)\}?\]", line)
        if not match or float(match[1]) <= 0:
            raise ValueError(f"Unsupported SDC constraint: {line}")
        clock = match[3]
        if clock in clocks or (match[2] == "ports" and clock not in pins):
            raise ValueError(f"Duplicate or unpinned clock: {clock}")
        clocks[clock] = 1000.0 / float(match[1])
        lines.append(f"set_frequency {clock} {clocks[clock]:.9g}")
    return "\n".join(lines) + "\n", pins, clocks, pullups


def apply_pullups(netlist, top, pullups):
    """Apply PCF pullups to actual SB_IO parameters, including output pins.

    nextpnr's PCF attributes alone do not configure already-instantiated SB_IO
    cells, nor pullups on output-only inferred cells in the installed 0.9 flow.
    """
    module = netlist["modules"][top]
    next_bit = 1 + max(bit for wire in module["netnames"].values()
                       for bit in wire["bits"] if isinstance(bit, int))
    for name, enabled in pullups.items():
        match = re.fullmatch(r"(.+)\[(\d+)\]", name)
        port_name = match[1] if match else name
        port = module["ports"][port_name]
        index = int(match[2]) - port.get("offset", 0) if match else 0
        bit = port["bits"][index]
        cells = [c for c in module["cells"].values()
                 if c["type"] == "SB_IO" and c["connections"].get("PACKAGE_PIN") == [bit]]
        if len(cells) > 1:
            raise ValueError(f"Multiple IO cells on {name}")
        if cells:
            cells[0]["parameters"]["PULLUP"] = "1" if enabled else "0"
            continue
        if port["direction"] not in ("input", "output"):
            raise ValueError(f"Expected a mapped bidirectional IO on {name}")
        internal = next_bit
        next_bit += 1
        # Split the package pin from the internal signal without changing RTL.
        for cell in module["cells"].values():
            for connection, bits in cell["connections"].items():
                cell["connections"][connection] = [internal if b == bit else b for b in bits]
        for wire_name, wire in module["netnames"].items():
            if wire_name != port_name:
                wire["bits"] = [internal if b == bit else b for b in wire["bits"]]
        cell_name = f"$pcf_pullup${name}"
        if cell_name in module["cells"]:
            raise ValueError(f"Duplicate generated IO cell {cell_name}")
        output = port["direction"] == "output"
        data_port = "D_OUT_0" if output else "D_IN_0"
        module["cells"][cell_name] = {
            "hide_name": 1, "type": "SB_IO",
            "parameters": {"PIN_TYPE": "011001" if output else "000001",
                           "PULLUP": "1" if enabled else "0"},
            "attributes": {},
            "port_directions": {"PACKAGE_PIN": "inout", data_port: "input" if output else "output"},
            "connections": {"PACKAGE_PIN": [bit], data_port: [internal]},
        }


def build(args, target):
    source = args.source / target
    out = args.output / target
    out.mkdir(parents=True, exist_ok=True)
    # A failed rebuild must not leave an old programming image looking current.
    bitstream = out / f"{target}_TOP_bitmap.bin"
    bitstream.unlink(missing_ok=True)
    (out / "manifest.json").unlink(missing_ok=True)
    verilog = sorted(source.glob("*.v"))
    if not verilog:
        raise ValueError(f"No Verilog sources in {source}")
    pcf, pins, clocks, pullups = constraints(source, target)
    (out / "constraints.pcf").write_text(pcf)
    top = f"{target}_TOP"
    script = ["read_verilog " + " ".join(json.dumps(str(p)) for p in verilog)]
    script += [
        f"synth_ice40 -top {top} -run begin:coarse",
        "simplemap t:$tribuf",
        # Resolve flattened aliases before iopadmap finds the tristate drivers.
        "opt_clean",
        f"iopadmap -tinoutpad SB_IO OUTPUT_ENABLE:D_IN_0:D_OUT_0:PACKAGE_PIN "
        f"-toutpad SB_IO OUTPUT_ENABLE:D_OUT_0:PACKAGE_PIN {top}",
        # Combinational input/output, active-high tristate output enable.
        "setparam -set PIN_TYPE 6'b101001 t:SB_IO",
        f"synth_ice40 -top {top} -run coarse: -json design.json",
        "check -assert",
        "select -assert-none t:$_TBUF_ t:$tribuf",
    ]
    (out / "synth.ys").write_text("\n".join(script) + "\n")
    run(["yosys", "-Q", "-T", "-s", "synth.ys"], out / "synthesis.log", out)
    netlist = json.loads((out / "design.json").read_text())
    apply_pullups(netlist, top, pullups)
    (out / "design.json").write_text(json.dumps(netlist, indent=2) + "\n")
    # Recheck the netlist after adding explicit pullups and any required IO cell.
    run(["yosys", "-Q", "-T", "-p",
         f"read_json design.json; read_verilog -lib -overwrite +/ice40/cells_sim.v; hierarchy -check -top {top}; check -assert"],
        out / "netlist-check.log", out)
    design = netlist["modules"][top]
    port_bits = set()
    for name, port in design["ports"].items():
        width = len(port["bits"])
        if width == 1 and not port.get("offset") and not port.get("upto"):
            port_bits.add(name)
        else:
            offset = port.get("offset", 0)
            port_bits.update(f"{name}[{i}]" for i in range(offset, offset + width))
    if port_bits != set(pins):
        raise ValueError(f"Pin constraints differ from ports: missing={port_bits-set(pins)}, extra={set(pins)-port_bits}")

    manifest = {
        "target": target, "device": DEVICES[target], "stage": "synthesis",
        "source": str(source), "clocks_mhz": clocks, "constrained_pins": len(pins),
        "inputs_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in [*verilog, pcf_path(source, target), source / f"{top}.sdc"]},
        "yosys_version": subprocess.check_output(["yosys", "-V"], text=True).strip(),
        "pullups": pullups,
        "hardware_tested": False,
    }
    if args.stage == "all":
        device, package = DEVICES[target]
        run(["nextpnr-ice40", f"--{device}", "--package", package,
             "--json", "design.json", "--pcf", "constraints.pcf", "--freq", "80",
             "--seed", str(args.seed), "--asc", "design.asc", "--report", "timing.json"],
            out / "place-route.log", out)
        run(["icepack", "design.asc", bitstream.name], out / "icepack.log", out)
        if not bitstream.stat().st_size:
            raise RuntimeError("icepack produced an empty bitstream")
        manifest.update(stage="bitstream", seed=args.seed,
                        nextpnr_version=subprocess.check_output(["nextpnr-ice40", "--version"],
                                                               stderr=subprocess.STDOUT, text=True).strip(),
                        bitstream_sha256=hashlib.sha256(bitstream.read_bytes()).hexdigest())
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"{target}: {manifest['stage']} complete; {out}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--target", choices=DEVICES)
    parser.add_argument("--stage", choices=("synth", "all"), default="all")
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    args.source, args.output = args.source.resolve(), args.output.resolve()
    if args.output == args.source or args.source in args.output.parents:
        parser.error("Output must be outside the source tree")
    for tool in (["yosys"] if args.stage == "synth" else ["yosys", "nextpnr-ice40", "icepack"]):
        if not shutil.which(tool):
            parser.error(f"Missing executable: {tool}")
    for target in ([args.target] if args.target else DEVICES):
        build(args, target)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
