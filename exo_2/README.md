# Exercise 2 — D Flip-Flop / Register with a Real Clock

## Initial Goal

The original idea was to use:

```text
SW0  = D
BTN0 = CLK
LED0 = Q
```

with:

```vhdl
if rising_edge(btn0) then
    led0 <= sw0;
end if;
```

This attempt was pedagogically useful because it revealed an important rule: **an FPGA clock is not just any ordinary input signal**.

## First Version

![First VHDL attempt](assets/exo2_first_attempt_vhdl.png)

Synthesis correctly created an `FDRE` flip-flop:

```text
BTN0 → IBUF → BUFG → C
SW0  → IBUF ──────→ D
                    FDRE → Q → OBUF → LED0
```

![FDRE with BTN0 used as clock](assets/exo2_fdre_button_clock.png)

However, implementation failed with:

```text
[Place 30-574] Poor placement for routing between an IO pin and BUFG
```

![Implementation error](assets/exo2_implementation_error.png)

### Why?

`BTN0` is a regular I/O. Vivado recognized `btn0` as a clock and inserted a `BUFG`, but the button pin is not a dedicated clock input suitable for that routing path.

Vivado suggested an override:

```xdc
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets btn0_IBUF]
```

but this workaround was intentionally avoided.

## Corrected Architecture

We now use the PYNQ-Z2's real **125 MHz clock** and use `BTN0` as a **Clock Enable**.

```text
                     ┌─────────────┐
CLK 125 MHz ────────>│ C           │
SW0 ────────────────>│ D        Q  │────> LED0
BTN0 ───────────────>│ CE          │
                     │    FDRE     │
                     └─────────────┘
```

## Corrected VHDL

```vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity flip_flop is
    Port (
        clk  : in  STD_LOGIC;
        sw0  : in  STD_LOGIC;
        btn0 : in  STD_LOGIC;
        led0 : out STD_LOGIC
    );
end flip_flop;

architecture flip_flop_arch of flip_flop is
begin
    flip_flop_d : process(clk)
    begin
        if rising_edge(clk) then
            if btn0 = '1' then
                led0 <= sw0;
            end if;
        end if;
    end process flip_flop_d;
end flip_flop_arch;
```

Synthesis automatically recognizes `if btn0 = '1'` as a **Clock Enable** and maps it directly to the `CE` input of the FDRE.

![FDRE with real clock and CE](assets/exo2_fdre_clock_enable.png)

## Physical Mapping

```text
clk  → H16  (125 MHz clock)
btn0 → D19  (BTN0)
sw0  → M20  (SW0)
led0 → R14  (LED0)
```

All using `LVCMOS33`.

XDC:

```xdc
set_property PACKAGE_PIN D19 [get_ports btn0]
set_property IOSTANDARD LVCMOS33 [get_ports btn0]

set_property PACKAGE_PIN R14 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]

set_property PACKAGE_PIN M20 [get_ports sw0]
set_property IOSTANDARD LVCMOS33 [get_ports sw0]

set_property PACKAGE_PIN H16 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

create_clock -period 8.000 [get_ports clk]
```

## Observed Behavior

```text
SW0 changes by itself
    ↓
LED0 keeps its current state

BTN0 = 1
    ↓
on every clk rising edge, LED0 reloads SW0
```

Because the clock runs at 125 MHz, while BTN0 is held down the register can reload `SW0` every cycle.

## Important Nuance

This version does not yet implement “one button press = one capture.” To achieve that later, we will need to:

- synchronize the button,
- handle mechanical bounce (debounce),
- detect an edge on BTN0,
- generate a one-clock-cycle pulse.

## Key Takeaway

This exercise introduces the essential distinction between:

```text
data / control signal
```

and:

```text
clock signal
```

A real clock should be routed through the FPGA's dedicated clocking resources.
