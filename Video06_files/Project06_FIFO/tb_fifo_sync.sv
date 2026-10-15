`timescale 1ns/1ps
// Transaction-level scoreboard with deterministic random stimulus.
// Checks data ordering, occupancy, flags and read_data retention on EVERY cycle.
module tb_fifo_sync;
    localparam integer DEPTH = 8;
    logic clk = 1'b0;
    always #5 clk = ~clk;             // 100 MHz simulation clock

    logic rst = 1'b1;
    logic wr_en = 1'b0, rd_en = 1'b0;
    logic [7:0] wr_data = 8'h00;
    wire [7:0] rd_data;
    wire rd_valid, full, empty, overflow, underflow;
    wire [3:0] count;

    fifo_sync #(.DATA_WIDTH(8), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .wr_data(wr_data), .rd_data(rd_data), .rd_valid(rd_valid),
        .full(full), .empty(empty), .count(count),
        .overflow(overflow), .underflow(underflow)
    );

    logic [7:0] expected_mem [0:DEPTH-1];
    integer head = 0, tail = 0, occupancy = 0;
    logic [7:0] expected_last_data = 8'h00;
    integer checks = 0, accepted_writes = 0, accepted_reads = 0;
    integer blocked_writes = 0, blocked_reads = 0, dual_accepts = 0;
    logic [31:0] rng = 32'h1ACEB00C;

    // All comparisons occur AFTER the DUT's nonblocking assignments settle.
    task automatic check_state(
        input bit expected_valid,
        input bit expected_overflow,
        input bit expected_underflow
    );
        begin
            if (count !== occupancy || full !== (occupancy == DEPTH) ||
                empty !== (occupancy == 0) ||
                rd_valid !== expected_valid ||
                overflow !== expected_overflow ||
                underflow !== expected_underflow ||
                rd_data !== expected_last_data) begin
                $display("EXPECTED: count=%0d full=%0b empty=%0b valid=%0b over=%0b under=%0b data=%02h",
                         occupancy, occupancy == DEPTH, occupancy == 0,
                         expected_valid, expected_overflow, expected_underflow,
                         expected_last_data);
                $display("ACTUAL:   count=%0d full=%0b empty=%0b valid=%0b over=%0b under=%0b data=%02h",
                         count, full, empty, rd_valid, overflow, underflow, rd_data);
                $fatal(1, "FAIL: FIFO scoreboard mismatch at check %0d, time %0t", checks, $time);
            end
            checks = checks + 1;
        end
    endtask

    task automatic reset_fifo;
        begin
            @(negedge clk);
            rst = 1'b1;
            wr_en = 1'b0;
            rd_en = 1'b0;
            @(posedge clk);
            #1;
            head = 0;
            tail = 0;
            occupancy = 0;
            expected_last_data = 8'h00;
            check_state(0, 0, 0);
            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task automatic step_fifo(input bit push, input bit pop,
                             input logic [7:0] data_byte);
        bit can_pop, can_push;
        begin
            @(negedge clk);
            wr_en = push;
            rd_en = pop;
            wr_data = data_byte;
            can_pop = pop && occupancy > 0;
            can_push = push && (occupancy < DEPTH || can_pop);

            // Read reference *before* writing: guarantees correct behavior
            // on simultaneous read/write while the FIFO is full.
            if (can_pop) begin
                expected_last_data = expected_mem[head];
                head = (head + 1) % DEPTH;
                accepted_reads = accepted_reads + 1;
            end
            if (can_push) begin
                expected_mem[tail] = data_byte;
                tail = (tail + 1) % DEPTH;
                accepted_writes = accepted_writes + 1;
            end
            if (push && !can_push) blocked_writes = blocked_writes + 1;
            if (pop && !can_pop) blocked_reads = blocked_reads + 1;
            if (can_pop && can_push) dual_accepts = dual_accepts + 1;
            if (can_push && !can_pop) occupancy = occupancy + 1;
            if (can_pop && !can_push) occupancy = occupancy - 1;

            @(posedge clk);
            #1;
            check_state(can_pop, (push && !can_push), (pop && !can_pop));
        end
    endtask

    initial begin : run_tests
        reset_fifo();
        if (!empty) $fatal(1, "FIFO should start empty");
        $display("PASS: synchronous reset and initial empty flag");

        // Fill to full with a known ordered sequence.
        for (integer i=0; i<DEPTH; i=i+1)
            step_fifo(1, 0, 8'h20 + i);
        if (!full) $fatal(1, "FIFO should be full after 8 writes");
        step_fifo(1, 0, 8'hEE);    // rejected push
        $display("PASS: fill-to-full and rejected-write overflow flag");

        // Read three, write three, exercise wrapping pointers.
        for (integer i=0; i<3; i=i+1)
            step_fifo(0, 1, 8'h00);
        for (integer i=0; i<3; i=i+1)
            step_fifo(1, 0, 8'hA0 + i);
        $display("PASS: wraparound and FIFO ordering");

        // Full: one pop and one push on same edge must both succeed.
        step_fifo(1, 1, 8'hF1);
        if (!full) $fatal(1, "FIFO should remain full after dual operation");
        $display("PASS: simultaneous read/write at full occupancy");

        for (integer i=0; i<DEPTH; i=i+1)
            step_fifo(0, 1, 8'h00);
        if (!empty) $fatal(1, "FIFO should be empty after drain");
        step_fifo(0, 1, 8'h00);  // rejected pop
        $display("PASS: drain-to-empty and rejected-read underflow flag");

        step_fifo(1, 1, 8'hD3); // empty: push accepted, pop rejected
        if (occupancy != 1) $fatal(1, "Empty dual-op policy violated");
        step_fifo(0, 1, 8'h00);
        $display("PASS: simultaneous push/pop at empty boundary");

        step_fifo(1, 0, 8'hBE);
        reset_fifo();             // flush occupied data and clear flags
        step_fifo(1, 0, 8'hEF);
        step_fifo(0, 1, 8'h00);
        $display("PASS: reset during traffic and recovery");

        for (integer j=0; j<2000; j=j+1) begin
            // xorshift32: reproducible randomized reads, writes and data
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step_fifo(rng[0], rng[7], rng[23:16]);
        end
        $display("PASS: 2000 reproducible randomized read/write transactions");
        if (blocked_writes == 0 || blocked_reads == 0 || dual_accepts == 0)
            $fatal(1, "FAIL: expected full/empty/dual-operation coverage missing");
        $display("PASS: coverage: blocked writes=%0d, blocked reads=%0d, simultaneous accepted=%0d",
                 blocked_writes, blocked_reads, dual_accepts);
        $display("SUCCESS: Project 06 FIFO testbench PASSED (%0d checks, %0d writes, %0d reads, 2000 random transactions).",
                 checks, accepted_writes, accepted_reads);
        $finish;
    end
endmodule
