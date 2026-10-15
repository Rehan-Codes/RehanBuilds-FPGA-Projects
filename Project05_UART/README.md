# Project 05 — UART Transmitter and Receiver

**Board:** Digilent Basys 3 (`xc7a35tcpg236-1`) | **Tool:** Vivado 2025.2

## Purpose

Implements a synthesizable 8-N-1 UART receiver and transmitter. The computer sends one byte over the Basys 3's built-in USB-UART interface. The FPGA displays its value on `LD7..LD0` and sends the identical byte back to the computer (echo). `LD8` latches high on a malformed UART stop bit; the center button BTNC resets the LEDs and clears this error flag.

## Project files

- `uart_rx.sv` — asynchronous-input synchronizer, UART sampling FSM and framing-error detection.
- `uart_tx.sv` — start, data and stop bit transmitter FSM.
- `uart_top.sv` — top-level receive/display/echo integration; one-entry echo staging register.
- `tb_uart_top.sv` — self-checking SystemVerilog simulation of transmitted and received frames, including malformed frames.
- `uart_basys3.xdc` — 100 MHz system clock, USB-UART pins, BTNC and LEDs.
- `uart_pc_test.py` — Python/pyserial hardware test; sends five bytes and checks the replies.

## Vivado

1. Create an RTL project for `xc7a35tcpg236-1`.
2. Add `uart_rx.sv`, `uart_tx.sv`, `uart_top.sv` as **Design Sources**.
3. Add `tb_uart_top.sv` as **Simulation Sources** (set top `tb_uart_top`).
4. Add `uart_basys3.xdc` as **Constraints**.
5. Run **Behavioral Simulation**, then `run -all` if it stops after 1000 ns. Capture actual PASS output. The testbench runs at a reduced simulated clock/baud ratio for speed; hardware parameters remain 100 MHz and 115200 baud.
6. Set design top `uart_top`. Run synthesis, implementation and report timing. Check the I/O timing warnings separately from internal clocked timing.
7. Generate bitstream, then program FPGA.

## Physical test (no AD3 or jumper wires)

1. Disconnect AD3 measurement wires; use the Basys 3's **PROG** micro-USB cable (the one already used for Vivado programming).
2. Locate the USB serial **COM** port in Windows **Device Manager → Ports (COM & LPT)**. The FTDI bridge may expose multiple interfaces; choose the serial UART port, not the JTAG interface.
3. Install Python dependency once: `python -m pip install pyserial`.
4. List ports if necessary: `python -m serial.tools.list_ports`.
5. In a terminal run: `python uart_pc_test.py COM5` (replace `COM5` with your actual port).
6. Each transmitted byte should be echoed back correctly. The FPGA displays the received byte in binary on LEDs LD7..LD0. After the final `0x00` byte, those eight LEDs should be OFF. BTNC resets the displayed value and error flag.

UART settings: **115200 baud, 8 data bits, no parity, 1 stop bit, no flow control**.

## Evidence to retain

- `evidence/Project05_UART_Testbench_PASS.png` — only after actual testbench success.
- `evidence/Project05_UART_Waveform.png` — readable start/data/stop frame, and LEDs.
- `evidence/Project05_Synthesis_Utilization.png` — LUTs and registers.
- `evidence/Project05_Implementation_Timing.png` — WNS/WHS, failing endpoints.
- `evidence/Project05_Python_Echo_PASS.png` — Python terminal showing echoed bytes.
- Brief phone recording of the board LEDs updating when Python sends a command (optional).

## Known limits

This is a demonstration, not a production UART: the top-level echo path contains a **single staging byte**, so indefinite incoming high-rate bursts can overflow it. The Python demonstration deliberately sends one byte and waits for its echo before sending the next. The framing-error indicator is sticky until reset. Hardware measurements and runtime validation should be documented only after they have been performed.

Reference pin assignments: [Digilent Basys3 Master XDC](https://github.com/Digilent/Basys3/blob/master/Resources/XDC/Basys3_Master.xdc).
