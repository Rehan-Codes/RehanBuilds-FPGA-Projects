`timescale 1ns/1ps
module tb_pwm_top;
    // Simulation-only scale: 32 cycles at the lowest PWM frequency.
    // The FPGA hardware instead uses 100,000 cycles at 1 kHz.
    localparam integer TEST_CLK_HZ = 32_000;
    localparam integer BASE_HZ     = 1_000;
    localparam integer BASE_P      = TEST_CLK_HZ / BASE_HZ;

    logic clk = 0;
    always #5 clk = ~clk;
    logic btnC = 0;
    logic [3:0] sw = 0;
    wire [4:0] led;
    wire pwm_ja1;

    pwm_top #(.CLK_HZ(TEST_CLK_HZ), .BASE_PWM_HZ(BASE_HZ)) dut (
        .clk(clk), .btnC(btnC), .sw(sw), .led(led), .pwm_ja1(pwm_ja1)
    );

    integer comparisons = 0;
    integer configurations = 0;

    task automatic check(input bit condition, input string explanation);
        begin
            if (!condition) $fatal(1, "FAIL: %s at %0t", explanation, $time);
            comparisons = comparisons + 1;
        end
    endtask

    // Assert physical reset long enough for the input synchronizer.
    task automatic reset_with_switches(input integer freq, input integer duty);
        begin
            @(negedge clk);
            sw   = (freq << 2) | duty;
            btnC = 1'b1;
            repeat (6) @(negedge clk);
            btnC = 1'b0;
            repeat (4) @(negedge clk);
            check(led[3:0] === {2'(freq), 2'(duty)},
                  "active settings match switches after reset");
        end
    endtask

    task automatic verify_configuration(input integer freq, input integer duty);
        integer period;
        integer expected_high;
        integer i;
        begin
            period = BASE_P >> freq;
            expected_high = period * duty / 4;
            reset_with_switches(freq, duty);

            // White-box phase alignment; output expectations independent.
            while (dut.period_counter != 0) @(negedge clk);
            for (i = 0; i < period; i = i + 1) begin
                check(pwm_ja1 === (i < expected_high),
                      $sformatf("PWM mismatch at freq_sel=%0d duty_sel=%0d cycle=%0d", freq, duty, i));
                check(led[4] === pwm_ja1, "LED4 must mirror PWM output");
                check(led[3:0] === {2'(freq), 2'(duty)}, "setting display must remain stable");
                @(negedge clk);
            end
            configurations = configurations + 1;
            $display("PASS: freq select %0d (%0d Hz), duty %0d%%: %0d clocks, %0d HIGH",
                     freq, BASE_HZ * (1 << freq), duty * 25, period, expected_high);
        end
    endtask

    integer f, d, ticks;
    initial begin
        // Exhaustively test 4 frequency settings x 4 duty settings.
        for (f = 0; f < 4; f = f + 1)
            for (d = 0; d < 4; d = d + 1)
                verify_configuration(f, d);

        // Change config well before rollover; it must remain unchanged
        // during the current PWM period and become active on rollover.
        reset_with_switches(0, 1);   // 1 kHz, 25%
        while (dut.period_counter != 4) @(negedge clk);
        sw = 4'b0111;                 // 2 kHz, 75%
        ticks = 0;
        while (dut.period_counter != 0) begin
            @(negedge clk);
            if (dut.period_counter != 0)
                check(led[3:0] === 4'b0001, "mid-period switch changes must not alter active settings");
            ticks = ticks + 1;
            if (ticks > BASE_P + 3) $fatal(1, "FAIL: PWM counter did not roll over");
        end
        check(led[3:0] === 4'b0111, "new settings must apply at PWM period boundary");
        $display("PASS: glitchless configuration update at period boundary");
        $display("SUCCESS: Project 04 PWM testbench PASSED (%0d configurations, %0d comparisons).",
                 configurations, comparisons);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "FAIL: testbench timeout");
    end
endmodule
