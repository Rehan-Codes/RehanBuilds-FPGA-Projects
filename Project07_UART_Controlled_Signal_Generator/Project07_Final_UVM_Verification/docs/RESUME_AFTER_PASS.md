# Résumé replacement after passing simulator and publishing GitHub

Do **not** paste the new claims until the UVM test and five-seed regression actually pass.

**UART-CONTROLLED FPGA DIGITAL SIGNAL GENERATOR — REHANBUILDS**  
*SystemVerilog · UVM 1.2 · Vivado/XSim · Python · Artix-7*

- Integrated UART TX/RX, an 8-entry FIFO, command decode and programmable PWM in SystemVerilog; verified PC configuration and waveform outputs on Basys 3 using Python and Analog Discovery 3.
- Developed a UVM 1.2 testbench with UART sequencer/driver/monitor, transaction-level scoreboard, SystemVerilog Assertions and functional coverage; verified [actual matched replies] with [actual seed count] passing randomized regressions.
- Covered all 16 defined frequency/duty combinations and tested UART error handling, back-to-back commands and PWM period-boundary updates; closed 100 MHz FPGA implementation timing with +2.009 ns setup slack under original constraints.

**Skills only after validation:** UVM 1.2, SystemVerilog Assertions, functional covergroups, constrained-random stimulus, transaction scoreboards, UVM driver/monitor/agent, XSim regression automation.

**Do not write:** AXI, APB, PCIe, formal verification, 100% total functional coverage, ASIC tape-out, UVM expertise, or new AD3 measurements unless independently supported by new work.
