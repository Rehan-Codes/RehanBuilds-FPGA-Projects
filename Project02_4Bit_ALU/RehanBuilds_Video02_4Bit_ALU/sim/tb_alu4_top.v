`timescale 1ns / 1ps
// Exhaustive self-checking testbench for the FULL Basys 3 top-level design.
// Tests 16 A values x 16 B values x 4 operations = 1024 vectors.
// Uses an independent integer-based reference model, not the ALU's logic.
module tb_alu4_top;
    reg  [9:0] sw;
    wire [6:0] led;

    reg [3:0] expected_result;
    reg expected_carry;
    reg expected_zero;
    reg expected_overflow;

    integer op_index;
    integer a_index;
    integer b_index;
    integer signed_a;
    integer signed_b;
    integer signed_answer;
    integer arithmetic_answer;
    integer passed;

    alu4_top dut (
        .sw(sw),
        .led(led)
    );

    initial begin
        sw = 10'b0000000000;
        passed = 0;

        for (op_index = 0; op_index < 4; op_index = op_index + 1) begin
            for (a_index = 0; a_index < 16; a_index = a_index + 1) begin
                for (b_index = 0; b_index < 16; b_index = b_index + 1) begin
                    sw[3:0] = a_index;
                    sw[7:4] = b_index;
                    sw[9:8] = op_index;

                    // Two's-complement interpretation for signed-overflow check.
                    signed_a = (a_index >= 8) ? a_index - 16 : a_index;
                    signed_b = (b_index >= 8) ? b_index - 16 : b_index;

                    expected_result = 4'b0000;
                    expected_carry = 1'b0;
                    expected_overflow = 1'b0;
                    signed_answer = 0;
                    arithmetic_answer = 0;

                    case (op_index)
                        0: begin // ADD
                            arithmetic_answer = a_index + b_index;
                            signed_answer = signed_a + signed_b;
                            expected_result = arithmetic_answer & 15;
                            expected_carry = (arithmetic_answer > 15);
                            expected_overflow = (signed_answer > 7)
                                             || (signed_answer < -8);
                        end
                        1: begin // SUBTRACT
                            arithmetic_answer = a_index - b_index;
                            signed_answer = signed_a - signed_b;
                            expected_result = arithmetic_answer & 15;
                            expected_carry = (a_index >= b_index); // no borrow
                            expected_overflow = (signed_answer > 7)
                                             || (signed_answer < -8);
                        end
                        2: begin // AND
                            expected_result = a_index & b_index;
                        end
                        3: begin // XOR
                            expected_result = a_index ^ b_index;
                        end
                    endcase
                    expected_zero = (expected_result == 4'b0000);

                    #10; // Allow combinational outputs to settle in simulation.
                    if (led !== {expected_overflow, expected_zero,
                                 expected_carry, expected_result}) begin
                        $display("FAIL: OP=%b A=%d B=%d expected LEDs=%b got=%b",
                                 sw[9:8], a_index, b_index,
                                 {expected_overflow, expected_zero,
                                  expected_carry, expected_result}, led);
                        $fatal(1, "ALU verification failed");
                    end
                    passed = passed + 1;
                end
            end
            $display("PASS: completed all 256 combinations for operation %b", sw[9:8]);
        end

        $display("SUCCESS: All %0d ALU combinations passed.", passed);
        $finish;
    end
endmodule
