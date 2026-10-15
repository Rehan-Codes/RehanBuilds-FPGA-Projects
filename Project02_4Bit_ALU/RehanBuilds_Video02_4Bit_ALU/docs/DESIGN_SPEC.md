# ALU Design Specification

## Inputs and outputs

- A (`sw[3:0]`) = 4-bit operand A
- B (`sw[7:4]`) = 4-bit operand B
- Operation (`sw[9:8]`): 00 ADD; 01 SUB; 10 AND; 11 XOR
- Result (`led[3:0]`): 4 bits
- Carry/no-borrow flag (`led[4]`): arithmetic only
- Zero flag (`led[5]`): all operations
- Signed overflow flag (`led[6]`): arithmetic only

## Architecture decisions

### Shared adder for addition and subtraction

SUB uses `A + (~B) + 1` to compute `A - B`. The 4-bit B operand is XORed with four copies of `subtract`, so B is inverted only in subtraction mode. The same adder performs both arithmetic operations.

### Result and flags

For ADD: output the low four sum bits, use the fifth bit as unsigned carry-out, and detect signed overflow when A and B share a sign but the result has the opposite sign.

For SUB: output the low four difference bits, use the fifth bit of two's-complement addition as **no borrow** (`A >= B` in the unsigned interpretation), and detect signed overflow when operand signs differ and the result sign differs from A.

For AND / XOR: result is bitwise A&B or A^B; carry and overflow flags are zero. In all operations zero=1 exactly when result is 0000.

### Combinational design

The circuit uses no registers and no clock. Output transitions follow input transitions after physical propagation delays. Mechanical switches may bounce or momentarily create intermediate patterns; this design does not debounce them.

### Limits of this project

- Four-bit arithmetic wraps modulo 16; e.g. unsigned 15+1 gives result 0 and carry 1.
- Signed input interpretations are -8..7 (4-bit two's complement).
- Carry and signed overflow are different properties.
- No seven-segment display, UART, or push-button debounce in this project.

## Review questions after the hardware works

1. Why does `A + (~B) + 1` implement subtraction?
2. Why do we need a fifth arithmetic bit if only four bits are displayed?
3. Explain a case with carry=1 but overflow=0.
4. What is the role of `alu4_top.v` versus `alu4.v`?
5. How do we know all operations and flags were exhaustively tested?
