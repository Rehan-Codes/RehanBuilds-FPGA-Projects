`timescale 1ns / 1ps

module tb_sequencer_top;
    logic clk = 1'b0;
    logic btnC = 1'b0;
    logic [4:0] sw = 5'b10000; // Start paused.
    wire  [7:0] led;
    integer checks = 0;

    // A reduced clock frequency makes a full 8/4/2/1 Hz-equivalent
    // sequence take tens of cycles instead of millions of cycles.
    sequencer_top #(.CLK_HZ(80), .DEBOUNCE_CYCLES(3)) dut (
        .clk(clk), .btnC(btnC), .sw(sw), .led(led)
    );

    always #5 clk = ~clk;

    task automatic cycles(input integer n);
        repeat (n) begin
            @(posedge clk);
            #1;
        end
    endtask

    task automatic assert_led(input logic [7:0] expected, input string label);
        if (led !== expected) begin
            $error("FAIL %s: LED=%b expected=%b at %0t", label, led, expected, $time);
            $fatal(1);
        end
        checks = checks + 1;
    endtask

    task automatic wait_for_led(
        input logic [7:0] expected,
        input integer max_cycles,
        input string label
    );
        for (integer n = 0; n < max_cycles; n = n + 1) begin
            cycles(1);
            if (led === expected) begin
                checks = checks + 1;
                return;
            end
        end
        $error("FAIL %s: never observed LED=%b; observed=%b at %0t",
               label, expected, led, $time);
        $fatal(1);
    endtask

    initial begin
        // Initial reset while paused. 3 debounce + 2 sync cycles.
        cycles(8);
        btnC = 1'b1;
        cycles(8);
        assert_led(8'h01, "reset initialization");
        btnC = 1'b0;
        cycles(8);
        assert_led(8'h01, "paused after reset");

        // 00: rotate toward higher LED index; every 10 cycles.
        sw = 5'b00000;
        wait_for_led(8'h02, 20, "rotate left: LED1");
        wait_for_led(8'h04, 20, "rotate left: LED2");
        wait_for_led(8'h08, 20, "rotate left: LED3");
        $display("PASS: rotate left");

        // Pause freezes both pattern and tick counter.
        sw = 5'b10000;
        cycles(6);
        assert_led(8'h08, "pause engaged");
        cycles(40);
        assert_led(8'h08, "pause holds pattern");
        $display("PASS: pause");

        // 01: mode switch resets pattern; then rotate right.
        sw = 5'b10001;
        cycles(8);
        assert_led(8'h01, "mode switch resets pattern");
        sw = 5'b00001;
        wait_for_led(8'h80, 20, "rotate right: LED7");
        wait_for_led(8'h40, 20, "rotate right: LED6");
        $display("PASS: rotate right");

        // 10: bounce 0 -> 7 -> 0 (without repeating endpoints).
        sw = 5'b10010;
        cycles(8);
        assert_led(8'h01, "bounce mode initial pattern");
        sw = 5'b00010;
        wait_for_led(8'h02, 20, "bounce bit1");
        wait_for_led(8'h04, 20, "bounce bit2");
        wait_for_led(8'h08, 20, "bounce bit3");
        wait_for_led(8'h10, 20, "bounce bit4");
        wait_for_led(8'h20, 20, "bounce bit5");
        wait_for_led(8'h40, 20, "bounce bit6");
        wait_for_led(8'h80, 20, "bounce bit7");
        wait_for_led(8'h40, 20, "bounce returns bit6");
        $display("PASS: bounce FSM");

        // 11: binary count, including initial 0.
        sw = 5'b10011;
        cycles(8);
        assert_led(8'h00, "count mode initializes to zero");
        sw = 5'b00011;
        wait_for_led(8'h01, 20, "count 1");
        wait_for_led(8'h02, 20, "count 2");
        wait_for_led(8'h03, 20, "count 3");
        $display("PASS: binary counter");

        // Switch to slowest speed (80 cycles per update at CLK_HZ=80).
        sw = 5'b11111; // paused, speed=11, mode=11
        cycles(8);
        assert_led(8'h03, "speed update preserves value");
        sw = 5'b01111; // unpaused, speed=11, mode=11
        cycles(40);
        assert_led(8'h03, "slow rate does not update early");
        wait_for_led(8'h04, 60, "slow rate eventually advances");
        $display("PASS: speed selection");

        // Reset while running.
        btnC = 1'b1;
        cycles(8);
        assert_led(8'h01, "reset while running");
        btnC = 1'b0;
        cycles(8);

        $display("SUCCESS: Project 03 controller testbench PASSED (%0d checks).", checks);
        $finish;
    end

    initial begin
        #100_000;
        $fatal(1, "FAIL: Simulation timed out.");
    end
endmodule
