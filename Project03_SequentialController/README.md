# Project 03 — Programmable Synchronous LED Controller

Board: Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`). Tool: Vivado 2025.2.

## Controls
- `SW1:SW0`: `00` rotate left, `01` rotate right, `10` bounce, `11` binary count.
- `SW3:SW2`: `00` 8 updates/s, `01` 4 updates/s, `10` 2 updates/s, `11` 1 update/s.
- `SW4`: high = pause (freeze pattern and tick count).
- `BTNC`: reset; hold for at least 10 ms (debounced).
- `LD7:LD0`: LED pattern.

## Architecture
- One 100 MHz clock; all logic synchronous with clock enables (no gated/generated clocks).
- Two flip-flop input synchronizers for switches and button, and button debounce logic.
- Four operational modes with defined entry states; parameterized update rate.
- Source `sequencer_top.sv`, verification `tb_sequencer_top.sv`, board constraints `sequencer_basys3.xdc`.

## Simulation
Add RTL as Design Sources, testbench as Simulation Sources, XDC as Constraints.
Set `tb_sequencer_top` as the simulation top. Run Behavioral Simulation, then `run -all`.
**The testbench uses `CLK_HZ=80` only in simulation to shorten test time.**
Expected output: `SUCCESS: Project 03 controller testbench PASSED (... checks).`

## Board operation
Use `sequencer_top` as synthesis top; generate bitstream, program the FPGA, then use switches and BTNC.
Check `Report Timing Summary` after implementation to confirm timing meets the 10.000 ns clock constraint.

## Evidence to capture
1. Final simulation Tcl Console with SUCCESS message.
2. Implementation timing summary and WNS (only claim timing met if WNS >= 0 and no relevant violations).
3. Photo or short clip of board cycling through modes and pause/reset.

## Limitations
Switches and reset button are synchronized; only BTNC is debounced. Switch settings are not individually debounced (adequate for stable toggle controls; possible transient mode selections during multi-bit switch changes). Full independent formal proof and comprehensive coverage are out of scope for the rapid prototype.
