# Board for all Zephyr apps
BOARD := lpcxpresso55s69/lpc55s69/cpu0/ns

# Helper function to get current directory
define current_directory
$(realpath $(dir $(lastword $(MAKEFILE_LIST))))
endef

# List all targets
IMAGES := Hypervisor PUF_VM GUEST_VM

# Define which of the above are Zephyr VM's
ZEPHYR_VMS := PUF_VM GUEST_VM

# Passed to Bao HV make
HV_CONFIG := uc1_1
HV_PLATFORM := lpc55s69

# Zephyr configuration
INSTALL_SDK ?= y

HV_MAKE_FLAGS := build_dir=$(current_directory)/build/Hypervisor/build/$(HV_PLATFORM)/$(HV_CONFIG) bin_dir=$(current_directory)/build/Hypervisor/bin/$(HV_PLATFORM)/$(HV_CONFIG) PLATFORM=$(HV_PLATFORM) CONFIG=$(HV_CONFIG)

.PHONY: all update clean build-% flash flash-% install-deps install-deps-% global-deps

#------------------------------------------------------------
# Python venv logic for installing west and python dependencies
#------------------------------------------------------------

# Whether to insist on being inside a venv
USE_VENV ?= 1
VENV_DIR ?= $(current_directory)/.venv

ifeq ($(USE_VENV),1)
ifeq ($(origin VIRTUAL_ENV), undefined)
ifeq ($(wildcard $(VENV_DIR)/bin/activate),)
$(error No active Python venv detected! \
Create one with: `python3 -m venv $(VENV_DIR)` \
Or disable the check: `make USE_VENV=0`)
else
$(error No active Python venv detected! \
Found $(VENV_DIR)/bin/activate — activate it with: `source $(VENV_DIR)/bin/activate` \
Or disable the check: `make USE_VENV=0`)
endif
endif
endif

#------------------------------------------------------------
# Git submodule initialization check
#------------------------------------------------------------

check-submodules:
	@echo ">>> Verifying git submodules are initialized…"
	@missing=$$(git submodule status $(IMAGES) \
	                | awk '/^-/ { print $$2 }'); \
	if [ -n "$$missing" ]; then \
	  echo >&2 "ERROR: these submodules look un­initialized: $$missing"; \
	  echo >&2 "Run: git submodule update --init --recursive"; \
	  exit 1; \
	fi

#------------------------------------------------------------
# Main invokes
#------------------------------------------------------------
# build - build all VM's and Hypervisor with substitutions for VM star address
# flash - flash all binaries onto the board
install-deps: global-deps check-submodules $(patsubst %,install-deps-%,$(ZEPHYR_VMS))
update: $(patsubst %,update-%,$(ZEPHYR_VMS))
build: $(patsubst %,build-%,$(ZEPHYR_VMS)) $(patsubst %,substitute_vm_start-%,$(ZEPHYR_VMS)) build-Hypervisor
flash: $(patsubst %,flash-%,$(ZEPHYR_VMS)) flash-Hypervisor
all: install-deps update build

#------------------------------------------------------------
# Dependencies install
#------------------------------------------------------------

global-deps:
	@pip install west

install-deps-%:
	@cd $* && \
	  west update && \
	  west packages pip --install && \
	  west sdk install --install-dir $(current_directory)/build/zephyr-sdk

#------------------------------------------------------------
# Update
#------------------------------------------------------------
update-Hypervisor:
	@echo ">>> Nothing to be done";

update-%:
	@echo ">>> Running 'west update' in $*";
	@cd $* && west update

#------------------------------------------------------------
# Build
#------------------------------------------------------------

substitute_vm_start-%:
	@raw_addr=$$( \
	    readelf -aW build/$*/zephyr/zephyr.elf \
	      | awk '/__start/ { print $$2 }' \
	); \
	prev_addr=$$( printf "0x%08x" $$((0x$${raw_addr} - 1)) ); \
	echo "$* start is 0x$${raw_addr}, entry will be $$prev_addr"; \
	sed -i -E \
	  "s|(\\.entry = )0x[0-9a-f]+(,\\s*/\\* @SUBST_ENTRY_ADDR:$* \\*/)|\\1$${prev_addr}\\2|" \
	  $(current_directory)/Hypervisor/configs/uc1_1/config.c

build-Hypervisor:
	@echo ">>> Building Hypervisor <<<"
	@mkdir -p build/Hypervisor/build
	@mkdir -p build/Hypervisor/bin
	@ln -snf ../../configs/uc1_1 $(current_directory)/Hypervisor/configs/uc1_1
	$(MAKE) $(HV_MAKE_FLAGS) -C Hypervisor

build-%:
	@echo ">>> Building Zephyr VM: $* <<<"
	@mkdir -p build/$*
	@cd $* && \
	  west build -p always -b $(BOARD) -d $(current_directory)/build/$* application

#------------------------------------------------------------
# Flash
#------------------------------------------------------------
flash-Hypervisor:
	@echo ">>> Flashing Hypervisor <<<"
	@LinkServer flash LPC55S69:LPCXpresso55S69 load $(current_directory)/build/Hypervisor/bin/$(HV_PLATFORM)/$(HV_CONFIG)/crossconhyp.elf

flash-%:
	@echo ">>> Flashing Zephyr VM: $* <<<"
	@LinkServer flash LPC55S69:LPCXpresso55S69 load $(current_directory)/build/$*/zephyr/zephyr.elf

#------------------------------------------------------------
# Clean
#------------------------------------------------------------
clean:
	@echo
	@echo ">>> Cleaning build targets <<<"
	@rm -rf build/GUEST_VM
	@rm -rf build/Hypervisor
	@rm -rf build/PUF_VM
