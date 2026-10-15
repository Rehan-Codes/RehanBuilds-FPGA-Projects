// Basys 3 top-level wrapper. Set this module as the SYNTHESIS top in Vivado.
// SW[3:0] = operand A, SW[7:4] = operand B, SW[9:8] = operation.
// LD[3:0] = result, LD4 = carry/no-borrow, LD5 = zero, LD6 = overflow.
module alu4_top (
    input  wire [9:0] sw,
    output wire [6:0] led
);
    wire [3:0] result;
    wire carry_flag;
    wire zero_flag;
    wire overflow_flag;

    alu4 u_alu4 (
        .a(sw[3:0]),
        .b(sw[7:4]),
        .op(sw[9:8]),
        .result(result),
        .carry_flag(carry_flag),
        .zero_flag(zero_flag),
        .overflow_flag(overflow_flag)
    );

    assign led[3:0] = result;
    assign led[4]   = carry_flag;
    assign led[5]   = zero_flag;
    assign led[6]   = overflow_flag;
endmodule
