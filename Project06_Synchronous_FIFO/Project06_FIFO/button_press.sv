// Synchronizes and debounces one active-high pushbutton.
// Produces a single clock-cycle pulse per completed press.
module button_press #(
    parameter integer DEBOUNCE_CYCLES = 500_000  // 5 ms at 100 MHz
) (
    input  logic clk,
    input  logic rst,
    input  logic button_in,
    output logic pulse
);
    localparam integer W = (DEBOUNCE_CYCLES > 1)
                         ? $clog2(DEBOUNCE_CYCLES) : 1;
    logic sync1, sync2, stable;
    logic [W-1:0] counter;

    always_ff @(posedge clk) begin
        if (rst) begin
            sync1   <= 1'b0;
            sync2   <= 1'b0;
            stable  <= 1'b0;
            counter <= '0;
            pulse   <= 1'b0;
        end else begin
            sync1 <= button_in;
            sync2 <= sync1;
            pulse <= 1'b0;
            if (sync2 == stable) begin
                counter <= '0;
            end else if (counter == DEBOUNCE_CYCLES-1) begin
                stable  <= sync2;
                counter <= '0;
                if (sync2)
                    pulse <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end
endmodule
