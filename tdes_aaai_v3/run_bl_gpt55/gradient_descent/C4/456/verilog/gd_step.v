module gd_step #(
    parameter integer N      = 16,
    parameter integer M      = 8,
    parameter integer GRAD_W = 46,
    parameter integer STEP_W = GRAD_W + N
)(
    input  signed [N-1:0]      alpha,
    input  signed [GRAD_W-1:0] grad,
    output signed [STEP_W-1:0] step
);

    localparam integer PRODUCT_W = N + GRAD_W;

    wire signed [PRODUCT_W-1:0] alpha_ext;
    wire signed [PRODUCT_W-1:0] grad_ext;
    wire signed [PRODUCT_W-1:0] product;
    wire signed [PRODUCT_W-1:0] scaled_product;

    assign alpha_ext = {{GRAD_W{alpha[N-1]}}, alpha};
    assign grad_ext  = {{N{grad[GRAD_W-1]}}, grad};

    assign product = alpha_ext * grad_ext;

    generate
        if (M == 0) begin : gen_no_shift
            assign scaled_product = product;
        end else if (M >= PRODUCT_W) begin : gen_shift_all
            assign scaled_product = {PRODUCT_W{product[PRODUCT_W-1]}};
        end else begin : gen_shift
            assign scaled_product = product >>> M;
        end
    endgenerate

    generate
        if (STEP_W == PRODUCT_W) begin : gen_step_same_width
            assign step = scaled_product;
        end else if (STEP_W > PRODUCT_W) begin : gen_step_sign_extend
            assign step = {{(STEP_W-PRODUCT_W){scaled_product[PRODUCT_W-1]}}, scaled_product};
        end else begin : gen_step_truncate
            assign step = scaled_product[STEP_W-1:0];
        end
    endgenerate

endmodule