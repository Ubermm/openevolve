`timescale 1ns/1ps

module fpm_round_pack #(
    parameter EXP_WIDTH  = 8,
    parameter MANT_WIDTH = 23,
    parameter WIDTH      = 1 + EXP_WIDTH + MANT_WIDTH
)(
    input  sign,
    input  signed [EXP_WIDTH+4:0] exp_unbiased,
    input  [MANT_WIDTH:0] sig,
    input  guard_bit,
    input  round_bit,
    input  sticky_bit,
    input  zero_product,
    input  [2:0] rnd_mode,
    output reg [WIDTH-1:0] product,
    output reg [2:0] exception_flags
);

    localparam integer BIAS_INT = (1 << (EXP_WIDTH-1)) - 1;

    localparam signed [EXP_WIDTH+4:0] MAX_UNBIASED =
        BIAS_INT[EXP_WIDTH+4:0];
    localparam signed [EXP_WIDTH+4:0] MIN_UNBIASED =
        (1 - BIAS_INT);

    localparam [2:0] RND_NEAREST_EVEN = 3'b000;
    localparam [2:0] RND_TOWARD_ZERO  = 3'b001;
    localparam [2:0] RND_DOWN         = 3'b010;
    localparam [2:0] RND_UP           = 3'b011;
    localparam [2:0] RND_NEAREST_MAX  = 3'b100;

    reg inexact;
    reg round_inc;
    reg [MANT_WIDTH+1:0] rounded_ext;
    reg [MANT_WIDTH:0] rounded_sig;
    reg signed [EXP_WIDTH+4:0] rounded_exp;
    reg [EXP_WIDTH-1:0] exp_field;
    reg overflow_to_inf;

    always @* begin
        product         = {WIDTH{1'b0}};
        exception_flags = 3'b000;

        inexact         = guard_bit | round_bit | sticky_bit;
        round_inc       = 1'b0;
        rounded_ext     = {(MANT_WIDTH+2){1'b0}};
        rounded_sig     = {(MANT_WIDTH+1){1'b0}};
        rounded_exp     = exp_unbiased;
        exp_field       = {EXP_WIDTH{1'b0}};
        overflow_to_inf = 1'b1;

        case (rnd_mode)
            RND_NEAREST_EVEN: begin
                round_inc = guard_bit & (round_bit | sticky_bit | sig[0]);
            end

            RND_TOWARD_ZERO: begin
                round_inc = 1'b0;
            end

            RND_DOWN: begin
                round_inc = sign & inexact;
            end

            RND_UP: begin
                round_inc = (~sign) & inexact;
            end

            RND_NEAREST_MAX: begin
                round_inc = guard_bit;
            end

            default: begin
                round_inc = guard_bit & (round_bit | sticky_bit | sig[0]);
            end
        endcase

        rounded_ext = {1'b0, sig} + {{(MANT_WIDTH+1){1'b0}}, round_inc};

        if (rounded_ext[MANT_WIDTH+1]) begin
            rounded_sig = rounded_ext[MANT_WIDTH+1:1];
            rounded_exp = exp_unbiased + {{(EXP_WIDTH+5){1'b0}}, 1'b1};
        end else begin
            rounded_sig = rounded_ext[MANT_WIDTH:0];
            rounded_exp = exp_unbiased;
        end

        if (zero_product) begin
            product         = {sign, {(WIDTH-1){1'b0}}};
            exception_flags = 3'b000;
        end else if (rounded_exp > MAX_UNBIASED) begin
            exception_flags = 3'b100;

            case (rnd_mode)
                RND_TOWARD_ZERO: begin
                    overflow_to_inf = 1'b0;
                end

                RND_DOWN: begin
                    overflow_to_inf = sign;
                end

                RND_UP: begin
                    overflow_to_inf = ~sign;
                end

                default: begin
                    overflow_to_inf = 1'b1;
                end
            endcase

            if (overflow_to_inf) begin
                product = {sign, {EXP_WIDTH{1'b1}}, {MANT_WIDTH{1'b0}}};
            end else begin
                product = {sign, ({EXP_WIDTH{1'b1}} - {{(EXP_WIDTH-1){1'b0}}, 1'b1}), {MANT_WIDTH{1'b1}}};
            end
        end else if (rounded_exp < MIN_UNBIASED) begin
            product         = {sign, {(WIDTH-1){1'b0}}};
            exception_flags = 3'b010;
        end else begin
            exp_field       = rounded_exp + BIAS_INT;
            product         = {sign, exp_field, rounded_sig[MANT_WIDTH-1:0]};
            exception_flags = 3'b000;
        end
    end

endmodule