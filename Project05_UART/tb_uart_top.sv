`timescale 1ns / 1ps
// Self-checking UART integration testbench. Runs with 10 simulated clocks/bit.
// The production top defaults to 100 MHz / 115200 baud.
module tb_uart_top;
    localparam integer TB_CLK_HZ = 1_000_000;
    localparam integer TB_BAUD = 100_000;
    localparam integer BIT_CLOCKS = TB_CLK_HZ / TB_BAUD;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic btnC = 1'b1;
    logic RsRx = 1'b1;
    wire RsTx;
    wire [8:0] led;
    integer checks = 0;
    integer echoed_frames = 0;

    uart_top #(.CLK_HZ(TB_CLK_HZ), .BAUD(TB_BAUD)) dut (
        .clk(clk), .btnC(btnC), .RsRx(RsRx), .RsTx(RsTx), .led(led)
    );

    // Count starts of echoed UART transmissions.
    always @(negedge RsTx) echoed_frames = echoed_frames + 1;

    task automatic send_byte(input logic [7:0] value, input logic good_stop);
        integer i;
        begin
            @(negedge clk);
            RsRx = 1'b0; // start
            repeat (BIT_CLOCKS) @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                RsRx = value[i];
                repeat (BIT_CLOCKS) @(negedge clk);
            end
            RsRx = good_stop; // stop must be HIGH
            repeat (BIT_CLOCKS) @(negedge clk);
            RsRx = 1'b1; // idle
        end
    endtask

    task automatic expect_echo(input logic [7:0] expected);
        logic [7:0] received;
        integer i;
        begin
            @(negedge RsTx); // beginning of FPGA echo start bit
            repeat (BIT_CLOCKS + BIT_CLOCKS/2) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                received[i] = RsTx; // UART sends LSB first
                repeat (BIT_CLOCKS) @(posedge clk);
            end
            if (RsTx !== 1'b1)
                $fatal(1, "FAIL: echoed byte missing stop bit");
            if (received !== expected)
                $fatal(1, "FAIL: echo expected %02h but got %02h", expected, received);
            checks = checks + 1;
        end
    endtask

    task automatic test_byte(input logic [7:0] value);
        begin
            fork
                send_byte(value, 1'b1);
                expect_echo(value);
            join
            repeat (3) @(posedge clk);
            if (led[7:0] !== value)
                $fatal(1, "FAIL: LED output expected %02h, got %02h", value, led[7:0]);
            checks = checks + 1;
            $display("PASS: received 0x%02h, displayed on LEDs, echoed over UART", value);
        end
    endtask

    integer prev_count;
    logic [7:0] old_led;
    initial begin
        repeat (10) @(negedge clk);
        btnC = 1'b0;
        repeat (5) @(negedge clk);

        test_byte(8'h55);
        test_byte(8'hA5);
        test_byte(8'h41); // 'A'
        test_byte(8'h31); // '1'
        test_byte(8'h00);
        test_byte(8'hFF);

        prev_count = echoed_frames;
        old_led = led[7:0];
        send_byte(8'h77, 1'b0); // corrupt stop bit
        repeat (4 * BIT_CLOCKS) @(negedge clk);
        if (led[8] !== 1'b1)
            $fatal(1, "FAIL: malformed stop bit did not latch error LED8");
        checks = checks + 1;
        if (led[7:0] !== old_led || echoed_frames !== prev_count)
            $fatal(1, "FAIL: malformed frame was accepted or echoed");
        checks = checks + 1;
        $display("PASS: malformed stop bit rejected and framing-error LED set");

        btnC = 1'b1;
        repeat (5) @(negedge clk);
        if (led !== 9'b0 || RsTx !== 1'b1)
            $fatal(1, "FAIL: reset did not clear LEDs and idle UART TX");
        checks = checks + 1;
        btnC = 1'b0;
        repeat (5) @(negedge clk);
        test_byte(8'h42); // ensure UART recovers after malformed frame/reset
        $display("PASS: receiver/transmitter recovered after reset");
        $display("SUCCESS: Project 05 UART testbench PASSED (%0d checks, 7 valid frames, 1 malformed frame).", checks);
        $finish;
    end

    initial begin
        #1000000; // absolute watchdog timeout, 1ms simulated time
        $fatal(1, "FAIL: UART testbench timeout");
    end
endmodule
