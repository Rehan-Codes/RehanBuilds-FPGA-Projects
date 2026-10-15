`timescale 1ns / 1ps
// 8-N-1 UART transmitter. start is sampled when idle; done is a pulse.
module uart_tx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [7:0] data_in,
    output logic       tx,
    output logic       busy,
    output logic       done
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer CW = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;
    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;
    logic [CW-1:0] timer;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            timer <= '0;
            bit_index <= '0;
            shift_reg <= '0;
            tx <= 1'b1;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shift_reg <= data_in;
                        tx <= 1'b0;
                        busy <= 1'b1;
                        timer <= CLKS_PER_BIT - 1;
                        state <= START_BIT;
                    end
                end
                START_BIT: begin
                    if (timer == 0) begin
                        tx <= shift_reg[0];
                        timer <= CLKS_PER_BIT - 1;
                        bit_index <= 3'd0;
                        state <= DATA_BITS;
                    end else timer <= timer - 1'b1;
                end
                DATA_BITS: begin
                    if (timer == 0) begin
                        timer <= CLKS_PER_BIT - 1;
                        if (bit_index == 3'd7) begin
                            tx <= 1'b1;
                            state <= STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                            tx <= shift_reg[bit_index + 1'b1];
                        end
                    end else timer <= timer - 1'b1;
                end
                STOP_BIT: begin
                    if (timer == 0) begin
                        state <= IDLE;
                        busy <= 1'b0;
                        done <= 1'b1;
                    end else timer <= timer - 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
