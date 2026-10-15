`timescale 1ns / 1ps
// Project 07 — UART-controlled FPGA digital signal generator (prototype v0.1).
// 115200 8N1 USB UART, eight-byte command FIFO, PWM and status/ack replies.
// Commands: ASCII '0'-'3' duty 0/25/50/75%; '4'-'7' freq 1/2/4/8 kHz;
// '?' returns one ASCII hex digit encoding {frequency[1:0], duty[1:0]};
// unknown commands return '!'. Valid settings echo the original byte.
// One-byte commands only; the FIFO buffers short bursts.
module instrument_top #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD = 115_200,
    parameter integer BASE_PWM_HZ = 1_000
) (
    input logic clk,
    input logic btnC,
    input logic RsRx,
    output logic RsTx,
    output logic pwm_ja1,
    output logic [7:0] led
);
    // Start-up reset and button synchronization. Press BTNC to clear settings.
    (* ASYNC_REG = "TRUE" *) logic [1:0] rst_pipe = 2'b11;
    always_ff @(posedge clk) rst_pipe <= {rst_pipe[0], btnC};
    wire rst = rst_pipe[1];

    logic [7:0] rx_data;
    logic rx_valid, rx_frame_error;
    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk), .rst(rst), .rx(RsRx),
        .data_out(rx_data), .data_valid(rx_valid), .frame_error(rx_frame_error)
    );

    logic [7:0] fifo_data;
    logic fifo_valid, fifo_full, fifo_empty, fifo_overflow, fifo_underflow;
    logic [3:0] fifo_count;
    logic fifo_pop;
    fifo_sync #(.DATA_WIDTH(8), .DEPTH(8)) command_queue (
        .clk(clk), .rst(rst), .wr_en(rx_valid), .rd_en(fifo_pop),
        .wr_data(rx_data), .rd_data(fifo_data), .rd_valid(fifo_valid),
        .full(fifo_full), .empty(fifo_empty), .count(fifo_count),
        .overflow(fifo_overflow), .underflow(fifo_underflow)
    );

    logic [7:0] tx_data;
    logic tx_start, tx_busy, tx_done;
    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) transmitter (
        .clk(clk), .rst(rst), .start(tx_start), .data_in(tx_data),
        .tx(RsTx), .busy(tx_busy), .done(tx_done)
    );

    logic [1:0] duty_cfg, freq_cfg, duty_active, freq_active;
    pwm_engine #(.CLK_HZ(CLK_HZ), .BASE_HZ(BASE_PWM_HZ)) waveform (
        .clk(clk), .rst(rst),
        .duty_cfg(duty_cfg), .freq_cfg(freq_cfg),
        .pwm_out(pwm_ja1), .active_duty(duty_active), .active_freq(freq_active)
    );

    typedef enum logic [1:0] {WAIT_CMD, WAIT_DATA, WAIT_TX} control_state_t;
    control_state_t control_state;
    logic activity, over_sticky, frame_sticky;
    wire [3:0] status_nibble = {freq_cfg, duty_cfg};
    assign fifo_pop = (control_state == WAIT_CMD) && !fifo_empty && !tx_busy && !rst;

    always_ff @(posedge clk) begin
        if (rst) begin
            control_state <= WAIT_CMD;
            duty_cfg <= 2'd0;
            freq_cfg <= 2'd0;
            tx_start <= 1'b0;
            tx_data <= '0;
            activity <= 1'b0;
            over_sticky <= 1'b0;
            frame_sticky <= 1'b0;
        end else begin
            tx_start <= 1'b0;
            if (fifo_overflow) over_sticky <= 1'b1;
            if (rx_frame_error) frame_sticky <= 1'b1;
            case (control_state)
                WAIT_CMD: begin
                    if (fifo_pop) control_state <= WAIT_DATA;
                end
                WAIT_DATA: begin
                    if (fifo_valid) begin
                        activity <= !activity;
                        // Echo recognized commands; reject unknown commands.
                        tx_data <= fifo_data;
                        case (fifo_data)
                            8'h30,8'h31,8'h32,8'h33:
                                duty_cfg <= fifo_data[1:0];
                            8'h34,8'h35,8'h36,8'h37:
                                freq_cfg <= fifo_data[1:0];
                            8'h3F: begin
                                tx_data <= (status_nibble < 10) ? (8'h30 + status_nibble) : (8'h41 + (status_nibble - 10));
                            end
                            default: tx_data <= 8'h21; // '!'
                        endcase
                        tx_start <= 1'b1;
                        control_state <= WAIT_TX;
                    end
                end
                WAIT_TX: if (tx_done) control_state <= WAIT_CMD;
                default: control_state <= WAIT_CMD;
            endcase
        end
    end

    // Desired configuration on LED0-3, actual PWM on LED4.
    // LED5: FIFO overflow sticky; LED6: framing error sticky; LED7: activity toggles.
    assign led = {activity,frame_sticky,over_sticky,pwm_ja1,freq_cfg,duty_cfg};
endmodule
