# Project 07 — UART-Controlled FPGA Digital Signal Generator

**RehanBuilds flagship prototype v0.1** · Basys 3 Artix-7 (`xc7a35tcpg236-1`) · Vivado 2025.2 · 100 MHz board clock · UART 115200 8N1.

## Overview

Control a 3.3 V **digital PWM signal** on Basys 3 **Pmod JA1** through a Python program on a Windows PC. The PC sends single-byte UART commands. FPGA RTL receives them, queues them in an eight-entry synchronous FIFO, decodes configuration commands, updates control/status registers, echoes accepted commands or sends status, and generates PWM. Waveform changes apply at the **next PWM period boundary**. Measure frequency and duty cycle with Analog Discovery 3.

**This is a digital PWM instrument, not an analog function generator or DAC.** The prototype does not produce sine or triangle waves.

```
Python PC -> USB-UART -> uart_rx -> FIFO[8] -> command parser -> frequency/duty registers
                ^                      |                            |
                |                      +--> uart_tx (ack/status)    v
                +------------------------------------------------ pwm_engine --> JA1 --> AD3 Scope
```

## Communication protocol

Baud **115200**, 8 data bits, no parity, 1 stop bit (8N1). All requests are one ASCII character.

| Send ASCII | Meaning | FPGA UART response |
|---|---|---|
| `0`, `1`, `2`, `3` | Duty **0%, 25%, 50%, 75%** | Echo same character |
| `4`, `5`, `6`, `7` | Frequency **1, 2, 4, 8 kHz** | Echo same character |
| `?` | Read desired frequency/duty settings | One uppercase hexadecimal digit: `(freq_code << 2) | duty_code` |
| Other | Invalid command | `!` |

Examples: send `2` and `6` to request **4 kHz, 50%**, then `?` returns `A` (0xA = frequency index 2, duty index 2). An echo indicates the command was decoded; use AD3 to confirm physical waveform characteristics.

**Command queue behavior:** 8-byte depth. At high sustained command rates, the FIFO can overflow; LED5 latches that error. There is no protocol backpressure or retransmission. The Python program intentionally waits for each reply before sending the next command.

## LEDs and hardware

| Output | Meaning |
|---|---|
| LD1:LD0 | Requested duty selection code (00..11) |
| LD3:LD2 | Requested frequency selection code (00..11) |
| LD4 | PWM digital output (will look steady/dim on LED) |
| LD5 | FIFO overflow sticky flag |
| LD6 | UART framing-error sticky flag |
| LD7 | Activity toggles on each processed command |
| **JA1** | 3.3 V PWM digital output |
| **BTNC** | Reset configuration and errors (press after programming) |

No FPGA input switches are required; the PC commands control settings. Basys 3 USB cable carries USB-UART as in Project 5.

## Files

- `instrument_top.sv` — top-level UART/FIFO/controller/LED integration.
- `pwm_engine.sv` — configurable counter-based **registered PWM**, no generated clock domains.
- `uart_rx.sv`, `uart_tx.sv` — reused from Project 5; 2FF UART input synchronization.
- `fifo_sync.sv` — reused from Project 6; parameterized synchronous FIFO.
- `tb_instrument_top.sv` — integrated self-checking SystemVerilog testbench.
- `instrument_basys3.xdc` — official Digilent pin mappings and 10 ns timing constraint.
- `uart_control.py` — interactive and automated Python USB-UART command client (`pyserial`).

## Vivado setup (exact workflow)

1. Create RTL Project **`video07_instrument`**, part `xc7a35tcpg236-1`. Choose **Do not specify sources at this time**.
2. Add **Design Sources**: `instrument_top.sv`, `pwm_engine.sv`, `uart_rx.sv`, `uart_tx.sv`, `fifo_sync.sv`. Set `instrument_top` as **Design Top**.
3. Add **Simulation Sources**: `tb_instrument_top.sv`. Set `tb_instrument_top` as **Simulation Top**.
4. Add **Constraints**: `instrument_basys3.xdc`.
5. Run Behavioral Simulation, then `run -all` as necessary. **Do not claim test success until the final SUCCESS line appears.**
6. Run Synthesis, capture utilization; Run Implementation, inspect Timing Summary and unconstrained paths; Generate Bitstream; Program Basys 3.
7. Open a new Windows Command Prompt in this folder and run:

   ```cmd
   py -m pip install pyserial
   py uart_control.py COM8 --demo
   ```
   Replace `COM8` with the actual serial port in Device Manager. Interactive mode: `py uart_control.py COM8`.
8. If the serial test succeeds, connect AD3 Scope `1+` to Basys 3 JA1, `1-` to a verified Pmod ground pin (JA5 or JA11), **while board power is off**, then re-power/reprogram as needed. Never attach AD3 power supplies or Wavegen outputs to JA1. Open WaveForms **Scope** with Channel 1 at about 1 V/div and 200 us/div for 1 kHz or 50 us/div for 4 kHz. Trigger at 1.5 V rising, DC coupling.
9. Python: `freq 1000`, `duty 50`, `status`; expect AD3 about 1 kHz, 50%, 0–3.3 V. Repeat for `freq 4000`, `duty 25`, expect ~4 kHz, 25%.

## Simulation features and constraints

The integrated testbench tests UART acknowledgements/status, configuration changes, cycle-by-cycle PWM duty/frequency, invalid commands, back-to-back FIFO-buffered commands, rejected malformed UART frames, and reset recovery. It runs with an accelerated simulated clock to reduce simulation time; **this does not prove production hardware until FPGA and AD3 tests pass**.

The implementation includes one synchronous 100 MHz clock domain. The UART input is synchronized. FIFO queues received bytes. PWM output transitions are registered and new settings take effect at period boundaries.

Constraints include the 100 MHz board clock and physical I/O pins. No external timing input/output-delay constraints are specified for asynchronous UART and pushbutton inputs or observational LED/JA outputs; disclose that distinction when sharing timing evidence.

**This is a learning and portfolio prototype, not production silicon IP.** It does not include UVM, formal proofs, automatic flow-control, a general-purpose bus, sine/triangle generation, or a DAC. Those are future extensions.

## Evidence to save under `evidence/`

- `Project07_Integrated_Testbench_PASS.png` — **only after** the integrated testbench reports SUCCESS.
- `Project07_UART_FIFO_PWM_Waveform.png` — RX, TX, selected settings, PWM pulses.
- `Project07_Synthesis_Utilization.png` — resource numbers from Vivado.
- `Project07_Implementation_Timing.png` — constrained timing with WNS/WHS.
- `Project07_Python_Control_PASS.png` — terminal showing real FPGA responses.
- `Project07_AD3_PWM_1kHz_50percent.png` — measured actual output.
- `Project07_AD3_PWM_4kHz_25percent.png` — measured actual output.
- `Project07_Hardware_Demo.mp4` — optional brief demonstration.

## Reference

Basys 3 Master XDC by Digilent: https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc
