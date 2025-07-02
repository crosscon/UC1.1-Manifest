# Board for all Zephyr apps
BOARD := lpcxpresso55s69/lpc55s69/cpu0

# Helper function to get current directory
define current_directory
$(realpath $(dir $(lastword $(MAKEFILE_LIST))))
endef

# List all targets
IMAGES := Hypervisor PUF_VM GUEST_VM ENROLLMENT_APP

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
	@echo
	@echo ">>> Verifying git submodules are initialized…"
	@missing=$$(git submodule status $(IMAGES) \
	                | awk '/^-/ { print $$2 }'); \
	if [ -n "$$missing" ]; then \
	  echo >&2 "ERROR: these submodules look un­initialized: $$missing"; \
	  echo >&2 "Run: git submodule update --init --recursive"; \
	  echo >&2 "To use https instead of ssh run:"; \
	  echo >&2 "git -c url."https://github.com/".insteadOf="git@github.com:" submodule update --init --recursive"; \
	  exit 1; \
	fi

#------------------------------------------------------------
# Main invokes
#------------------------------------------------------------

install-deps: global-deps check-submodules $(patsubst %,install-deps-%,$(ZEPHYR_VMS)) install-deps-ENROLLMENT_APP
update: $(patsubst %,update-%,$(ZEPHYR_VMS)) update-ENROLLMENT_APP
enroll: build-ENROLLMENT_APP flash-ENROLLMENT_APP get_enrollment_data
build: $(patsubst %,build-%,$(ZEPHYR_VMS)) substitute_enrollment_data $(patsubst %,substitute_vm_start-%,$(ZEPHYR_VMS)) build-Hypervisor
flash: $(patsubst %,flash-%,$(ZEPHYR_VMS)) flash-Hypervisor
all: install-deps update enroll build flash

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
	@echo
	@echo ">>> Nothing to be done";

update-%:
	@echo
	@echo ">>> Running 'west update' in $*";
	@cd $* && west update

#------------------------------------------------------------
# Enrollment logic
#------------------------------------------------------------

build-ENROLLMENT_APP:
	@echo
	@echo ">>> Building Enrollment App <<<"
	@mkdir -p build/ENROLLMENT_APP
	@cd ENROLLMENT_APP && \
	  west build -p always -b $(BOARD) -d $(current_directory)/build/ENROLLMENT_APP application

flash-ENROLLMENT_APP:
	@echo
	@echo ">>> Flashing Enrollment App <<<"
	@LinkServer flash LPC55S69:LPCXpresso55S69 load $(current_directory)/build/ENROLLMENT_APP/zephyr/zephyr.elf

get_enrollment_data:
	@{ \
		if ! command -v tio >/dev/null 2>&1; then \
			echo >&2 "'tio' is not installed or not in PATH."; \
			read -p "Do you want to use the fallback script (y/n)? " fallback; \
			[ "$$fallback" = "y" ] || { echo "Aborted."; exit 1; }; \
			lua scripts/serial_capture/fallback_capture_enroll.lua || { echo "Fallback failed."; exit 1; }; \
			mkdir -p build/enrollment_data; \
			mv -v /tmp/activation_code.* /tmp/intrinsic_key.* $(current_directory)/build/enrollment_data/; \
			echo "Output moved to build/enrollment_data/"; \
			exit 0; \
		fi; \
		\
		tio_version=$$(tio -v | head -n 1 | sed -E 's/[^0-9]*([0-9]+\.[0-9]+).*/\1/'); \
		if [ "$$tio_version" != "3.8" ]; then \
			echo >&2 "'tio' version 3.8 is required, but found $$tio_version."; \
			read -p "Do you want to use the fallback script (y/n)? " fallback; \
			[ "$$fallback" = "y" ] || { echo "Aborted."; exit 1; }; \
			lua scripts/serial_capture/fallback_capture_enroll.lua || { echo "Fallback failed."; exit 1; }; \
			mkdir -p build/enrollment_data; \
			mv -v /tmp/activation_code.* /tmp/intrinsic_key.* $(current_directory)/build/enrollment_data/; \
			echo "Output moved to build/enrollment_data/"; \
			exit 0; \
		fi; \
		\
		echo; \
		echo ">>> Attempting to auto-detect CMSIS-DAP serial device..."; \
		serial_dev=$$( \
			ls /dev/ttyACM* 2>/dev/null | while read dev; do \
				udevadm info -q property -n $$dev | grep -q "ID_MODEL=LPC-LINK2_CMSIS-DAP" && echo $$dev && break; \
			done \
		); \
		if [ -z "$$serial_dev" ]; then \
			echo "Could not auto-detect CMSIS-DAP device."; \
			read -p "Please enter the serial port (e.g. /dev/ttyACM0): " serial_dev; \
		fi; \
		echo "Using serial port: $$serial_dev"; \
		echo; \
		printf "\033[1;32m>>> Please press reset button on your board <<<\033[0m\n"; \
		printf "(ctrl-t q to abort)\n"; \
		tio $$serial_dev --script-file=./scripts/serial_capture/capture_enroll.lua > /dev/null; \
		if [ $$? -ne 0 ]; then \
			echo "'scripts/serial_capture/capture_enroll.lua' script failed."; \
			read -p "Do you want to use the fallback script (y/n)? " fallback; \
			[ "$$fallback" = "y" ] || { echo "Aborted."; exit 1; }; \
			lua scripts/serial_capture/fallback_capture_enroll.lua || { echo "Fallback failed."; exit 1; }; \
		fi; \
		\
		mkdir -p build/enrollment_data; \
		mv -v /tmp/activation_code.* /tmp/intrinsic_key.* $(current_directory)/build/enrollment_data/; \
		echo "Output moved to build/enrollment_data/"; \
	}

#------------------------------------------------------------
# Build
#------------------------------------------------------------

substitute_vm_start-%:
	@ln -snf $(current_directory)/configs/uc1_1 $(current_directory)/Hypervisor/configs/uc1_1
	@raw_addr=$$( \
	    readelf -aW build/$*/zephyr/zephyr.elf \
	      | awk '/__start/ { print $$2 }' \
	); \
	prev_addr=$$( printf "0x%08x" $$((0x$${raw_addr} - 1)) ); \
	echo "$* start is 0x$${raw_addr}, entry will be $$prev_addr"; \
	sed -i -E \
	  "s|(\\.entry = )0x[0-9a-f]+(,\\s*/\\* @SUBST_ENTRY_ADDR:$* \\*/)|\\1$${prev_addr}\\2|" \
	  $(current_directory)/Hypervisor/configs/uc1_1/config.c

substitute_enrollment_data:
	@echo
	@echo ">>> Substituting Enrollment Data in PUF_VM <<<"
	@proceed=true; \
	if [ ! -f $(current_directory)/build/enrollment_data/activation_code.bin ] || [ ! -f $(current_directory)/build/enrollment_data/intrinsic_key.bin ]; then \
		echo "One or both required files are missing:"; \
		[ ! -f $(current_directory)/build/enrollment_data/activation_code.bin ] && echo " - build/enrollment_data/activation_code.bin"; \
		[ ! -f $(current_directory)/build/enrollment_data/intrinsic_key.bin ] && echo " - build/enrollment_data/intrinsic_key.bin"; \
		read -p "Continue anyway and skip patching? (y/n): " ans; \
		if [ "$$ans" != "y" ]; then \
			echo "Aborting."; exit 1; \
		else \
			proceed=false; \
		fi; \
	fi; \
	if $$proceed; then \
		echo; \
		echo ">>> Pre-patch <<<"; \
		arm-none-eabi-objdump -s -j .activation_code $(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
		arm-none-eabi-objcopy -v --update-section .activation_code=$(current_directory)/build/enrollment_data/activation_code.bin \
			$(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
		echo; \
		echo ">>> Post-patch <<<"; \
		arm-none-eabi-objdump -s -j .activation_code $(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
		echo; \
		echo ">>> Pre-patch <<<"; \
		arm-none-eabi-objdump -s -j .key_code $(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
		arm-none-eabi-objcopy -v --update-section .key_code=$(current_directory)/build/enrollment_data/intrinsic_key.bin \
			$(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
		echo; \
		echo ">>> Post-patch <<<"; \
		arm-none-eabi-objdump -s -j .key_code $(current_directory)/build/PUF_VM/zephyr/zephyr.elf; \
	else \
		echo; \
		echo ">>> Skipping patching steps <<<"; \
	fi

build-Hypervisor:
	@echo
	@echo ">>> Building Hypervisor <<<"
	@mkdir -p build/Hypervisor/build
	@mkdir -p build/Hypervisor/bin
	$(MAKE) $(HV_MAKE_FLAGS) -C Hypervisor

build-%:
	@echo
	@echo ">>> Building Zephyr VM: $* <<<"
	@mkdir -p build/$*
	@cd $* && \
	  west build -p always -b $(BOARD)/ns -d $(current_directory)/build/$* application

#------------------------------------------------------------
# MCU Secure Provisioning Tool
#------------------------------------------------------------

provision-docker:
	@xhost +local:docker
	@docker build -t secure_provision scripts/mcu_secure_provision/
	@docker rm -f secure_provision_container 2>/dev/null || true
	@sh -c '\
		docker run --rm -d --name secure_provision_container --privileged \
		-e DISPLAY=$$DISPLAY \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v $$(pwd)/build:/work/build \
		secure_provision tail -f /dev/null; \
		docker exec -it secure_provision_container securep > /dev/null 2>&1'
	@docker cp secure_provision_container:/root/secure_provisioning0/bootable_images/crossconhyp.bin /tmp/crossconhyp_signed.bin
	@xhost -local:docker'

#------------------------------------------------------------
# Flash
#------------------------------------------------------------
flash-Hypervisor:
	@echo
	@echo ">>> Flashing Hypervisor <<<"
	@LinkServer flash LPC55S69:LPCXpresso55S69 load $(current_directory)/build/Hypervisor/bin/$(HV_PLATFORM)/$(HV_CONFIG)/crossconhyp_signed.bin:0x10000000

flash-%:
	@echo
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
	@rm -rf build/ENROLLMENT_APP
