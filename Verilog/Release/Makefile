SHELL := /bin/bash
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.NOTPARALLEL:
RELEASE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
TOOLCHAIN ?= icecube2
ICECUBE2_ROOT ?= /opt/lscc/iCEcube2.2020.12
SYNPLIFY_PATH ?= $(ICECUBE2_ROOT)/synpbase
PYTHON ?= python3
TCLSH ?= tclsh
ICECUBE2_PRELOAD ?= /usr/lib/i386-linux-gnu/libgcc_s.so.1:/usr/lib/i386-linux-gnu/libstdc++.so.6
BUILD_DIR ?= $(RELEASE_DIR)/build-$(TOOLCHAIN)
BIN_DIR ?= $(RELEASE_DIR)/BINs
CHIPS := $(notdir $(wildcard $(RELEASE_DIR)/Verilog/U*))
export LM_LICENSE_FILE
ifeq ($(TOOLCHAIN),icecube2)
BUILD = $(PYTHON) "$(RELEASE_DIR)/build-tools/build_icecube2.py" --source "$(RELEASE_DIR)/Verilog" --output "$(BUILD_DIR)" --synplify "$(SYNPLIFY_PATH)" --icecube2 "$(ICECUBE2_ROOT)" --tclsh "$(TCLSH)" --preload "$(ICECUBE2_PRELOAD)" --targets
else ifeq ($(TOOLCHAIN),yosys)
BUILD = $(PYTHON) "$(RELEASE_DIR)/build-tools/build_ice40.py" --source "$(RELEASE_DIR)/Verilog" --output "$(BUILD_DIR)" --target
else
$(error TOOLCHAIN must be icecube2 or yosys)
endif
.PHONY: all $(CHIPS) help
all: $(CHIPS)
# Always rebuild: source deletions and toolchain switches cannot reuse stale BINs.
# Export only after that chip completes successfully.
$(CHIPS):
	$(BUILD) $@
	@mkdir -p "$(BIN_DIR)"
	install -m 0644 "$(BUILD_DIR)/$@/$@_TOP_bitmap.bin" "$(BIN_DIR)/$@_TOP_bitmap.bin"
help:
	@echo 'make [TOOLCHAIN=icecube2|yosys] [$(CHIPS)]'
	@echo 'Default: installed /opt/lscc/iCEcube2.2020.12; override ICECUBE2_ROOT or SYNPLIFY_PATH.'
	@echo 'All chip outputs are copied to BINs; intermediates and logs are in build-TOOLCHAIN.'
