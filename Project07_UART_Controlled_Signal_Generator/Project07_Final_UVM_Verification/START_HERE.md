# Project 07 — FINAL verification upgrade (Vivado 2025.2, UVM 1.2)

This archive is a **simulation-only verification extension** to the working RehanBuilds Project 7. The *original* `instrument_top.sv`, `fifo_sync.sv`, `pwm_engine.sv`, `uart_rx.sv`, `uart_tx.sv` and `instrument_basys3.xdc` are **byte-for-byte unchanged**. Your existing working `tb_instrument_top.sv` is preserved under `legacy_testbench/`.

**Status: GENERATED AND REVIEWED, NOT YET COMPILED OR SIMULATED IN VIVADO BY THE ASSISTANT.** Do not advertise a passing UVM test, coverage closure, or five-seed regression until you obtain actual simulator PASS results. Simulation failures may require a corrected package.

## Easy run — keep your existing Vivado project

1. **Make a backup of your original Project 7 folder**, then extract this ZIP to a normal folder, for example `C:\Users\User\Desktop\Project07_Final_UVM_Verification`. Do not put it inside `.runs` or `.sim` directories.
2. Open **Vivado 2025.2** and open your original `video07_instrument.xpr` (not the copied `.xpr` from your previous upload).
3. In Vivado's **Tcl Console**, enter the following, replacing the path with your actual extracted folder path (forward slashes are easiest in Tcl):

   ```tcl
   source {C:/Users/User/Desktop/Project07_Final_UVM_Verification/RUN_IN_VIVADO.tcl}
   ```

4. Vivado adds **three simulation-only** files, sets `tb_instrument_uvm` as the simulation top, launches XSim and requests `run all`. If Vivado pauses after 1000 ns, enter `run all` again.
5. At the **bottom of the Tcl Console**, look for `FINAL_SCOREBOARD`, `FINAL_PWM`, `FINAL_FIFO`, `FINAL_RESULT: PASS`, and `UVM_ERROR : 0` / `UVM_FATAL : 0`. Send the **full output from `FINAL_SCOREBOARD` onward**, or compile errors if you see them.
6. Only if seed 7 passes, execute the **five-seed regression**:

   ```tcl
   source {C:/Users/User/Desktop/Project07_Final_UVM_Verification/RUN_5_SEEDS_IN_VIVADO.tcl}
   ```

   Expected: one `FINAL_RESULT: PASS` for each seed **7, 11, 23, 41, 83**, zero UVM errors/fatals, and all 16 PWM configuration bins hit **on each run**. Note that Vivado may overwrite previous `xsim.log` files; save the Tcl Console output if you need evidence for all seeds.

If you see `UVM_ERROR`, `UVM_FATAL`, compiler errors, no `FINAL_RESULT` or timeout, **do not claim this passed**. Share the *first* error and the output around it, and we'll fix that specific problem.

## Why this is a genuine UVM project

The three simulation-only files are:

- `uvm/instrument_uvm_if.sv` — virtual interface exposing real UART pins and test-only PWM/FIFO monitor signals.
- `uvm/instrument_uvm_pkg.sv` — UVM 1.2 sequences/items, sequencer, UART driver/monitor/agent, environment, transaction scoreboard, functional covergroups, directed + constrained-random traffic, FIFO/PWM checkers and UVM test.
- `uvm/tb_instrument_uvm.sv` — simulation top that instantiates **your existing RTL** and **eight concurrent SystemVerilog assertions**.

**Tests include:** all 16 frequency × duty setting combinations, response/status prediction, unsupported command and malformed UART stop-bit rejection, 12 consecutive UART frames with no extra idle bits, 40 seeded constrained-random commands with variable gaps, FIFO occupancy monitoring, PWM cycle checking and period-boundary updates, and reset followed by status/reconfiguration checks.

**What is NOT being claimed:** AXI/APB, full industrial protocol verification, formal proof, physical waveform measurement from this UVM run, 100% total code coverage, full-FIFO/overflow coverage, CDC closure, or UVM expertise gained merely by running a script. We deliberately have not added a fake industry bus or modified FPGA functionality.

## Notes

- No board/Analog Discovery 3 required for **new verification tests**. Prior physical measurements remain historical evidence for the unchanged RTL.
- The UVM test uses accelerated clock/baud/PWM settings to simulate quickly. It does not simulate actual 100 MHz timing; your original Vivado implementation report remains the source for timing claims.
- Requires Vivado 2025.2 with XSim and the precompiled UVM 1.2 library. This is supported by AMD's Vivado simulation documentation: https://docs.amd.com/r/en-US/ug937-vivado-design-suite-simulation-tutorial/Vivado-Simulator-Overview
- Do not mix old `Project07_Resume_Ready_Upgrade` and this package's `tb_instrument_uvm.sv` files in the same compilation hierarchy.

## Definition of done

1. UVM seed 7 PASS, no UVM errors/fatals.
2. All five seeds PASS, no errors/fatals; `pwm_bins=16/16` on each.
3. Scoreboard proves expected UART responses; PWM/FIFO checkers produce evidence. Review what conditions actually occurred (including peak FIFO occupancy), and don't label unhit conditions as covered.
4. GitHub contains full RTL, UVM code, original testbench, README, and screenshots/logs showing actual results.
5. Only then update résumé with accurate metrics (template in `docs/RESUME_AFTER_PASS.md`).
