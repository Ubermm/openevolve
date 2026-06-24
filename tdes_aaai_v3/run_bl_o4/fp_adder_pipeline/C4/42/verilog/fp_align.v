module fp_align (
    input  [7:0]  exp_a,
    input  [7:0]  exp_b,
    input  [22:0] frac_a,
    input  [22:0] frac_b,
    input         sign_a,
    input         sign_b,
    output [26:0] mant_a,
    output [26:0] mant_b,
    output [7:0]  exp_max,
    output [4:0]  shift_amt
);

    //--------------------------------------------------------------------------
    // 1) Compute hidden‐bit and extend each mantissa to include three
    //    extra bits: guard (bit[2]), round (bit[1]), sticky (bit[0]).
    //--------------------------------------------------------------------------
    wire hidden_a = |exp_a;
    wire hidden_b = |exp_b;
    // ext_mant_*[26] = hidden, [25:3] = frac, [2:0] = {guard,round,sticky}=0
    wire [26:0] ext_mant_a = { hidden_a, frac_a, 3'b000 };
    wire [26:0] ext_mant_b = { hidden_b, frac_b, 3'b000 };

    //--------------------------------------------------------------------------
    // 2) Select larger exponent and compute shift amount (capped at 31)
    //--------------------------------------------------------------------------
    wire a_ge_b     = (exp_a >= exp_b);
    assign exp_max  = a_ge_b ? exp_a : exp_b;
    wire [7:0] dexp = a_ge_b ? (exp_a - exp_b)
                              : (exp_b - exp_a);
    assign shift_amt = (dexp > 8'd31) ? 5'd31 : dexp[4:0];

    //--------------------------------------------------------------------------
    // 3) Shift‐right with 3−bit sticky/round/guard generation
    //--------------------------------------------------------------------------
    function [26:0] shift_right_sticky3;
        input [26:0] in;
        input [4:0]  sh;
        reg   [26:0] tmp;
        reg          g, r, s;
    begin
        if (sh == 0) begin
            tmp = in;
        end else if (sh >= 27) begin
            // All bits shifted out → zero mantissa, sticky=1 if any in was 1
            tmp = 27'b0;
            tmp[0] = |in;
        end else begin
            // guard bit = first bit shifted out
            g = in[sh-1];
            // round bit = second bit shifted out (if exists)
            r = (sh >= 2) ? in[sh-2] : 1'b0;
            // sticky bit = OR of all lower bits beyond round
            if (sh > 2)
                s = |in[sh-3:0];
            else
                s = 1'b0;
            // shift down
            tmp = in >> sh;
            // insert new guard/round/sticky in LSBs
            tmp[2] = g;
            tmp[1] = r;
            tmp[0] = s;
        end
        shift_right_sticky3 = tmp;
    end
    endfunction

    //--------------------------------------------------------------------------
    // 4) Align smaller mantissa; larger mantissa is unshifted
    //--------------------------------------------------------------------------
    assign mant_a = a_ge_b
                    ? ext_mant_a
                    : shift_right_sticky3(ext_mant_a, shift_amt);

    assign mant_b = a_ge_b
                    ? shift_right_sticky3(ext_mant_b, shift_amt)
                    : ext_mant_b;

endmodule