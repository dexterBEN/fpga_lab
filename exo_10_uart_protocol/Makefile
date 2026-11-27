# --------------------------------------------------
# GHDL configuration
# --------------------------------------------------

GHDL := ghdl
STD  := --std=08

# --------------------------------------------------
# Directories
# --------------------------------------------------

SRC_DIR   := src
SIM_DIR   := sim
BUILD_DIR := build
WORK_DIR  := $(BUILD_DIR)/ghdl
WAVE_DIR  := $(BUILD_DIR)/waves

GHDL_FLAGS := $(STD) --workdir=$(WORK_DIR)
RUN_FLAGS  := --assert-level=error

# --------------------------------------------------
# RTL sources
# --------------------------------------------------

SOURCES := \
	$(SRC_DIR)/uart_tx.vhd \
	$(SRC_DIR)/uart_rx.vhd \
	$(SRC_DIR)/uart_gpio_bridge.vhd

# --------------------------------------------------
# Testbenches
# --------------------------------------------------

TESTBENCHES := \
	uart_tx_tb \
	uart_tx_robustness_tb \
	uart_rx_tb \
	uart_rx_robustness_tb \
	uart_loopback_tb \
	uart_gpio_bridge_tb

TB_SOURCES := $(addprefix $(SIM_DIR)/,$(addsuffix .vhd,$(TESTBENCHES)))

# Default testbench for waveform generation
TB ?= uart_gpio_bridge_tb

# --------------------------------------------------
# Targets
# --------------------------------------------------

.PHONY: all analyze test clean help dirs
.PHONY: test-loopback-fast test-loopback-slow
.PHONY: wave $(TESTBENCHES)

all: test

# --------------------------------------------------
# Create build directories
# --------------------------------------------------

dirs:
	mkdir -p $(WORK_DIR)
	mkdir -p $(WAVE_DIR)

# --------------------------------------------------
# Analyze RTL and testbench sources
# --------------------------------------------------

analyze: dirs
	$(GHDL) -a $(GHDL_FLAGS) $(SOURCES)
	$(GHDL) -a $(GHDL_FLAGS) $(TB_SOURCES)

# --------------------------------------------------
# Run all tests
# --------------------------------------------------

test: $(TESTBENCHES) test-loopback-fast test-loopback-slow

# --------------------------------------------------
# Run an individual testbench
# --------------------------------------------------

$(TESTBENCHES): analyze
	$(GHDL) -e $(GHDL_FLAGS) $@
	$(GHDL) -r $(GHDL_FLAGS) $@ $(RUN_FLAGS)

# --------------------------------------------------
# Loopback with faster transmitter
# --------------------------------------------------

test-loopback-fast: analyze
	$(GHDL) -e $(GHDL_FLAGS) uart_loopback_tb
	$(GHDL) -r $(GHDL_FLAGS) uart_loopback_tb \
		-gTX_BAUD_RATE=117504 \
		-gRX_BAUD_RATE=115200 \
		$(RUN_FLAGS)

# --------------------------------------------------
# Loopback with slower transmitter
# --------------------------------------------------

test-loopback-slow: analyze
	$(GHDL) -e $(GHDL_FLAGS) uart_loopback_tb
	$(GHDL) -r $(GHDL_FLAGS) uart_loopback_tb \
		-gTX_BAUD_RATE=112896 \
		-gRX_BAUD_RATE=115200 \
		$(RUN_FLAGS)

# --------------------------------------------------
# Generate waveform
# --------------------------------------------------

wave: analyze
	$(GHDL) -e $(GHDL_FLAGS) $(TB)
	$(GHDL) -r $(GHDL_FLAGS) $(TB) \
		$(RUN_FLAGS) \
		--vcd=$(WAVE_DIR)/$(TB).vcd

# --------------------------------------------------
# Clean generated files
# --------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)

# --------------------------------------------------
# Display available commands
# --------------------------------------------------

help:
	@echo "Available targets:"
	@echo "  make analyze              Analyze all sources"
	@echo "  make test                 Run all tests"
	@echo "  make <testbench>          Run a specific testbench"
	@echo "  make test-loopback-fast   Run loopback at +2%"
	@echo "  make test-loopback-slow   Run loopback at -2%"
	@echo "  make wave TB=<testbench>  Generate VCD waveform"
	@echo "  make clean                Remove build files"
	@echo "  make help                 Display available commands"