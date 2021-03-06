# Leave at the top
THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

# Application target name
TARGET = JN516xSniffer

# Default device type
JENNIC_CHIP ?= JN5169

# Default SDK
JENNIC_SDK ?= JN-SW-4163

##############################################################################
# Select the network stack (e.g. MAC, ZBPRO)

JENNIC_STACK ?= None

##############################################################################
# Debug options define DEBUG for HW debug
#DEBUG ?=HW
#
# Define which UART to use for debug
DEBUG_PORT ?= UART1

##############################################################################
# Define TRACE to use with DBG module
TRACE ?=1

##############################################################################
# Path definitions

SDK_BASE_DIR       ?= $(abspath ../../sdk/$(JENNIC_SDK)/)
SRC_DIR             = src
OBJ_DIR             = debug
#TOOL_COMMON_BASE_DIR= /usr/local
TOOL_COMMON_BASE_DIR= $(abspath ../../sdk/Tools/)
#TOOL_COMMON_BASE_DIR= $(HOME)/bin
TOOLCHAIN_PATH      = 
#TOOLCHAIN_PATH      = ba-elf-gcc-4.7.4
# Needs patch of sdk/JN-SW-4163/Chip/Common/Build/config_ba2.mk to not replace this value

##############################################################################
# Application Source files

APPSRC += main.c crc-ccitt.c UartBuffered.c Queue.c Printf.c

# Specify additional Component libraries
APPLIBS += MMAC
APPLIBS += DBG

##############################################################################
# Standard Application header search paths

INCFLAGS += -I$(COMPONENTS_BASE_DIR)/MicroSpecific/Include
INCFLAGS += -Iinc

##############################################################################
##############################################################################
# Configure for the selected chip or chip family

include $(SDK_BASE_DIR)/Chip/Common/Build/config.mk
include $(SDK_BASE_DIR)/Platform/Common/Build/Config.mk
include $(SDK_BASE_DIR)/Stack/Common/Build/config.mk

###TODO: change this
INCFLAGS += -I$(TOOL_COMMON_BASE_DIR)/$(TOOLCHAIN_PATH)/include
LDFLAGS += -fno-lto
INCFLAGS += -I$(SDK_BASE_DIR)/Components/Xcv/Include

##############################################################################

APPOBJS = $(addprefix $(OBJ_DIR)/,$(APPSRC:.c=.o))
APPSRCS = $(addprefix $(SRC_DIR)/,$(APPSRC))

##############################################################################
# Application dynamic dependencies

APPDEPS = $(APPOBJS:.o=.d)

#########################################################################
# Linker

# Add application libraries before chip specific libraries to linker so
# symbols are resolved correctly (i.e. ordering is significant for GCC)

LDLIBS := $(addsuffix _$(JENNIC_CHIP_FAMILY),$(APPLIBS)) $(LDLIBS)

#########################################################################
# Dependency rules

.PHONY: all clean
# Path to directories containing application source 
#vpath % $(APP_SRC_DIR)

all: $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).bin $(THIS_MAKEFILE)

-include $(APPDEPS)
$(OBJ_DIR)/%.d:
	rm -f $(OBJ_DIR)/$*.o

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.S $(OBJ_DIR)/.dirok $(THIS_MAKEFILE)
	$(info Assembling $< ...)
	$(CC) -c -o $@ $(CFLAGS) $(INCFLAGS) $< -MMD -MF $(OBJ_DIR)/$*.d -MP
	@echo

$(OBJ_DIR)/%.i: $(SRC_DIR)/%.c $(OBJ_DIR)/.dirok $(THIS_MAKEFILE)
	$(info Compiling $< ...)
	$(CC) -E -o $@ $(CFLAGS) $(INCFLAGS) $<
	@echo

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c $(OBJ_DIR)/.dirok $(THIS_MAKEFILE)
	$(info Compiling $< ...)
	$(CC) -c -o $@ $(CFLAGS) $(INCFLAGS) $< -MMD -MF $(OBJ_DIR)/$*.d -MP
	@echo

$(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).elf: $(APPOBJS) $(addsuffix _$(JENNIC_CHIP_FAMILY).a,$(addprefix $(COMPONENTS_BASE_DIR)/Library/lib,$(APPLIBS))) $(THIS_MAKEFILE)
	$(info Linking $@ ...)
	$(CC) -Wl,--gc-sections -Wl,-u_AppColdStart -Wl,-u_AppWarmStart $(LDFLAGS) -T$(LINKCMD) -o $@ $(APPOBJS) -Wl,--start-group  $(addprefix -l,$(LDLIBS)) -Wl,--end-group -Wl,-Map,$(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).map 
	${SIZE} $@
	@echo

$(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).dis: $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).elf
	$(info Disassembling $< to $@ ...)
	$(OBJDUMP) -S $< > $@
	@echo

$(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).bin: $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)$(BIN_SUFFIX).elf $(THIS_MAKEFILE)
	$(info Generating binary ...)
	$(OBJCOPY) -S -O binary $< $@

$(OBJ_DIR)/.dirok: $(THIS_MAKEFILE)
	echo $@
	mkdir -p $(dir $@)
	touch $@

#########################################################################

clean:
#	rm -f $(APPOBJS) $(APPDEPS) $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)*.bin $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)*.elf $(OBJ_DIR)/$(TARGET)_$(JENNIC_CHIP)*.map
	rm -fR $(OBJ_DIR)

#########################################################################
