# Basys 3 Physical Hardware Test Cases

## How to set the inputs

- To set A, switch ON the indicated switches among SW0..SW3; switch OFF the others.
- To set B, switch ON the indicated switches among SW4..SW7; switch OFF the others.
- Set operation bits SW9:SW8 according to the table.
- LD0 is result bit 0; LD3 is result bit 3.
- Flag LEDs: LD4=carry or no-borrow; LD5=zero; LD6=signed overflow.

| Case | A | B | SW9:SW8 | Expected result LD3:LD0 | Flag LD4 | Flag LD5 | Flag LD6 | Expected illuminated LEDs |
|---|---:|---:|:---:|:---:|:---:|:---:|:---:|---|
| ADD normal | 3 | 2 | 00 | 0101 | 0 | 0 | 0 | LD0, LD2 |
| ADD carry/zero | 15 | 1 | 00 | 0000 | 1 | 1 | 0 | LD4, LD5 |
| ADD signed overflow | 7 | 1 | 00 | 1000 | 0 | 0 | 1 | LD3, LD6 |
| SUB no borrow | 5 | 3 | 01 | 0010 | 1 | 0 | 0 | LD1, LD4 |
| SUB borrow | 2 | 5 | 01 | 1101 | 0 | 0 | 0 | LD0, LD2, LD3 |
| SUB signed overflow | 8 | 1 | 01 | 0111 | 1 | 0 | 1 | LD0, LD1, LD2, LD4, LD6 |
| AND | 10 | 12 | 10 | 1000 | 0 | 0 | 0 | LD3 |
| XOR | 10 | 12 | 11 | 0110 | 0 | 0 | 0 | LD1, LD2 |
| AND zero | 3 | 12 | 10 | 0000 | 0 | 1 | 0 | LD5 |

## Example: ADD A=3 B=2

- ON: SW0, SW1, SW5. OFF: SW2, SW3, SW4, SW6, SW7, SW8, SW9.
- Expected: LD0 and LD2 ON, all remaining LD0..LD6 OFF.

## Example: SUB A=5 B=3

- ON: SW0, SW2, SW4, SW5, SW8. OFF: SW1, SW3, SW6, SW7, SW9.
- Expected: LD1 and LD4 ON; all other LD0..LD6 OFF.

## Evidence

Record your actual observations for at least six of these cases in `VERIFICATION_LOG.md`. The `expected` values above were derived from the ALU specification; they are **not** claims of real hardware verification.
