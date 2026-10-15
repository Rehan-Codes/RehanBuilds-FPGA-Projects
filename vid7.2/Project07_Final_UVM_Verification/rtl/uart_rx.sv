`timescale 1ns / 1ps
// 8-N-1 UART receiver; data_valid and frame_error are one-clock pulses.
// The asynchronous UART input is synchronized before use.
module uart_rx #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic [7:0] data_out,
    output logic       data_valid,
    output logic       frame_error
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer CW = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;
    localparam integer HALF_BIT = (CLKS_PER_BIT > 1) ? (CLKS_PER_BIT/2) : 1;

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;
    logic rx_meta, rx_sync;
    logic [CW-1:0] timer;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            state       <= IDLE;
            timer       <= '0;
            bit_index   <= '0;
            shift_reg   <= '0;
            data_out    <= '0;
            data_valid  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            data_valid  <= 1'b0;
            frame_error <= 1'b0;
            case (state)
                IDLE: begin
                    if (!rx_sync) begin
                        timer <= HALF_BIT - 1;
                        state <= START;
                    end
                end
                START: begin
                    if (timer == 0) begin
                        if (!rx_sync) begin
                            timer     <= CLKS_PER_BIT - 1;
                            bit_index <= 3'd0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE; // rejected false start
                        end
                    end else timer <= timer - 1'b1;
                end
                DATA: begin
                    if (timer == 0) begin
                        shift_reg[bit_index] <= rx_sync;
                        timer <= CLKS_PER_BIT - 1;
                        if (bit_index == 3'd7) state <= STOP;
                        else bit_index <= bit_index + 1'b1;
                    end else timer <= timer - 1'b1;
                end
                STOP: begin
                    if (timer == 0) begin
                        if (rx_sync) begin
                            data_out   <= shift_reg;
                            data_valid <= 1'b1;
                        end else frame_error <= 1'b1;
                        state <= IDLE;
                    end else timer <= timer - 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
