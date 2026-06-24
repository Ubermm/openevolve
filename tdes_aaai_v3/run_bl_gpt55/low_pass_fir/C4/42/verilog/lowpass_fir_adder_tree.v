module lowpass_fir_adder_tree #(
    parameter TERM_CNT = 51,
    parameter TERM_W   = 37,
    parameter ACC_W    = 64
) (
    input  signed [TERM_CNT*TERM_W-1:0] terms,
    output reg signed [ACC_W-1:0]       acc
);

    integer i;
    reg signed [TERM_W-1:0] term_i;

    always @* begin
        acc = {ACC_W{1'b0}};

        for (i = 0; i < TERM_CNT; i = i + 1) begin
            term_i = terms[i*TERM_W +: TERM_W];
            acc = acc + {{(ACC_W-TERM_W){term_i[TERM_W-1]}}, term_i};
        end
    end

endmodule