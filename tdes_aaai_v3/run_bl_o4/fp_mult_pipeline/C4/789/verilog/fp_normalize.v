module fp_normalize(
    input  [47:0]         mant_prod,
    input  signed [9:0]   exp_sum,
    input                 sign_in,
    input                 is_zero_a,
    input                 is_inf_a,
    input                 is_nan_a,
    input                 is_subnormal_a,
    input                 is_zero_b,
    input                 is_inf_b,
    input                 is_nan_b,
    input                 is_subnormal_b,
    output                sign_out,
    output signed [9:0]   exp_norm,
    output [23:0]         mant_norm,
    output                guard,
    output                round,
    output                sticky,
    output                is_zero_a_out,
    output                is_inf_a_out,
    output                is_nan_a_out,
    output                is_subnormal_a_out,
    output                is_zero_b_out,
    output                is_inf_b_out,
    output                is_nan_b_out,
    output                is_subnormal_b_out
);

    // Pass-through of input exception flags for downstream stages
    assign is_zero_a_out      = is_zero_a;
    assign is_inf_a_out       = is_inf_a;
    assign is_nan_a_out       = is_nan_a;
    assign is_subnormal_a_out = is_subnormal_a;
    assign is_zero_b_out      = is_zero_b;
    assign is_inf_b_out       = is_inf_b;
    assign is_nan_b_out       = is_nan_b;
    assign is_subnormal_b_out = is_subnormal_b;

    // detect special cases
    wire invalid_inf_zero = (is_inf_a & is_zero_b) | (is_inf_b & is_zero_a);
    wire any_nan    = is_nan_a | is_nan_b;
    wire any_inf    = (is_inf_a | is_inf_b) & ~invalid_inf_zero;
    wire any_zero   = (is_zero_a | is_zero_b) | invalid_inf_zero;

    // normalization shift decision and base normalized mantissa
    wire         norm_shift         = mant_prod[47];
    wire [23:0]  mant_norm_noshift  = mant_prod[46:23];
    wire [23:0]  mant_norm_shift    = mant_prod[47:24];
    wire         guard_noshift      = mant_prod[22];
    wire         guard_shift        = mant_prod[23];
    wire         round_noshift      = mant_prod[21];
    wire         round_shift        = mant_prod[22];
    wire         sticky_noshift     = |mant_prod[20:0];
    wire         sticky_shift       = |mant_prod[21:0];
    wire signed [9:0] exp_norm_base = exp_sum + norm_shift;

    // outputs
    reg        s_out;
    reg signed [9:0] e_out;
    reg [23:0] m_out;
    reg        g_out, r_out, st_out;

    always @* begin
        if (any_nan) begin
            // produce a quiet NaN: sign=0, exp=all 1s, mantissa MSB=1
            s_out  = 1'b0;
            e_out  = 10'b11_1111_1111;
            m_out  = 24'h400000;
            g_out  = 1'b0;
            r_out  = 1'b0;
            st_out = 1'b0;
        end else if (any_inf) begin
            // produce infinity: mantissa zero, exp all 1s
            s_out  = sign_in;
            e_out  = 10'b11_1111_1111;
            m_out  = 24'h000000;
            g_out  = 1'b0;
            r_out  = 1'b0;
            st_out = 1'b0;
        end else if (any_zero) begin
            // produce zero: mantissa zero, exp zero
            s_out  = sign_in;
            e_out  = 10'b0;
            m_out  = 24'h000000;
            g_out  = 1'b0;
            r_out  = 1'b0;
            st_out = 1'b0;
        end else begin
            // normal case: shift and extract bits
            s_out  = sign_in;
            e_out  = exp_norm_base;
            if (norm_shift) begin
                m_out  = mant_norm_shift;
                g_out  = guard_shift;
                r_out  = round_shift;
                st_out = sticky_shift;
            end else begin
                m_out  = mant_norm_noshift;
                g_out  = guard_noshift;
                r_out  = round_noshift;
                st_out = sticky_noshift;
            end
        end
    end

    assign sign_out  = s_out;
    assign exp_norm  = e_out;
    assign mant_norm = m_out;
    assign guard     = g_out;
    assign round     = r_out;
    assign sticky    = st_out;

endmodule