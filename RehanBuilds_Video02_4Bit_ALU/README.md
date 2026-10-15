# RehanBuilds — Video 02: Four-Bit Arithmetic Logic Unit (ALU)

**Hardware:** Digilent Basys 3 (Artix-7 `xc7a35tcpg236-1`)
**Tool:** AMD Vivado 2025.2, Verilog RTL, XSim
**Status:** Starter implementation and verification suite provided. Do NOT claim this project has been simulated or hardware-verified until you personally run the tests and record the results.

## Objective

Build and test a combinational 4-bit ALU with four functions:

| SW9 | SW8 | Operation | Description |
| --- | --- | --- | --- |
| 0 | 0 | ADD | A + B modulo 16, with carry-out and signed overflow flags |
| 0 | 1 | SUB | A - B modulo 16, with no-borrow and signed overflow flags |
| 1 | 0 | AND | A & B |
| 1 | 1 | XOR | A ^ B |

- `sw[3:0]`: operand A (0..15 unsigned; -8..7 interpreted as 4-bit signed)
- `sw[7:4]`: operand B (same)
- `sw[9:8]`: operation selection
- `led[3:0]`: four-bit result (LD0 is bit zero)
- `led[4]`: carry-out for ADD, **1 means no borrow** for SUB, always 0 for logic operations
- `led[5]`: zero flag, 1 if four-bit result = 0
- `led[6]`: signed two's-complement overflow for ADD/SUB, always 0 for logic operations

A single adder handles ADD and SUB using two's-complement inversion of B. **No clock is used in this project**; outputs change as combinational input signals change.

## Repository files

```text
RehanBuilds_Video02_4Bit_ALU/
  rtl/
    alu4.v                 # reusable ALU core
    alu4_top.v             # Basys 3 switches/LED wrapper; synthesis top
  sim/
    tb_alu4_top.v          # self-checking exhaustive testbench; simulation top
  constraints/
    alu4_basys3.xdc       # SW0..SW9 and LD0..LD6 pins
  docs/
    DESIGN_SPEC.md         # architecture, arithmetic and flag specification
    VERIFICATION_LOG.md   # fill with YOUR observed results
    HARDWARE_TESTS.md     # expected physical switch/LED test patterns
  results/
    README.md             # place actual utilization/timing reports here
  README.md
```

## Step 1 — Create a Vivado project

1. Extract this folder somewhere easy to find, e.g. `C:\Users\User\Desktop\video02_files\RehanBuilds_Video02_4Bit_ALU`.
2. Launch **Vivado 2025.2** and select **Create Project**.
3. Name it **`video02_alu4`**. Choose a location such as `C:\Users\User\Desktop\video02_files`. Avoid placing Vivado-generated files within the `rtl` folder.
4. Choose **RTL Project**, and tick **Do not specify sources at this time** for easy controlled importing.
5. On **Default Part**, use the **Parts** tab and search for **`xc7a35tcpg236-1`**. Select exactly that part and Finish. (You can alternatively select the installed Basys 3 board definition if it maps to the same part.)

## Step 2 — Add the files

1. From **Flow Navigator → Project Manager → Add Sources**, choose **Add or Create Design Sources**.
2. **Add Files**: `rtl/alu4.v` and `rtl/alu4_top.v`. Complete the wizard.
3. Use **Add Sources → Add or Create Simulation Sources → Add Files**, select `sim/tb_alu4_top.v`.
4. Use **Add Sources → Add or Create Constraints → Add Files**, select `constraints/alu4_basys3.xdc`.
5. In **Sources → Design Sources**, right-click `alu4_top` → **Set as Top** (if it is not already the top).
6. In **Sources → Simulation Sources**, ensure `tb_alu4_top` is the simulation top. In the simulation file hierarchy, right-click `tb_alu4_top` → **Set as Top** if needed.

**Important:** Do not accidentally set the testbench as the synthesis top, or put `tb_alu4_top.v` in Design Sources.

## Step 3 — Behavioral simulation BEFORE synthesis

1. In **Flow Navigator → Simulation**, select **Run Simulation → Run Behavioral Simulation**.
2. Wait for XSim to finish. Check the **Tcl Console** output (and expand the Console if necessary).
3. Expected output:

```text
PASS: completed all 256 combinations for operation 00
PASS: completed all 256 combinations for operation 01
PASS: completed all 256 combinations for operation 10
PASS: completed all 256 combinations for operation 11
SUCCESS: All 1024 ALU combinations passed.
```

The simulation checks **all four operations for all 16 A and 16 B input values**, including result, carry/no-borrow, zero, and signed overflow. If it prints `FAIL` or `FATAL`, STOP and investigate before hardware programming. Note: this starter ZIP has not been verified by the assistant on your installation of Vivado.

## Step 4 — Build for the Artix-7 FPGA

1. In Flow Navigator select **Run Synthesis**. Wait for successful completion.
2. Then select **Run Implementation**. Wait for completion. Inspect warnings and timing reports; a green completed run is not a substitute for engineering checks.
3. Select **Generate Bitstream**. Expected bitstream location is inside the Vivado project, generally `video02_alu4.runs/impl_1/alu4_top.bit`.
4. In the design reports, inspect **Utilization**. Record LUT count, I/O usage, and any relevant warnings in `docs/VERIFICATION_LOG.md` (do not estimate resource counts).

This is a **clockless combinational design**. Do not claim that it runs at a particular clock frequency or meets a 100 MHz clock simply because bitstream generation succeeded.

## Step 5 — Program the board

1. Connect your Basys 3 to the PC over USB and turn it on.
2. Open **Flow Navigator → Program and Debug → Open Hardware Manager**.
3. Select **Open Target → Auto Connect** (if not already connected).
4. Select **Program Device**; browse to the generated `alu4_top.bit` if not automatically selected, and click **Program**.
5. The old seven-gate or factory demonstration should be replaced by the ALU logic.

## Step 6 — Physical tests

Perform the test patterns in `docs/HARDWARE_TESTS.md` and record observations in `docs/VERIFICATION_LOG.md`.

For a first quick test, set:

- **A=3**: SW1 and SW0 ON; other A switches OFF.
- **B=2**: SW5 ON; other B switches OFF.
- **ADD**: SW9 and SW8 OFF.
- **Expected**: 3+2=5 = binary 0101, so **LD0 and LD2 ON**; LD4, LD5 and LD6 OFF.

Then try ADD 15+1 (LD4 carry and LD5 zero ON), ADD 7+1 (LD3 result and LD6 overflow ON), and SUB 5-3 (LD1 result and LD4 no-borrow ON).

## Step 7 — Preserve genuine engineering evidence

- Fill in `docs/VERIFICATION_LOG.md` with your *actual* date, screenshots, observations, compilation messages, and any unresolved issues.
- Save relevant testbench PASS screenshot, synthesis utilization report, implementation/timing report, and a short hardware demonstration.
- Create Git commits as real milestones are reached; do not invent prior history or fake errors.
- Describe any assistant-generated starter code or substantial third-party assistance honestly; your own testing and modifications establish design ownership.
- Do **not** upload Vivado's huge temporary caches, `.runs`, `.sim`, `.cache`, or bitstreams containing device-specific information to GitHub unless you intentionally choose to share specific artifacts. You can commit `rtl`, `sim`, `constraints`, `docs`, and selected `results` reports.

## Done criteria

1. Exhaustive testbench reports **1024/1024 PASS**.
2. Synthesis, implementation and bitstream generation complete.
3. At least six meaningful physical test cases match the expected LED patterns.
4. Log and README reflect real measured results, not projected or invented claims.
5. After hardware success, complete a short explanation of the shared adder, two's complement, carry vs overflow, and modular design.

## Reference

Basys 3 XDC pin mapping is derived from Digilent's official master XDC:
https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
