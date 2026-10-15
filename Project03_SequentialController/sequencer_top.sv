`timescale 1ns / 1ps

// RehanBuilds Project 03: Programmable synchronous LED controller.
// FPGA: Digilent Basys 3 (100 MHz input clock).
// SW[1:0] = mode: 00 rotate left, 01 rotate right,
//                  10 bounce, 11 binary count.
// SW[3:2] = speed: 00 = 8 Hz, 01 = 4 Hz, 10 = 2 Hz, 11 = 1 Hz.
// SW[4]   = pause when high.
// BTNC    = debounced, active-high reset.
// LED[7:0] shows the pattern.
module sequencer_top #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer DEBOUNCE_CYCLES = 1_000_000
) (
    input  logic       clk,
    input  logic       btnC,
    input  logic [4:0] sw,
    output logic [7:0] led
);

    // Synchronize asynchronous external inputs to the board clock.
    (* ASYNC_REG = "TRUE" *) logic [4:0] sw_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [4:0] sw_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic btn_meta = 1'b0;
    (* ASYNC_REG = "TRUE" *) logic btn_sync = 1'b0;

    always_ff @(posedge clk) begin
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
        btn_meta <= btnC;
        btn_sync <= btn_meta;
    end

    // Debounce the center reset button (10 ms at 100 MHz).
    localparam integer DB_WIDTH = (DEBOUNCE_CYCLES > 1) ?
                                  $clog2(DEBOUNCE_CYCLES) : 1;
    logic [DB_WIDTH-1:0] db_count = '0;
    logic btn_clean = 1'b0;

    always_ff @(posedge clk) begin
        if (btn_sync == btn_clean) begin
            db_count <= '0;
        end else if (db_count == DEBOUNCE_CYCLES - 1) begin
            db_count  <= '0;
            btn_clean <= btn_sync;
        end else begin
            db_count <= db_count + 1'b1;
        end
    end

    localparam integer DIV_8HZ = (CLK_HZ / 8 > 0) ? CLK_HZ / 8 : 1;
    localparam integer DIV_4HZ = (CLK_HZ / 4 > 0) ? CLK_HZ / 4 : 1;
    localparam integer DIV_2HZ = (CLK_HZ / 2 > 0) ? CLK_HZ / 2 : 1;
    localparam integer DIV_1HZ = (CLK_HZ > 0) ? CLK_HZ : 1;
    localparam integer COUNT_WIDTH = (CLK_HZ > 1) ? $clog2(CLK_HZ + 1) : 1;

    logic [1:0] mode;
    logic [1:0] speed;
    logic paused;
    logic [COUNT_WIDTH-1:0] tick_limit;
    logic [COUNT_WIDTH-1:0] tick_count = '0;
    logic [1:0] previous_mode = 2'b00;
    logic [1:0] previous_speed = 2'b00;
    logic [7:0] pattern = 8'b0000_0001;
    logic bounce_down = 1'b0;

    assign mode   = sw_sync[1:0];
    assign speed  = sw_sync[3:2];
    assign paused = sw_sync[4];
    assign led    = pattern;

    always_comb begin
        case (speed)
            2'b00: tick_limit = DIV_8HZ;
            2'b01: tick_limit = DIV_4HZ;
            2'b10: tick_limit = DIV_2HZ;
            default: tick_limit = DIV_1HZ;
        endcase
    end

    // One clock domain; generate a clock ENABLE instead of another clock.
    always_ff @(posedge clk) begin
        if (btn_clean) begin
            pattern        <= 8'b0000_0001;
            bounce_down    <= 1'b0;
            tick_count     <= '0;
            previous_mode  <= mode;
            previous_speed <= speed;
        end else if (mode != previous_mode) begin
            // Deterministic initial state on every mode change.
            previous_mode  <= mode;
            previous_speed <= speed;
            pattern        <= (mode == 2'b11) ? 8'h00 : 8'h01;
            bounce_down    <= 1'b0;
            tick_count     <= '0;
        end else if (speed != previous_speed) begin
            previous_speed <= speed;
            tick_count     <= '0;
        end else if (!paused) begin
            if (tick_count == tick_limit - 1'b1) begin
                tick_count <= '0;
                case (mode)
                    2'b00: pattern <= {pattern[6:0], pattern[7]};
                    2'b01: pattern <= {pattern[0], pattern[7:1]};
                    2'b10: begin
                        if (!bounce_down) begin
                            pattern <= {pattern[6:0], 1'b0};
                            if (pattern[6]) bounce_down <= 1'b1;
                        end else begin
                            pattern <= {1'b0, pattern[7:1]};
                            if (pattern[1]) bounce_down <= 1'b0;
                        end
                    end
                    2'b11: pattern <= pattern + 8'd1;
                endcase
            end else begin
                tick_count <= tick_count + 1'b1;
            end
        end
        // When paused, retain pattern and partial tick count.
    end
endmodule
