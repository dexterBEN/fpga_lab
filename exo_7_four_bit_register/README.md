# Exercise 7 — 4-bit registers

Two VHDL registers, their top module, and a PS/AXI GPIO integration for the PYNQ-Z2.

- [Command protocol, resets, and Vivado integration](docs/integration_pynq.md)
- [Results of the checks performed](docs/validation.md)
- [PYNQ hardware test notebook](notebooks/register_system_test.ipynb)

Run the simulations from this directory inside the devcontainer:

```bash
make sim
```

The `sim-parallel`, `sim-shift`, `sim-system`, `sim-adapter`, and
`sim-integration` targets can also be run separately.

To create and build a new overlay project on a machine with Vivado 2024.1:

```bash
python3 scripts/fetch_board_files.py
vivado -mode batch -source scripts/build_overlay.tcl -tclargs build
```

The original standalone project is preserved. The overlay is built under
`build/`, and the deployment artifacts are exported to `overlay/`.
The project used to generate this session's artifacts is
`build/pynq_overlay_script_check/registers.xpr`.
Read the integration guide before rebuilding or cleaning: `make clean`
also removes the generated overlay project under `build/`.

The notebook must be run on the PYNQ-Z2. Providing the notebook and passing
the GHDL tests do not constitute hardware validation on the board.
