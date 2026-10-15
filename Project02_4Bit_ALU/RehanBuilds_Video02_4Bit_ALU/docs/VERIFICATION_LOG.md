# Verification Log — Complete With Your Actual Results

**Date tested:** _fill in_
**Vivado version:** _fill in_
**Board:** Digilent Basys 3, XC7A35T
**Git commit / source revision:** _fill in_

## Simulation

- [ ] `tb_alu4_top.v` compiled and elaborated
- [ ] Testbench reported `SUCCESS: All 1024 ALU combinations passed.`
- [ ] Saved screenshot or console transcript of the result
- Notes / actual output:

## Synthesis and implementation

- [ ] Synthesis completed
- [ ] Implementation completed
- [ ] Bitstream generated and FPGA programmed
- [ ] Reviewed warnings / critical warnings
- LUT utilization (as reported): _fill in_
- I/O count (as reported): _fill in_
- Relevant timing constraints / timing remarks: _fill in_

## Physical hardware

| Test case | Expected LEDs | Actual LEDs observed | Pass/fail | Photo or video filename |
|---|---|---|---|---|
| ADD A=3 B=2 | LD0, LD2 | _record_ | _record_ | _record_ |
| ADD A=15 B=1 | LD4, LD5 | _record_ | _record_ | _record_ |
| ADD A=7 B=1 | LD3, LD6 | _record_ | _record_ | _record_ |
| SUB A=5 B=3 | LD1, LD4 | _record_ | _record_ | _record_ |
| SUB A=2 B=5 | LD0, LD2, LD3 | _record_ | _record_ | _record_ |
| SUB A=8 B=1 | LD0, LD1, LD2, LD4, LD6 | _record_ | _record_ | _record_ |
| AND A=10 B=12 | LD3 | _record_ | _record_ | _record_ |
| XOR A=10 B=12 | LD1, LD2 | _record_ | _record_ | _record_ |
| AND A=3 B=12 | LD5 | _record_ | _record_ | _record_ |

## Debugging and engineering decisions

- Problem observed:
- Hypothesis:
- Test performed:
- Resolution:
- Design limitation or future improvement:

## Portfolio status

- [ ] Code committed with accurate history
- [ ] Simulation evidence saved
- [ ] Hardware evidence saved
- [ ] Known limitations documented
- [ ] Prepared to explain and modify the design independently
