// RehanBuilds Project 04 — glitchless, configurable PWM generator.
// 100 MHz onboard clock; no generated clocks or gated clocks.
module pwm_top #(
    parameter integer CLK_HZ      = 100_000_000,
    parameter integer BASE_PWM_HZ = 1_000
)(
    input  logic       clk,
    input  logic       btnC,
    input  logic [3:0] sw,
    output logic [4:0] led,
    output logic       pwm_ja1
);
    // BASE_PERIOD must be a multiple of 8 so each selectable duty
    // fraction is exact, including at the highest selected frequency.
    localparam integer BASE_PERIOD = CLK_HZ / BASE_PWM_HZ;
    localparam integer CW = (BASE_PERIOD > 1) ? $clog2(BASE_PERIOD) : 1;

    // Synchronize asynchronous board controls to the 100 MHz clock.
    // FPGA initializations guarantee a defined startup before BTNC is used.
    (* ASYNC_REG = "TRUE" *) logic [3:0] sw_meta = '0;
    (* ASYNC_REG = "TRUE" *) logic [3:0] sw_sync = '0;
    (* ASYNC_REG = "TRUE" *) logic [1:0] btn_pipe = 2'b11;

    always_ff @(posedge clk) begin
        sw_meta  <= sw;
        sw_sync  <= sw_meta;
        btn_pipe <= {btn_pipe[0], btnC};
    end

    wire reset_active = btn_pipe[1];

    // Each setting is latched only at the beginning of a PWM period.
    logic [1:0] active_duty = 2'b00;
    logic [1:0] active_freq = 2'b00;
    logic [CW-1:0] period_counter = '0;
    logic [CW-1:0] period_cycles;
    logic [CW-1:0] high_cycles;

    always_comb begin
        case (active_freq)
            2'b00: period_cycles = BASE_PERIOD;
            2'b01: period_cycles = BASE_PERIOD / 2;
            2'b10: period_cycles = BASE_PERIOD / 4;
            default: period_cycles = BASE_PERIOD / 8;
        endcase
        case (active_duty)
            2'b00: high_cycles = '0;                         // 0%
            2'b01: high_cycles = period_cycles / 4;           // 25%
            2'b10: high_cycles = period_cycles / 2;           // 50%
            default: high_cycles = (period_cycles / 2) +
                                   (period_cycles / 4);      // 75%
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset_active) begin
            period_counter <= '0;
            active_duty    <= sw_sync[1:0];
            active_freq    <= sw_sync[3:2];
        end else if (period_counter == (period_cycles - 1'b1)) begin
            period_counter <= '0;
            active_duty    <= sw_sync[1:0];
            active_freq    <= sw_sync[3:2];
        end else begin
            period_counter <= period_counter + 1'b1;
        end
    end

    assign pwm_ja1 = !reset_active && (period_counter < high_cycles);
    // LD4 displays PWM brightness; LD3:LD2 encode frequency;
    // LD1:LD0 encode duty. (These are *codes*, not numeric measurements.)
    assign led = {pwm_ja1, active_freq, active_duty};
endmodule
