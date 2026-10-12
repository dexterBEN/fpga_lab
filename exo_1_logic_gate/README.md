# Exercise 1 — AND Logic Gate

## Goal

Create a real two-input combinational function:

```text
SW0 ─────┐
         ├── AND ───> LED0
SW1 ─────┘
```

The LED must turn on only when **SW0 = 1 and SW1 = 1**.

## Concepts Covered

- multi-input combinational logic,
- VHDL `and` operator,
- truth tables,
- synthesis to a LUT,
- distinction between functional description and physical implementation.

## VHDL

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity logic_gate is
    Port (
        sw0  : in  STD_LOGIC;
        sw1  : in  STD_LOGIC;
        led0 : out STD_LOGIC
    );
end logic_gate;

architecture logic_gate_arch of logic_gate is
begin
    led0 <= sw0 and sw1;
end logic_gate_arch;
```

## Truth Table

| SW0 | SW1 | LED0 |
|---:|---:|---:|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

## What Vivado Synthesizes

This time, synthesis shows a **LUT2**:

```text
sw0 → IBUF ──┐
             ├── LUT2 ──> OBUF ──> led0
sw1 → IBUF ──┘
```

![LUT2 synthesized for the AND gate](assets/exo1_lut2_schematic.png)

A LUT is not a dedicated physical “AND gate” in the sense of a discrete logic component. It is configured to produce the required truth table.

## Physical Mapping

```text
sw0  → SW0  → M20
sw1  → SW1  → M19
led0 → LED0 → R14
```

All using `LVCMOS33`.

![I/O Ports view for Exercise 1](assets/exo1_io_ports.png)

## Hardware Validation

Test all four combinations of `SW0` and `SW1`. The LED should only turn on for `11`.

## Simple Extensions

Without changing the project structure, replace:

```vhdl
led0 <= sw0 and sw1;
```

with:

```vhdl
led0 <= sw0 or sw1;
```

or:

```vhdl
led0 <= sw0 xor sw1;
```

Then compare the truth tables and the synthesized LUTs.
