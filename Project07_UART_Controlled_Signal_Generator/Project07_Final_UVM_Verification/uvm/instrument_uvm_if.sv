`timescale 1ns / 1ps
// SIMULATION ONLY. Existing FPGA ports/RTL remain unchanged.
interface instrument_uvm_if(input logic clk);
    logic btnC = 1'b1;
    logic RsRx = 1'b1;
    logic RsTx;
    logic pwm_out;
    logic [7:0] led;
    logic rst;
    logic [1:0] active_freq, active_duty;
    logic [5:0] pwm_counter;
    logic [3:0] fifo_count;
    logic fifo_full, fifo_empty, fifo_pop;
    logic fifo_overflow, fifo_underflow;
    logic tx_busy;
    logic rx_frame_error;
endinterface
