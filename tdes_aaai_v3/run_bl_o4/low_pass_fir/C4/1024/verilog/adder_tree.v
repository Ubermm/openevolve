module adder_tree #(
    parameter integer TAP_CNT = 101,
    parameter integer PROD_W  = 36,
    parameter integer ACC_W   = 43,
    parameter integer SHIFT   = 20,
    parameter integer OUT_W   = 24
) (
    input  wire signed [PROD_W*TAP_CNT-1:0] prods,
    output wire signed [OUT_W-1:0]          data_out
);

    // Unpack flat product bus into array of signed products
    wire signed [PROD_W-1:0] prod_arr [0:TAP_CNT-1];
    genvar i;
    generate
        for (i = 0; i < TAP_CNT; i = i + 1) begin : unpack
            assign prod_arr[i] = prods[PROD_W*(i+1)-1 -: PROD_W];
        end
    endgenerate

    // Combinational accumulation of all products
    reg signed [ACC_W-1:0] acc_sum;
    integer j;
    always @* begin
        acc_sum = {ACC_W{1'b0}};
        for (j = 0; j < TAP_CNT; j = j + 1) begin
            acc_sum = acc_sum + prod_arr[j];
        end
    end

    // Fixed-point adjustment: drop low SHIFT bits
    localparam integer SHR_W = ACC_W - SHIFT;
    wire signed [SHR_W-1:0] shifted = acc_sum[ACC_W-1:SHIFT];

    // Sign-extend or truncate to OUT_W bits
    localparam integer EXT_W = OUT_W - SHR_W;
    generate
        if (EXT_W > 0) begin : gen_extend
            assign data_out = {{EXT_W{shifted[SHR_W-1]}}, shifted};
        end else if (EXT_W == 0) begin : gen_noext
            assign data_out = shifted;
        end else begin : gen_trunc
            assign data_out = shifted[SHR_W-1 -: OUT_W];
        end
    endgenerate

endmodule