# Project 07 — UVM verification plan

| Requirement | Stimulus | Check / evidence | Scope/limitations |
|---|---|---|---|
| All legal PWM configurations | 4 frequency × 4 duty directed sweep | Scoreboard's settings covergroup cross, response checks, independent UVM PWM checker | 16 *defined configuration bins*, not total design coverage |
| UART legal command response | Directed and 40 seeded constrained-random operations | Passive UART TX monitor + FIFO of predicted replies in UVM scoreboard | Serial framing at simulation-accelerated BAUD |
| Unsupported command | ASCII Z | Expect '!'; model unchanged | Checks command rejection not entire ASCII space |
| Framing error | UART corrupted stop bit | No predicted response, LED6 sticky, frame-error pulse observed | One kind of malformed frame |
| Burst buffering | 12 UART frames without extra idle bits | Expected response ordering, peak FIFO occupancy, overflow/underflow monitoring | Full FIFO is not guaranteed to be reached |
| Reset/recovery | Assert BTNC after drain; status/reconfigure | Reset LEDs and settings, new status response '0', then 'A' | Reset intentionally occurs after pending replies drain |
| PWM waveform | Every cycle, accelerated 32 tick base | Checker compares registered output to duty math; updates only at period boundary | Simulation only; real oscilloscope work remains prior evidence |
| FIFO safety properties | Every cycle during simulation | 8 SVA properties at TB top plus UVM FIFO checker | Not formal verification; properties must be observed in a running simulator |
| Reproducibility | Seeds 7,11,23,41,83 | Five-seed Tcl script, UVM summaries | Simulator run needs to be completed by user |

**Coverage note:** Hitting 16/16 frequency/duty bins is coverage of a *defined* cross, not a claim of 100% bug detection, code coverage, or total functional coverage. Passing SVA properties also does not prove their antecedents activated: review observed settings transitions, FIFO occupancy and pulse counts.
