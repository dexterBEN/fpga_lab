# Exercise 0 — Switch → LED

## Goal

Build the smallest useful FPGA design possible: **LED0 directly reflects the state of SW0**.

```text
SW0 ─────────────> LED0
```

This exercise is mainly about learning the complete Vivado flow rather than implementing complex logic.

## Concepts Covered

- creating an RTL project,
- selecting `xc7z020clg400-1`,
- VHDL entity / architecture,
- `in` / `out` ports,
- combinational logic,
- synthesis,
- I/O buffers (`IBUF`, `OBUF`),
- XDC constraints,
- implementation / bitstream / device programming.

## VHDL

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity switch_button is
    Port (
        sw  : in  STD_LOGIC;
        led : out STD_LOGIC
    );
end switch_button;

architecture Behavioral of switch_button is
begin
    led <= sw;
end Behavioral;
```

The line:

```vhdl
led <= sw;
```

describes a permanent combinational connection, not a D flip-flop.

```text
led(t) = sw(t)
```

## What Synthesis Shows

Vivado essentially synthesizes an input-to-output path with buffers:

```text
sw → IBUF ─────────────→ OBUF → led
```

![Synthesized design for Exercise 0](assets/exo0_synthesized_design.png)

There is:

- no clock,
- no register,
- no flip-flop,
- no memory.

## Physical Mapping

```text
sw  → SW0  → M20
led → LED0 → R14
```

using `LVCMOS33`.

Example XDC:

```xdc
set_property PACKAGE_PIN M20 [get_ports sw]
set_property IOSTANDARD LVCMOS33 [get_ports sw]

set_property PACKAGE_PIN R14 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
```

The I/O Ports view can also be used to configure this mapping graphically:

![I/O Ports for Exercise 0](assets/exo0_io_ports.png)

## Hardware Validation

Expected behavior:

| SW0 | LED0 |
|---:|---:|
| 0 | off |
| 1 | on |

Complete signal path:

```text
Physical SW0
   ↓
M20
   ↓
VHDL port sw
   ↓
led <= sw
   ↓
VHDL port led
   ↓
R14
   ↓
Physical LED0
```

## Key Takeaway

This exercise shows that an FPGA design begins with a **hardware description**, which then has to be connected to real hardware through XDC constraints.
