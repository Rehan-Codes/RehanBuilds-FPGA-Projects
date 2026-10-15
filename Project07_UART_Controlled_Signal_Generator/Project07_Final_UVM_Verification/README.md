# RehanBuilds — Project 07: UART-Controlled FPGA Digital PWM Instrument + UVM Verification

**Existing hardware (unchanged)**: Artix-7 Basys 3, UART 115,200 8N1, 8-entry synchronous FIFO, PWM generator (1/2/4/8 kHz; 0/25/50/75% duty), Python serial configuration, Pmod JA1 PWM waveform.

**New simulation-only environment**: UVM 1.2 UART agent + scoreboarding, directed and constrained-random stimuli, functional covergroups, 8 concurrent SVAs, per-cycle PWM/FIFO monitoring, reset/error/burst tests, and five-seed XSim regression script.

> **New test status:** Pending first Vivado/XSim execution. See [START_HERE.md](START_HERE.md). Do not claim the UVM tests passed until actual results are saved.

Files: `rtl/` original synthesizable code and XDC; `uvm/` new verification testbench; `legacy_testbench/` original 85-check simulation; `docs/` verification plan, prior README and proposed résumé after PASS. The UVM test uses accelerated simulation settings; earlier physical AD3 results and timing are described in `docs/README_original.md`.
