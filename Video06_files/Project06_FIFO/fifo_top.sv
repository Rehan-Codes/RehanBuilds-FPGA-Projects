// Basys 3 hardware wrapper. Press BTNC once after programming to initialize.
module fifo_top (
    input  logic clk,               // 100 MHz board clock
    input  logic btnC,              // reset
    input  logic btnU,              // push SW7:0 into FIFO
    input  logic btnD,              // pop oldest FIFO word
    input  logic [7:0] sw,
    output logic [15:0] led
);
    logic rst_meta, rst_sync;
    logic push_pulse, pop_pulse;
    logic [7:0] read_data;
    logic read_valid, full, empty, overflow, underflow;
    logic [3:0] count;
    logic overflow_sticky, underflow_sticky;

    // Synchronous reset request; all state is initialized by pressing BTNC.
    always_ff @(posedge clk) begin
        rst_meta <= btnC;
        rst_sync <= rst_meta;
    end

    button_press #(.DEBOUNCE_CYCLES(500_000)) push_btn (
        .clk(clk), .rst(rst_sync), .button_in(btnU), .pulse(push_pulse)
    );
    button_press #(.DEBOUNCE_CYCLES(500_000)) pop_btn (
        .clk(clk), .rst(rst_sync), .button_in(btnD), .pulse(pop_pulse)
    );

    fifo_sync #(.DATA_WIDTH(8), .DEPTH(8)) dut (
        .clk(clk), .rst(rst_sync),
        .wr_en(push_pulse), .rd_en(pop_pulse), .wr_data(sw),
        .rd_data(read_data), .rd_valid(read_valid),
        .full(full), .empty(empty), .count(count),
        .overflow(overflow), .underflow(underflow)
    );

    // Remember rejected operations so they remain visible on human-scale LEDs.
    always_ff @(posedge clk) begin
        if (rst_sync) begin
            overflow_sticky <= 1'b0;
            underflow_sticky <= 1'b0;
        end else begin
            if (overflow) overflow_sticky <= 1'b1;
            if (underflow) underflow_sticky <= 1'b1;
        end
    end

    assign led[7:0]   = read_data;       // last successfully popped byte
    assign led[8]     = empty;
    assign led[9]     = full;
    assign led[10]    = overflow_sticky;
    assign led[11]    = underflow_sticky;
    assign led[15:12] = count;           // 0..8 in binary
endmodule
