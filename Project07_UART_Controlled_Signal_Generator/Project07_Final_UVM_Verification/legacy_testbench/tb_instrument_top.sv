`timescale 1ns / 1ps
// Self-checking integrated UART -> FIFO -> registers -> PWM + UART reply test.
// Short simulated clock periods preserve all 4 PWM frequency/duty ratios.
module tb_instrument_top;
    localparam integer TB_CLK_HZ = 32_000;
    localparam integer TB_BAUD = 1_000;
    localparam integer TB_BASE_HZ = 1_000;
    localparam integer BIT_CLOCKS = TB_CLK_HZ / TB_BAUD; // 32 clock ticks / bit

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic btnC = 1'b1;
    logic RsRx = 1'b1;
    wire RsTx, pwm_ja1;
    wire [7:0] led;
    integer checks = 0;
    integer commands = 0;
    integer pwm_periods_checked = 0;

    instrument_top #(
        .CLK_HZ(TB_CLK_HZ), .BAUD(TB_BAUD), .BASE_PWM_HZ(TB_BASE_HZ)
    ) dut (
        .clk(clk), .btnC(btnC), .RsRx(RsRx), .RsTx(RsTx),
        .pwm_ja1(pwm_ja1), .led(led)
    );

    task automatic send_uart(input logic [7:0] value, input bit good_stop);
        integer i;
        begin
            @(negedge clk);
            RsRx = 1'b0; // start
            repeat (BIT_CLOCKS) @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                RsRx = value[i];
                repeat (BIT_CLOCKS) @(negedge clk);
            end
            RsRx = good_stop;
            repeat (BIT_CLOCKS) @(negedge clk);
            RsRx = 1'b1;
        end
    endtask

    task automatic expect_uart(input logic [7:0] expected);
        logic [7:0] received;
        integer i;
        begin
            @(negedge RsTx);
            repeat (BIT_CLOCKS + BIT_CLOCKS/2) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                received[i] = RsTx;
                repeat (BIT_CLOCKS) @(posedge clk);
            end
            if (RsTx !== 1'b1)
                $fatal(1, "UART TX stop bit low");
            if (received !== expected)
                $fatal(1, "UART reply mismatch: expected %02h, got %02h", expected, received);
            checks = checks + 1;
        end
    endtask

    task automatic transact(input logic [7:0] cmd, input logic [7:0] reply);
        begin
            fork
                send_uart(cmd, 1'b1);
                expect_uart(reply);
            join
            commands = commands + 1;
            repeat (4) @(posedge clk);
            $display("PASS: UART command %c (0x%02h) -> response %c (0x%02h)",cmd,cmd,reply,reply);
        end
    endtask

    task automatic verify_pwm(input integer frequency_index, input integer duty_index);
        integer n, high_ticks, t;
        begin
            n = (TB_CLK_HZ/TB_BASE_HZ) >> frequency_index;
            high_ticks = (n * duty_index) / 4;
            // Allow next PWM period boundary to commit requested settings.
            repeat (65) @(negedge clk);
            if (dut.waveform.active_freq !== frequency_index[1:0] ||
                dut.waveform.active_duty !== duty_index[1:0])
                $fatal(1, "PWM config not committed: freq=%0d duty=%0d",frequency_index,duty_index);
            while (dut.waveform.period_counter !== 0) @(negedge clk);
            for (t = 0; t < n; t = t + 1) begin
                if (pwm_ja1 !== (t < high_ticks))
                    $fatal(1, "PWM mismatch freq=%0d duty=%0d tick=%0d (got %b)",
                           frequency_index,duty_index,t,pwm_ja1);
                checks = checks + 1;
                @(negedge clk);
            end
            pwm_periods_checked = pwm_periods_checked + 1;
            $display("PASS: PWM period at frequency index %0d duty index %0d: %0d ticks, %0d high",
                     frequency_index,duty_index,n,high_ticks);
        end
    endtask

    initial begin
        // Establish reset once all RTL has started, then release it.
        repeat (10) @(negedge clk);
        btnC = 1'b0;
        repeat (10) @(negedge clk);
        if (led[3:0] !== 4'b0000 || RsTx !== 1'b1)
            $fatal(1, "Bad startup reset defaults");
        checks = checks + 1;
        $display("PASS: startup reset and initial configuration");

        // Set duty 50% and check physical PWM logic output cycle-by-cycle.
        transact("2", "2");
        verify_pwm(0, 2);
        transact("?", "2");     // 0x2 = freq=0, duty=2

        // Set frequency 4 kHz and recheck the PWM periods.
        transact("6", "6");
        verify_pwm(2, 2);
        transact("?", "A");     // 0xA = freq=2, duty=2
        transact("1", "1");
        verify_pwm(2, 1);
        transact("7", "7");
        verify_pwm(3, 1);
        transact("?", "D");     // 0xD = freq=3, duty=1

        // Unrecognized command produces a NAK and must not change configuration.
        transact("Z", "!");
        if (led[3:0] !== 4'b1101)
            $fatal(1, "Unknown command changed configuration");
        checks = checks + 1;
        $display("PASS: unknown command rejected without changing settings");

        // Burst three bytes while transmit responses are pending. They must
        // emerge in the same order, through the integrated receive FIFO.
        fork
            begin
                send_uart("0", 1'b1);
                send_uart("5", 1'b1);
                send_uart("3", 1'b1);
            end
            begin
                expect_uart("0");
                expect_uart("5");
                expect_uart("3");
            end
        join
        commands = commands + 3;
        repeat (100) @(negedge clk);
        if (led[3:0] !== 4'b0111) // freq=1 from 5, duty=3
            $fatal(1, "Burst command ordering wrong, led[3:0]=%b",led[3:0]);
        checks = checks + 1;
        verify_pwm(1,3);
        $display("PASS: back-to-back commands buffered and applied in order");

        // Malformed stop bit should latch an error and not change settings.
        send_uart("2", 1'b0);
        repeat (4*BIT_CLOCKS) @(negedge clk);
        if (led[6] !== 1'b1 || led[3:0] !== 4'b0111)
            $fatal(1, "Bad frame incorrectly accepted or framing LED not set");
        checks = checks + 1;
        $display("PASS: malformed UART stop bit rejected");

        // Button reset clears registers; the UART remains usable afterward.
        @(negedge clk);
        btnC = 1'b1;
        repeat (7) @(negedge clk);
        btnC = 1'b0;
        repeat (15) @(negedge clk);
        if (led[3:0] !== 4'b0000 || led[6] !== 1'b0)
            $fatal(1, "Reset failed to clear configuration/error");
        checks = checks + 1;
        transact("?", "0");
        $display("PASS: recovery after reset");
        $display("SUCCESS: Project 07 integrated testbench PASSED (%0d checks, %0d commands, %0d PWM periods).",
                 checks, commands, pwm_periods_checked);
        $finish;
    end
    initial begin
        #1000000; // watchdog: 1ms simulation time
        $fatal(1, "FAIL: Project 07 simulation timed out");
    end
endmodule
