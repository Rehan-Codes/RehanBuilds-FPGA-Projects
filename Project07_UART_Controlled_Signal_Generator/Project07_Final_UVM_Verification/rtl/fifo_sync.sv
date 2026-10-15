// RehanBuilds Project 06: Parameterized synchronous FIFO
// Single-clock, first-word registered on a successful read.
// Policy: full + simultaneous push/pop accepts BOTH operations.
//         empty + simultaneous push/pop accepts PUSH ONLY and signals underflow.
module fifo_sync #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DEPTH = 8
) (
    input  logic clk,
    input  logic rst,                // synchronous active-high reset
    input  logic wr_en,
    input  logic rd_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic rd_valid,          // one cycle for each accepted read
    output logic full,
    output logic empty,
    output logic [$clog2(DEPTH+1)-1:0] count,
    output logic overflow,          // one-cycle rejected-write indication
    output logic underflow          // one-cycle rejected-read indication
);
    localparam integer PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [PTR_W-1:0] wr_ptr, rd_ptr;
    logic write_ok, read_ok;

    assign full = (count == DEPTH);
    assign empty = (count == 0);
    assign read_ok = rd_en && !empty;
    // Allow a write on a full FIFO when the same edge also frees a slot.
    assign write_ok = wr_en && (!full || read_ok);

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr    <= '0;
            rd_ptr    <= '0;
            count     <= '0;
            rd_data   <= '0;
            rd_valid  <= 1'b0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else begin
            rd_valid  <= read_ok;
            overflow  <= wr_en && !write_ok;
            underflow <= rd_en && !read_ok;

            if (read_ok) begin
                // Nonblocking RHS sees old memory: safe when full and replacing
                // the oldest element in the same clock edge.
                rd_data <= mem[rd_ptr];
                rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1'b1;
            end

            if (write_ok) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1'b1;
            end

            case ({write_ok, read_ok})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
