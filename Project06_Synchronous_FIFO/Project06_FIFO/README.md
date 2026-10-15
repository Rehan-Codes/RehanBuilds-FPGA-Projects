# RehanBuilds — Project 06: Parameterized Synchronous FIFO

**Board:** Digilent Basys 3 (Artix-7, `xc7a35tcpg236-1`)  
**Tool:** AMD Vivado 2025.2, XSim  
**Status:** Source package prepared; simulation, synthesis, timing and hardware tests must be performed before recording any PASS claim.

## What it does

A single-clock FIFO stores up to **8 bytes** and returns them in the same order they were written (first in, first out). Its reusable RTL core is parameterized by `DATA_WIDTH` and `DEPTH` (default 8 and 8). A separate Basys 3 wrapper adds debounced pushbuttons and visible status LEDs.

This project emphasizes RTL design **and** verification: occupancy tracking, full/empty boundaries, wraparound, simultaneous operations, reproducible randomized testing and an independent reference scoreboard.

## Basys 3 controls

| Control | Action |
| --- | --- |
| SW7–SW0 | Select the byte to push (binary) |
| BTNU | Push the selected byte into the FIFO (one operation per press) |
| BTND | Pop the oldest byte (one operation per press) |
| BTNC | Reset the FIFO, counters, data output and sticky error indicators |
| LD7–LD0 | **Last popped** byte, not the current switch setting |
| LD8 | Empty flag (ON when empty) |
| LD9 | Full flag (ON when full) |
| LD10 | Sticky overflow: attempted push when full without a concurrent valid pop |
| LD11 | Sticky underflow: attempted pop when empty |
| LD15–LD12 | Occupancy in binary: 0 to 8 |

**After programming, press BTNC once**, then release. The board uses the 100 MHz onboard clock. Push/pop buttons are synchronized and debounced (5 ms) to prevent one press being treated as many. Set switches before pressing BTNU; the switch positions are not individually synchronized because they are expected to remain stable across the debounced press.

## Files

| File | Vivado file set | Description |
| --- | --- | --- |
| `fifo_sync.sv` | Design Sources | Reusable parameterized FIFO core |
| `button_press.sv` | Design Sources | Synchronizer + debouncer + press pulse |
| `fifo_top.sv` | Design Sources (**top**) | Basys 3 switches/buttons/LEDs wrapper |
| `tb_fifo_sync.sv` | Simulation Sources (**simulation top**) | Self-checking scoreboard, directed and randomized tests |
| `fifo_basys3.xdc` | Constraints | Official Digilent clock, switch, button and LED pin assignments |

### Create the Vivado project

1. Create `video06_fifo` as an **RTL Project**, part `xc7a35tcpg236-1`. Check **Do not specify sources at this time**.
2. Import `fifo_sync.sv`, `button_press.sv`, `fifo_top.sv` as **Design Sources**.
3. Import `tb_fifo_sync.sv` as **Simulation Sources**.
4. Add `fifo_basys3.xdc` as **Constraints**.
5. Select **`fifo_top`** as the design top and **`tb_fifo_sync`** as the simulation top.
6. Run Behavioral Simulation. If it stops at 1000 ns, type `run -all` in the active XSim Tcl Console.

### Simulation coverage

The testbench exercises:

- Synchronous reset and empty state
- Eight sequential writes and full flag
- Rejected write on full FIFO (overflow)
- Correct FIFO output order and pointer wraparound
- Simultaneous read + write when full (both accepted)
- Drain to empty and rejected read (underflow)
- Simultaneous push + pop when empty (push accepted, pop rejected)
- Reset while the FIFO holds data, followed by recovery
- **2,000 reproducible randomized read/write transactions** (xorshift32 seed `0x1ACEB00C`)
- Independent reference scoreboard checking **occupancy, flags, valid and read data on every driven cycle**
- Coverage counters for rejected writes, rejected reads and accepted simultaneous transactions

The expected final message is similar to:

```text
PASS: synchronous reset and initial empty flag
PASS: fill-to-full and rejected-write overflow flag
PASS: wraparound and FIFO ordering
PASS: simultaneous read/write at full occupancy
PASS: drain-to-empty and rejected-read underflow flag
PASS: simultaneous push/pop at empty boundary
PASS: reset during traffic and recovery
PASS: 2000 reproducible randomized read/write transactions
PASS: coverage: blocked writes=..., blocked reads=..., simultaneous accepted=...
SUCCESS: Project 06 FIFO testbench PASSED (... checks, ... writes, ... reads, 2000 random transactions).
```

**Note:** These are the intended checks, **not pre-verified results**. Only publish actual XSim output after it passes.

### Hardware test (after passing simulation, synthesis and timing)

1. Program `fifo_top.bit` and press **BTNC**. LD8 (EMPTY) should illuminate; occupancy LEDs LD15–LD12 should be OFF.
2. Set SW7–SW0 to `10100101` (`0xA5`), press and release **BTNU** once. Occupancy becomes **1**. LD7–LD0 stays unchanged because no byte has been read.
3. Set switches to `00111100` (`0x3C`), press/release **BTNU** again. Occupancy becomes **2**.
4. Press/release **BTND**: LEDs LD7–LD0 show `10100101` (`0xA5`) and occupancy becomes **1**.
5. Press/release **BTND** again: LEDs show `00111100` (`0x3C`); occupancy becomes **0**, LD8 lights.
6. Press/release **BTND** once more while empty: LD11 (UNDERFLOW) stays ON until reset.
7. Press **BTNC**. Fill with eight button presses (set any SW byte); LD9 (FULL) and occupancy `1000` turn ON. A ninth push lights LD10 (OVERFLOW) without changing occupancy.

**Button timing:** Press and release naturally (at least ~10 ms per press and ~10 ms release). The 5 ms debounce is independent for push/pop.

### FIFO boundary-operation policy

- **Full + push & pop on same clock edge:** BOTH accepted; the oldest word is returned, new word replaces it, occupancy remains full.
- **Empty + push & pop on same clock edge:** PUSH accepted, POP rejected and underflow asserted; occupancy becomes one.
- **Read data:** Registered on successful pop; it remains unchanged if no read succeeds. `rd_valid` is asserted for one clock cycle for every accepted read.
- **Overflow/underflow in `fifo_sync.sv`:** One-cycle pulses. The hardware wrapper latches those events to separate LEDs until reset.

## Evidence for GitHub

Store files in `evidence/` with truthful labels after capture:

- `Project06_FIFO_Testbench_PASS.png` — XSim final PASS summary
- `Project06_FIFO_Simulation_Waveform.png` — a selected series of push/pop transactions
- `Project06_FIFO_Synthesis_Utilization.png` — synthesized resource counts
- `Project06_FIFO_Implementation_Timing.png` — implemented timing summary
- `Project06_FIFO_Hardware_Demo.mp4` — optional unedited hardware demonstration

For timing evidence, check WNS, WHS, failing endpoints, **and missing timing constraints**; I/O delay warnings for physical switches/LEDs should be described rather than represented as fully timed interfaces.

## Limitations / planned improvements

- This is a **single-clock** synchronous FIFO, **not** an asynchronous dual-clock FIFO.
- No AXI-Stream handshake or memory-mapped bus interface yet.
- No full UVM environment: the supplied testbench uses **directed + deterministic randomized stimulus and a reference scoreboard**, compatible with Vivado XSim. A dedicated UVM environment in a UVM-capable simulator is a later enhancement.
- Status uses LEDs and pushbuttons for demonstration; these button controls are not intended as a high-throughput interface.

## External reference

Pin assignments adapted from Digilent's Basys 3 Master XDC:
https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
