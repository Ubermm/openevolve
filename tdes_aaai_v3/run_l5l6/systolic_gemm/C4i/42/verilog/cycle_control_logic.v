`ifndef CYCLE_CONTROL_LOGIC_V
`define CYCLE_CONTROL_LOGIC_V

module cycle_control_logic(
    cycle_count,
    next_cycle_count,
    done_next
);
    input  [3:0] cycle_count;
    output reg [3:0] next_cycle_count;
    output reg       done_next;

    always @* begin
        if (cycle_count < 4'd9) begin
            next_cycle_count = cycle_count + 4'd1;
        end else begin
            next_cycle_count = cycle_count;
        end

        done_next = (cycle_count >= 4'd8);
    end

endmodule

`endif