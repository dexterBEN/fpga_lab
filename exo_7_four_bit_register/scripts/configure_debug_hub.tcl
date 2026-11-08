# Debug Hub clock configuration for PYNQ-Z2
# FCLK_CLK0 = 50 MHz

set_property C_CLK_INPUT_FREQ_HZ 50000000 \
    [get_debug_cores dbg_hub]

set_property C_ENABLE_CLK_DIVIDER false \
    [get_debug_cores dbg_hub]