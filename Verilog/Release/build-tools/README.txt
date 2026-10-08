Release build
=============
Run make in the parent Release directory to synthesize, place, route, and
export every chip into BINs/Uxxx_TOP_bitmap.bin using the installed patched
/opt/lscc/iCEcube2.2020.12. Run make TOOLCHAIN=yosys for the open-source flow.
Individual chip targets are supported (for example make U111).
Use make -k to attempt all chips even if one fails.

Keep Makefile and build-tools together with Verilog/; no parent repository
helpers or files under ~/lattice/synplify-patched are required. Python 3 and
Tcl are required for the vendor flow. Yosys additionally requires nextpnr-ice40
and icepack. Override ICECUBE2_ROOT, SYNPLIFY_PATH, BUILD_DIR or BIN_DIR as needed.

Build intermediates and logs are separated by toolchain. Every invocation
rebuilds selected chips. A BINs image is replaced only after its chip succeeds;
failed chips retain the previous BINs image, so always check make's exit code.
Successful Yosys builds also replace those BINs images.

The vendor helper creates local Bash-compatible shell launchers referencing
the installed Synplify binaries. This fixes vendor scripts that declare sh
while using Bash syntax, without modifying the installed scripts.
