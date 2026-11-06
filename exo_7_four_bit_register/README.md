# Exercise 7 — Four-Bit Registers in VHDL

**FPGA Lab · Technical report and learning summary**  
**Target board:** PYNQ-Z2 (Zynq-7020, `xc7z020clg400-1`)  
**Toolchain:** GHDL (VHDL-2008 simulation), VaporView (VS Code waveform inspection), Vivado 2024.1 (synthesis, implementation and timing)  
**Report date:** 6 November 2026  
**Validation scope:** RTL simulation and Vivado design analysis; **no on-board functional test**

## 1. Purpose and scope

The purpose of this exercise is to revisit **sequential digital logic** by implementing and examining two basic four-bit storage circuits:

1. A **parallel register** with a clock enable and asynchronous active-high reset.
2. A **serial-in, parallel-out (SIPO) shift register** with a shift enable and the same reset convention.

A third, lightweight `register_system` module composes both registers and multiplexes their outputs. The focus is on how VHDL describes clocked hardware, how a testbench proves specified behaviors, and what Vivado actually synthesizes.

The earlier AXI GPIO / Zynq Processing System / Jupyter Notebook integration was deliberately **removed from the core exercise**. Those topics are valuable but represent a separate PS–PL integration project. Here, simulation is the primary functional verification method, complemented by FPGA synthesis and timing analysis.

## 2. Project structure

The relevant, hand-maintained files are organized as follows; the Vivado-generated folders are omitted:

```text
exo_7_four_bit_register/
├── src/
│   ├── parallel_register.vhd
│   ├── shift_register.vhd
│   └── register_system.vhd
├── sim/
│   ├── parallel_register_tb.vhd
│   ├── shift_register_tb.vhd
│   └── register_system_tb.vhd
├── constraints/
│   └── parallel_register.xdc   # shared clock constraint in the tested project
└── exo_7_four_bit_register.xpr
```

> The XDC filename still says `parallel_register`, although its `create_clock` constraint is also applicable to `shift_register` and `register_system`, because all expose a port named `clk`. Renaming it to `register_clock.xdc` would improve clarity (update the Vivado project reference if doing so).

## 3. Design fundamentals

### 3.1 Parallel register (4 bits)

```text
                  +-----------------------------+
        d[3:0] -->| D[3:0]               Q[3:0] |--> parallel_q[3:0]
          load -->| CE         4 × D flip-flops   |
           clk -->| CLK                         |
         reset -->| asynchronous clear          |
                  +-----------------------------+
```

The corresponding RTL is based on:

```vhdl
process (clk, reset)
begin
    if reset = '1' then
        q <= (others => '0');
    elsif rising_edge(clk) then
        if enable = '1' then
            q <= d;
        end if;
    end if;
end process;
```

- `reset = '1'`: clears the four stored bits **asynchronously**, independent of the clock.
- Rising edge and `enable = '1'`: captures all four inputs together.
- Rising edge and `enable = '0'`: retains the previously stored value.
- No assignment in the disabled clocked branch means flip-flop state retention, **not** a combinational latch.

Vivado mapped the parallel register to **four `FDCE` primitives**, which include clock (`C`), clock enable (`CE`), asynchronous clear (`CLR`), data (`D`) and output (`Q`). External `IBUF`/`OBUF` cells and a clock `BUFG` were also visible in the standalone implementation schematic.

![Parallel register mapped to FDCE primitives](assets/parallel_fdce_schematic.png)

*Figure 1 — Vivado schematic of the standalone parallel register. Source: screenshot supplied during the exercise.*

### 3.2 SIPO shift register (4 bits)

```text
 serial_in ---> [D FF0 Q] ---> [D FF1 Q] ---> [D FF2 Q] ---> [D FF3 Q]
                  |              |              |              |
                 q(0)           q(1)           q(2)           q(3)

      Common clock: clk       Shift enable: shift
      Common asynchronous active-high clear: reset
```

The key VHDL operation is:

```vhdl
if shift = '1' then
    stored <= stored(2 downto 0) & serial_in;
end if;
```

On each rising clock edge with `shift = '1'`, the incoming serial bit enters `stored(0)`, while each previous bit moves toward the most-significant position. The prior `stored(3)` bit is discarded. With `shift = '0'`, the complete word is retained. As in the parallel register, the asynchronous `reset` clears storage without waiting for a rising edge.

Example, starting from `0000`:

| Rising edge | `serial_in` | `q[3:0]` |
|---:|:---:|:---:|
| Reset | — | `0000` |
| 1 | 1 | `0001` |
| 2 | 0 | `0010` |
| 3 | 1 | `0101` |
| 4 | 1 | `1011` |

![Shift register implementation](assets/shift_implemented_schematic.png)

*Figure 2 — Standalone shift-register implementation. The physical optimization view contained cells with `_lopt_replica` suffixes; these should not be confused with additional architectural storage bits.*

### 3.3 Top-level register system

The `register_system.vhd` top-level instantiates the registers in parallel and uses `mode` **only** to select which stored word appears at the output:

```text
                           +-----------------------+
 d[3:0] ------------------>| parallel_register     |--- parallel_q[3:0] --+
 load -------------------->| enable                |                       |
                          +-----------------------+                       |
                                                                          +--[ 2:1 MUX ]--> q[3:0]
                          +-----------------------+                       |      ^
 serial_in -------------->| shift_register        |--- shift_q[3:0] -----+      |
 shift ------------------>| shift enable          |                            mode
                          +-----------------------+

 clk ---------------------> both register instances
 reset -------------------> both register instances
```

The selection is combinational:

```vhdl
q <= parallel_q when mode = '0' else shift_q;
```

Therefore changing `mode` can change `q` **between** clock edges; it does **not** enable, disable or reset either register. `load` and `shift` are independent, so both registers can update on the same rising edge even though only one is visible through `q` at any moment.

The Boolean function for each output bit is:

```text
q[i] = (NOT mode AND parallel_q[i]) OR (mode AND shift_q[i])
```

This illustrates how a sequential-storage exercise builds on the combinational multiplexers studied in Exercise 5.

![Register system hierarchy](assets/system_hierarchy_schematic.png)

*Figure 3 — Top-level system hierarchy and connectivity in Vivado.*

![Register system synthesized detail](assets/system_synthesized_schematic.png)

*Figure 4 — Expanded synthesized netlist: 4 parallel flip-flops, 4 shift flip-flops and combinational selection logic visible as four `LUT3` symbols.*

## 4. RTL functional verification

### 4.1 Testbench strategy

The `register_system_tb.vhd` testbench instantiates the **public top-level interface**, rather than probing internal storage signals. It uses:

- A 10 ns simulated clock (`CLK_PERIOD = 10 ns`). This is a **testbench stimulus period** and is independent of the 8 ns Vivado timing constraint.
- A `cycle(...)` helper: prepares inputs at a falling edge, waits for a rising edge, and checks the selected output.
- A `check_outputs(...)` helper: toggles `mode` and checks **both** register values through the same public `q[3:0]` port, including their retention.
- Self-checking VHDL `assert` statements with `severity failure` on mismatch.
- A 500 ns watchdog that fails if the testbench does not complete.

### 4.2 Six tested behaviors

| # | Testbench scenario | Verified intention |
|---:|---|---|
| 1 | Common asynchronous reset | Both registers clear before another rising edge is required |
| 2 | Independent commands | Each register may update while the other is selected at the output |
| 3 | Simultaneous `load` and `shift` | Both operations take place on one rising edge |
| 4 | Hold with changing inputs | Both stored words remain unchanged when both enables are low |
| 5 | Reset between rising edges | Both nonzero states are cleared asynchronously |
| 6 | Reset priority | An asserted reset overrides active operations; updates resume after reset release and a subsequent rising edge |

### 4.3 Executed GHDL commands and result

From the exercise directory in the development container:

```bash
ghdl -a --std=08 \
  src/parallel_register.vhd \
  src/shift_register.vhd \
  src/register_system.vhd \
  sim/register_system_tb.vhd

ghdl -e --std=08 register_system_tb

ghdl -r --std=08 register_system_tb \
  --wave=register_system.ghw \
  --stop-time=1us
```

The commands returned **exit code 0**, and the simulation reported:

```text
sim/register_system_tb.vhd:152:9:@137500ps:(report note): Tous les tests du systeme de registres ont reussi.
```

**Outcome:** All six testbench scenarios completed successfully by **137.5 ns**. This proves the specified simulated behaviors for the exercised cases; it is not a formal proof over all possible input traces.

![System waveforms viewed in VaporView](assets/system_waveform.png)

*Figure 5 — Final `register_system.ghw` trace opened with VaporView in VS Code. The `finished` signal rises after the tested scenarios.*

The two individual registers were also simulated and inspected:

| Standalone module | Waveform |
|---|---|
| Parallel | [parallel_waveform.png](assets/parallel_waveform.png) |
| SIPO shift | [shift_waveform.png](assets/shift_waveform.png) |

## 5. Vivado synthesis and resource mapping

**Target:** Zynq-7020 `xc7z020clg400-1`  
**Vivado:** 2024.1  
**Top:** `register_system`

The supplied **hierarchical synthesis utilization report** states:

| Hierarchy | Logic LUTs | Flip-flops | BRAMs | DSPs |
|---|---:|---:|---:|---:|
| `parallel_inst` | 0 | 4 | 0 | 0 |
| `shift_inst` | 2 | 4 | 0 | 0 |
| **Total `register_system`** | **2** | **8** | **0** | **0** |

This confirms the intended eight bits of sequential storage. The expanded schematic shows four `FDCE` instances per register and **four `LUT3`-labeled selection functions**, whereas the hierarchy utilization report shows **two LUTs** in total. The screenshots and resource report are different views of the synthesis result; the supplied evidence alone does not establish exactly how those four schematic functions are accounted for in two physical LUT resources. A cell-level utilization report and primitive properties would be needed to resolve that distinction rigorously. **Do not report four physical LUTs from the schematic alone.**

## 6. Timing constraints and analysis

The exercise's XDC defined the input clock:

```tcl
create_clock -name sys_clk -period 8.000 [get_ports clk]
```

This declares a nominal **125 MHz** timing clock (8 ns period). It specifies a timing requirement; by itself, it **does not** assign the signal to a PYNQ-Z2 package pin or guarantee a running 125 MHz source on real hardware.

### 6.1 Synthesized vs fully routed results

| Metric | Synthesized design | Fully routed design |
|---|---:|---:|
| Setup WNS | +6.777 ns | **+6.746 ns** |
| Hold WHS | +0.156 ns | **+0.294 ns** |
| Pulse-width WPWS | +3.500 ns | **+3.500 ns** |
| Total negative slack (TNS) | 0.000 ns | **0.000 ns** |
| Failing endpoints | 0 | **0** |

The final timing report was generated for **`register_system`, Design State: Routed**, and states: **“All user specified timing constraints are met.”** These results cover the paths constrained by the current XDC; they are not a complete board-level interface timing signoff.

### 6.2 Critical path after routing

The worst setup path connects two SIPO stages:

```text
shift_inst/stored_reg[2]/Q
            |
            |   C-to-Q propagation: 0.518 ns
            |   routed net:         0.672 ns
            v
shift_inst/stored_reg[3]/D

Total data path delay = 1.190 ns
Setup slack           = +6.746 ns
```

Both endpoints were placed in `SLICE_X0Y13` in the fully routed report. The worst hold path was from `stored_reg[0]` to `stored_reg[1]`, with **+0.294 ns** hold slack. This is a useful illustration of **setup** (data arrives early enough before the receiving clock edge) versus **hold** (data remains stable long enough around the receiving edge).

### 6.3 Remaining methodology warnings

The fully routed `report_methodology` found **12 `TIMING-18` warnings** about missing external input/output delays:

- 8 inputs: `d[3:0]`, `load`, `reset`, `serial_in`, `shift`.
- 4 outputs: `q[3:0]`.

`clk` is covered by `create_clock`; `mode` is not enumerated in the report's 12 warnings. Its presence and timing relevance must still be assessed when defining any real external interface, rather than assuming the warning list is an exhaustive interface specification.

These warnings are expected for an exercise where the external timing contract has **not yet been defined**. Do not invent `set_input_delay`/`set_output_delay` values merely to silence them. Such constraints require a real source/destination and timing specification. Similarly, the asynchronous reset's release requires appropriate synchronization or other justified timing treatment in a physical design.

The provided run also did not include a full PYNQ-Z2 pin mapping and electrical I/O standards. This is **not** a board-ready bitstream verification.

## 7. Interpretation and lessons learned

1. **Registers are parallel hardware.** Four `FDCE` cells store four bits simultaneously on a shared clock edge; they are not a sequence of software statements.
2. **An enable does not gate the clock in this RTL.** The `FDCE` primitive has a dedicated `CE` input.
3. **An asynchronous reset can change state between clock edges.** Its deassertion on hardware needs additional care.
4. **A SIPO register is a chain of state elements.** The output of one stage supplies the next stage's D input.
5. **A parent entity composes modules, not necessarily a controller.** `register_system` has no FSM or bus protocol.
6. **`mode` controls observation, not operation.** Both registers remain independently active and retain distinct states.
7. **A clean RTL simulation is not a hardware test.** GHDL validates the tested logic, while Vivado reports mapping and timing of the constrained design.
8. **Synthesis and routed results must not be conflated.** Placement and routing change delay estimates and may change netlist structure.

## 8. Verification status and conclusion

| Verification stage | Status | Evidence / qualification |
|---|---|---|
| Standalone VHDL RTL | Completed | `parallel_register.vhd`, `shift_register.vhd` |
| Standalone waveforms | Inspected | VaporView screenshots |
| Composed system RTL test | **Passed** | 6 scenarios, GHDL exit code 0, 137.5 ns |
| Vivado synthesis | **Completed** | 8 FFs, 2 LUTs in hierarchical synthesis utilization |
| Vivado routing | **Completed** | Final timing report: Design State Routed |
| Constrained 125 MHz internal timing | **Met** | WNS +6.746 ns; WHS +0.294 ns; TNS 0 |
| External interface timing | **Incomplete** | 12 TIMING-18 warnings; no I/O delay contract |
| PYNQ-Z2 execution | **Not performed** | No functional board test is documented |

**Conclusion:** Exercise 7 successfully revisited basic parallel and shift registers, VHDL hierarchy, multiplexing, self-checking simulation and FPGA primitive inference. The RTL verification and the constrained internal routed timing checks passed. External I/O timing and real hardware behavior remain intentionally outside the validated scope of this simplified exercise. A future, separate experiment could use buttons/LEDs or Vivado VIO to test hardware without rebuilding the earlier AXI/Jupyter integration.

---

## 9. Evidence and provenance

This report is based on materials shared in the conversation on 6 November 2026:

- VHDL source listings for the three entities and the system testbench.
- GHDL terminal result reporting success at 137,500 ps.
- Screenshots from VaporView and Vivado 2024.1 (all images in `assets/`).
- The pasted `report_utilization -hierarchical`, `report_timing_summary`, and `report_methodology` outputs for the synthesized and fully routed `register_system`.

The original Vivado project, source files, GHW waveform files and complete timing logs are **not** reproduced in this ZIP. The archive contains this Markdown report and selected screenshots, not a runnable FPGA project.
