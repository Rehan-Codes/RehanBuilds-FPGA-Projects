`timescale 1ns / 1ps
// Basys 3 USB-UART demo, 115200 8N1.
// PC byte -> LEDs[7:0] and echo same byte back to PC.
// LED8 latches a malformed stop bit; BTNC clears it.
// One-byte echo staging register; PC should send one byte and read its echo.
module uart_top #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer BAUD   = 115_200
) (
    input  logic       clk,
    input  logic       btnC,
    input  logic       RsRx,
    output logic       RsTx,
    output logic [8:0] led
);
    logic [7:0] rx_data;
    logic rx_valid, rx_frame_error;
    logic [7:0] tx_data;
    logic tx_start, tx_busy;
    logic pending;
    logic [7:0] pending_data;
    logic tx_done;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) receiver (
        .clk(clk), .rst(btnC), .rx(RsRx),
        .data_out(rx_data), .data_valid(rx_valid), .frame_error(rx_frame_error)
    );

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) transmitter (
        .clk(clk), .rst(btnC), .start(tx_start), .data_in(tx_data),
        .tx(RsTx), .busy(tx_busy), .done(tx_done)
    );

    always_ff @(posedge clk) begin
        if (btnC) begin
            led <= '0;
            tx_data <= '0;
            tx_start <= 1'b0;
            pending <= 1'b0;
            pending_data <= '0;
        end else begin
            tx_start <= 1'b0;
            if (pending && !tx_busy && !tx_start) begin
                tx_data <= pending_data;
                tx_start <= 1'b1;
                pending <= 1'b0;
            end
            if (rx_valid) begin
                led[7:0] <= rx_data;
                pending_data <= rx_data;
                pending <= 1'b1;
            end
            if (rx_frame_error) led[8] <= 1'b1;
        end
    end
endmodule
