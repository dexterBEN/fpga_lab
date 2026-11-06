# ============================================================
# Exercise 7 - 4-bit registers
# GHDL / GTKWave
# ============================================================

GHDL    := ghdl
GTKWAVE := gtkwave

STD       := --std=08
STOP_TIME := 1us

SRC_DIR   := src
SIM_DIR   := sim
WAVE_DIR  := wave
BUILD_DIR := build

PARALLEL_TB := parallel_register_tb
SHIFT_TB    := shift_register_tb
SYSTEM_TB   := register_system_tb

.PHONY: all sim sim-parallel sim-shift sim-system \
        wave-parallel wave-shift wave-system clean help

all: sim

sim: sim-parallel sim-shift sim-system

# ------------------------------------------------------------
# Parallel register
# ------------------------------------------------------------

sim-parallel:
	@mkdir -p $(BUILD_DIR)/parallel $(WAVE_DIR)
	cd $(BUILD_DIR)/parallel && \
	$(GHDL) -a $(STD) ../../$(SRC_DIR)/parallel_register.vhd && \
	$(GHDL) -a $(STD) ../../$(SIM_DIR)/parallel_register_tb.vhd && \
	$(GHDL) -e $(STD) $(PARALLEL_TB) && \
	$(GHDL) -r $(STD) $(PARALLEL_TB) \
		--stop-time=$(STOP_TIME) \
		--wave=../../$(WAVE_DIR)/parallel_register.ghw

# ------------------------------------------------------------
# Shift register
# ------------------------------------------------------------

sim-shift:
	@mkdir -p $(BUILD_DIR)/shift $(WAVE_DIR)
	cd $(BUILD_DIR)/shift && \
	$(GHDL) -a $(STD) ../../$(SRC_DIR)/shift_register.vhd && \
	$(GHDL) -a $(STD) ../../$(SIM_DIR)/shift_register_tb.vhd && \
	$(GHDL) -e $(STD) $(SHIFT_TB) && \
	$(GHDL) -r $(STD) $(SHIFT_TB) \
		--stop-time=$(STOP_TIME) \
		--wave=../../$(WAVE_DIR)/shift_register.ghw

# ------------------------------------------------------------
# Register system
# ------------------------------------------------------------

sim-system:
	@mkdir -p $(BUILD_DIR)/system $(WAVE_DIR)
	cd $(BUILD_DIR)/system && \
	$(GHDL) -a $(STD) ../../$(SRC_DIR)/parallel_register.vhd && \
	$(GHDL) -a $(STD) ../../$(SRC_DIR)/shift_register.vhd && \
	$(GHDL) -a $(STD) ../../$(SRC_DIR)/register_system.vhd && \
	$(GHDL) -a $(STD) ../../$(SIM_DIR)/register_system_tb.vhd && \
	$(GHDL) -e $(STD) $(SYSTEM_TB) && \
	$(GHDL) -r $(STD) $(SYSTEM_TB) \
		--stop-time=$(STOP_TIME) \
		--wave=../../$(WAVE_DIR)/register_system.ghw

# ------------------------------------------------------------
# Open GTKWave
# ------------------------------------------------------------

wave-parallel: sim-parallel
	$(GTKWAVE) $(WAVE_DIR)/parallel_register.ghw

wave-shift: sim-shift
	$(GTKWAVE) $(WAVE_DIR)/shift_register.ghw

wave-system: sim-system
	$(GTKWAVE) $(WAVE_DIR)/register_system.ghw

# ------------------------------------------------------------
# Cleanup
# ------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(WAVE_DIR)/*.ghw

# ------------------------------------------------------------
# Help
# ------------------------------------------------------------

help:
	@echo "Exercise 7 - 4-bit registers"
	@echo ""
	@echo "make sim-parallel   Simulate parallel register"
	@echo "make sim-shift      Simulate shift register"
	@echo "make sim-system     Simulate register system"
	@echo "make sim            Simulate all three modules"
	@echo "make wave-parallel  Open parallel waveform in GTKWave"
	@echo "make wave-shift     Open shift waveform in GTKWave"
	@echo "make wave-system    Open system waveform in GTKWave"
	@echo "make clean          Remove generated simulation files"
	@echo "make help           Show this help"
