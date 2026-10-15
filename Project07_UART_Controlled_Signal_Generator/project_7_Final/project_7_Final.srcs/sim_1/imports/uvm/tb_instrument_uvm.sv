`timescale 1ns / 1ps
// Vivado 2025.2 XSim + precompiled UVM 1.2. No FPGA/RTL changes.
module tb_instrument_uvm;
    import uvm_pkg::*;
    import instrument_uvm_pkg::*;
    logic clk=1'b0;
    always #5 clk=~clk;
    instrument_uvm_if bus(clk);

    instrument_top #(.CLK_HZ(32_000),.BAUD(1_000),.BASE_PWM_HZ(1_000)) dut (
        .clk(clk),.btnC(bus.btnC),.RsRx(bus.RsRx),.RsTx(bus.RsTx),
        .pwm_ja1(bus.pwm_out),.led(bus.led)
    );
    // White-box signals for simulation-only SVA and PWM/FIFO checkers.
    assign bus.rst=dut.rst;
    assign bus.active_freq=dut.waveform.active_freq;
    assign bus.active_duty=dut.waveform.active_duty;
    assign bus.pwm_counter=dut.waveform.period_counter;
    assign bus.fifo_count=dut.fifo_count;
    assign bus.fifo_full=dut.fifo_full;
    assign bus.fifo_empty=dut.fifo_empty;
    assign bus.fifo_pop=dut.fifo_pop;
    assign bus.fifo_overflow=dut.fifo_overflow;
    assign bus.fifo_underflow=dut.fifo_underflow;
    assign bus.tx_busy=dut.tx_busy;
    assign bus.rx_frame_error=dut.rx_frame_error;

    // Eight real concurrent assertions, separate from UVM procedural checkers.
    ap_count_bound: assert property (@(posedge clk)
        disable iff(bus.rst) (bus.fifo_count<=4'd8))
        else $fatal(1,"SVA FAIL: FIFO occupancy >8");
    ap_full_flag: assert property (@(posedge clk)
        disable iff(bus.rst) (bus.fifo_full == (bus.fifo_count==8)))
        else $fatal(1,"SVA FAIL: FIFO full flag");
    ap_empty_flag: assert property (@(posedge clk)
        disable iff(bus.rst) (bus.fifo_empty == (bus.fifo_count==0)))
        else $fatal(1,"SVA FAIL: FIFO empty flag");
    ap_no_empty_pop: assert property (@(posedge clk)
        disable iff(bus.rst) !(bus.fifo_pop && bus.fifo_empty))
        else $fatal(1,"SVA FAIL: popped empty FIFO");
    ap_pwm_zero: assert property (@(posedge clk)
        disable iff(bus.rst) (bus.active_duty==0 |-> !bus.pwm_out))
        else $fatal(1,"SVA FAIL: output high at zero duty");
    ap_pwm_range: assert property (@(posedge clk)
        disable iff(bus.rst) (int'(bus.pwm_counter) < (32 >> int'(bus.active_freq))))
        else $fatal(1,"SVA FAIL: PWM period counter out of bounds");
    ap_commit_boundary: assert property (@(posedge clk)
        disable iff(bus.rst)
        (($changed(bus.active_freq) || $changed(bus.active_duty)) |-> (bus.pwm_counter==0)))
        else $fatal(1,"SVA FAIL: PWM setting changed off boundary");
    ap_led_tracks_pwm: assert property (@(posedge clk)
        disable iff(bus.rst) (bus.led[4]==bus.pwm_out))
        else $fatal(1,"SVA FAIL: PWM LED mismatch");

    initial begin
        bus.btnC=1'b1;
        bus.RsRx=1'b1;
        repeat (10) @(negedge clk);
        bus.btnC=1'b0;
    end
    initial begin
        uvm_config_db #(virtual instrument_uvm_if)::set(null,"*","vif",bus);
        run_test("instrument_uvm_test");
    end
    initial begin
        #20_000_000;
        $fatal(1,"UVM watchdog: 20ms timeout");
    end
endmodule
