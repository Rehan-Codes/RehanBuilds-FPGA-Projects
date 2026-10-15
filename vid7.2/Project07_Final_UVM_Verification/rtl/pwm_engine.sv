`timescale 1ns / 1ps
// PWM engine for the UART-controlled digital instrument.
// One clock domain. Configuration takes effect only at period boundaries.
// Registered output avoids combinational glitches during counter transitions.
module pwm_engine #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BASE_HZ = 1_000
) (
    input  logic clk,
    input  logic rst,
    input  logic [1:0] duty_cfg,
    input  logic [1:0] freq_cfg,
    output logic pwm_out,
    output logic [1:0] active_duty,
    output logic [1:0] active_freq
);
    localparam integer BASE_PERIOD = CLK_HZ / BASE_HZ;
    localparam integer CW = (BASE_PERIOD > 1) ? $clog2(BASE_PERIOD+1) : 1;
    logic [CW-1:0] period_counter;
    logic [CW-1:0] period_cycles, high_cycles;

    always_comb begin
        case (active_freq)
            2'd0: period_cycles = BASE_PERIOD;
            2'd1: period_cycles = BASE_PERIOD / 2;
            2'd2: period_cycles = BASE_PERIOD / 4;
            default: period_cycles = BASE_PERIOD / 8;
        endcase
        case (active_duty)
            2'd0: high_cycles = '0;
            2'd1: high_cycles = period_cycles / 4;
            2'd2: high_cycles = period_cycles / 2;
            default: high_cycles = (period_cycles / 2) + (period_cycles / 4);
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            period_counter <= '0;
            active_duty <= 2'd0;
            active_freq <= 2'd0;
            pwm_out <= 1'b0;
        end else if (period_counter == period_cycles - 1'b1) begin
            period_counter <= '0;
            active_duty <= duty_cfg;
            active_freq <= freq_cfg;
            pwm_out <= (duty_cfg != 2'd0);
        end else begin
            period_counter <= period_counter + 1'b1;
            pwm_out <= ((period_counter + 1'b1) < high_cycles);
        end
    end
endmodule
