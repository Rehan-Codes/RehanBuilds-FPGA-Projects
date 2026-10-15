// RehanBuilds Video 02: four-bit ALU core.
// Operations: 00=ADD, 01=SUBTRACT, 10=AND, 11=XOR.
// carry_flag: ADD -> unsigned carry-out; SUB -> 1 means no borrow.
// overflow_flag: signed two's-complement overflow (ADD/SUB only).
// zero_flag: the four-bit result is zero (all operations).
// All logic is combinational; no clock is used.
module alu4 (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire [1:0] op,
    output reg  [3:0] result,
    output reg        carry_flag,
    output wire       zero_flag,
    output reg        overflow_flag
);

    // Subtract by two's complement: A - B = A + (~B) + 1.
    // The same adder is shared between ADD and SUB.
    wire subtract;
    wire [3:0] b_for_arithmetic;
    wire [4:0] arithmetic_full;

    assign subtract         = (op == 2'b01);
    assign b_for_arithmetic = b ^ {4{subtract}};
    assign arithmetic_full  = {1'b0, a} + {1'b0, b_for_arithmetic}
                            + {4'b0000, subtract};

    always @(*) begin
        // Defaults avoid unintended latches.
        result        = 4'b0000;
        carry_flag    = 1'b0;
        overflow_flag = 1'b0;

        case (op)
            2'b00: begin // ADD
                result        = arithmetic_full[3:0];
                carry_flag    = arithmetic_full[4];
                overflow_flag = (~(a[3] ^ b[3])) & (a[3] ^ result[3]);
            end
            2'b01: begin // SUBTRACT
                result        = arithmetic_full[3:0];
                carry_flag    = arithmetic_full[4]; // 1 = no borrow
                overflow_flag = (a[3] ^ b[3]) & (a[3] ^ result[3]);
            end
            2'b10: begin // AND
                result = a & b;
            end
            2'b11: begin // XOR
                result = a ^ b;
            end
        endcase
    end

    assign zero_flag = (result == 4'b0000);

endmodule
