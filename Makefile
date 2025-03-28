BOARD?=vcu108
VIVADO_VERSION?=$(shell ./scripts/get-vivado-version.sh)
TOP_LEVEL=mkTop_vcu108
BUILD_DIR=build

# -------------------------
# Miscellaneous targets
# -------------------------

.PHONY: all
all: build.$(BOARD)

.PHONY: dirs
dirs:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/info
	@mkdir -p $(BUILD_DIR)/verilog
	@mkdir -p $(BUILD_DIR)/bluespec
	@mkdir -p $(BUILD_DIR)/sim

.PHONY: clean
clean:
	rm -fR build

# -------------------------
# Generate Verilog using bsc
# -------------------------

BSC_SUPPRESSED_WARNINGS=G0046
BSC_FLAGS=+RTS -Ksize -RTS\
  -vdir $(BUILD_DIR)/verilog \
  -bdir $(BUILD_DIR)/bluespec \
  -simdir $(BUILD_DIR)/sim \
  -info-dir $(BUILD_DIR)/info \
  -remove-dollar \
  --aggressive-conditions --show-schedule \
  -suppress-warnings $(BSC_SUPPRESSED_WARNINGS) \
  -p +:%/Libraries/FPGA/Xilinx:src \
  -verilog

SRCS=$(wildcard src/*.bsv)
TOP_LEVEL_VERILOG_FILE=$(BUILD_DIR)/verilog/$(TOP_LEVEL).v

.PHONY: bsc
bsc: $(TOP_LEVEL_VERILOG_FILE)


$(TOP_LEVEL_VERILOG_FILE): $(BUILD_DIR)/verilog/%.v: src/%.bsv $(SRCS) | dirs
	bsc $(BSC_FLAGS) -g $* -u src/$*.bsv

# -------------------------
# Test targets
# -------------------------

.PHONY: uart-tx-test
uart-tx-test: | dirs
	bsc $(BSC_FLAGS) -g mkUartTxTest -u src/mkUartTx.bsv

.PHONY: uart-rx-test
uart-rx-test: | dirs
	bsc $(BSC_FLAGS) -g mkUartRxTest -u src/mkUartRx.bsv

# -------------------------
# Generate bitstreams from Verilog
# -------------------------

SUPPORTED_BOARDS:=vcu108
BUILD_TARGETS:=$(foreach board, $(SUPPORTED_BOARDS), build.$(board))
FLASH_TARGETS:=$(foreach board, $(SUPPORTED_BOARDS), flash.$(board))
BITSTREAM_TARGETS:=$(foreach board, $(SUPPORTED_BOARDS), $(BUILD_DIR)/$(board)/final.bit)


.PHONY: $(BUILD_TARGETS)
$(BUILD_TARGETS): build.%: $(BUILD_DIR)/%/final.bit


.PHONY: $(FLASH_TARGETS)
$(FLASH_TARGETS): flash.%:
	@echo "Attempting to flash $(BUILD_DIR)/$*/final.bit without re-synthesizing..."
	fpgajtag $(BUILD_DIR)/$*/final.bit

$(BITSTREAM_TARGETS): $(BUILD_DIR)/%/final.bit: $(TOP_LEVEL_VERILOG_FILE) tcl/build.tcl
	BOARD=$(BOARD) VIVADO_VERSION=$(VIVADO_VERSION) TOP_LEVEL=$(TOP_LEVEL) \
	  vivado -mode batch -source tcl/build.tcl
