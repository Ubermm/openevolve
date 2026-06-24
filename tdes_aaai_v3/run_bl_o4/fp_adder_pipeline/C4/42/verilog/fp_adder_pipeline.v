// Top-level pipelined IEEE-754 single-precision FP adder/subtractor
// Pipeline depth = 5 stages
module fp_adder_pipeline #(
    parameter LATENCY = 5
) (
    input              clk,
    input              rst,
    input      [31:0]  a,
    input      [31:0]  b,
    input              add_sub,    // 0: add, 1: subtract
    input              valid_in,
    output reg [31:0]  result,
    output reg         valid_out
);

    // Pipeline registers for control/valid
    reg [LATENCY-1:0]                    vld;
    always @(posedge clk) begin
        if (rst) vld <= 0;
        else     vld <= {vld[LATENCY-2:0], valid_in};
        valid_out <= vld[LATENCY-1];
    end

    // -------------------
    // Stage 1: Unpack
    // -------------------
    wire        sign_a, sign_b;
    wire [7:0]  exp_a, exp_b;
    wire [22:0] frac_a, frac_b;
    wire        is_zero_a, is_zero_b;
    wire        is_inf_a,  is_inf_b;
    wire        is_nan_a,  is_nan_b;
    fp_unpack u_unpack (
        .a(a), .b(b),
        .sign_a(sign_a), .sign_b(sign_b),
        .exp_a(exp_a),   .exp_b(exp_b),
        .frac_a(frac_a), .frac_b(frac_b),
        .is_zero_a(is_zero_a), .is_zero_b(is_zero_b),
        .is_inf_a(is_inf_a),   .is_inf_b(is_inf_b),
        .is_nan_a(is_nan_a),   .is_nan_b(is_nan_b)
    );
    // pipeline regs
    reg        sign_a_s1, sign_b_s1;
    reg [7:0]  exp_a_s1, exp_b_s1;
    reg [22:0] frac_a_s1, frac_b_s1;
    reg        z_a_s1, z_b_s1, i_a_s1, i_b_s1, n_a_s1, n_b_s1, op_s1;
    always @(posedge clk) if (!rst) begin
        sign_a_s1 <= sign_a; sign_b_s1 <= sign_b;
        exp_a_s1  <= exp_a;  exp_b_s1  <= exp_b;
        frac_a_s1 <= frac_a; frac_b_s1 <= frac_b;
        z_a_s1    <= is_zero_a; z_b_s1 <= is_zero_b;
        i_a_s1    <= is_inf_a;   i_b_s1 <= is_inf_b;
        n_a_s1    <= is_nan_a;   n_b_s1 <= is_nan_b;
        op_s1     <= add_sub;
    end

    // -------------------
    // Stage 2: Align
    // -------------------
    wire [7:0]  exp_max2;
    wire [4:0]  shift;
    wire [24:0] mant_a2, mant_b2;
    fp_align u_align (
        .exp_a(exp_a_s1), .exp_b(exp_b_s1),
        .frac_a(frac_a_s1), .frac_b(frac_b_s1),
        .sign_a(sign_a_s1), .sign_b(sign_b_s1),
        .mant_a(mant_a2), .mant_b(mant_b2),
        .exp_max(exp_max2), .shift_amt(shift)
    );
    // regs
    reg [24:0] mant_a_s2, mant_b_s2;
    reg [7:0]  exp_max_s2;
    reg        sign_a_s2, sign_b_s2, op_s2;
    reg        z_a_s2, z_b_s2, i_a_s2, i_b_s2, n_a_s2, n_b_s2;
    always @(posedge clk) if (!rst) begin
        mant_a_s2  <= mant_a2;  mant_b_s2 <= mant_b2;
        exp_max_s2 <= exp_max2;
        sign_a_s2  <= sign_a_s1; sign_b_s2 <= sign_b_s1;
        op_s2      <= op_s1;
        z_a_s2 <= z_a_s1; z_b_s2 <= z_b_s1;
        i_a_s2 <= i_a_s1; i_b_s2 <= i_b_s1;
        n_a_s2 <= n_a_s1; n_b_s2 <= n_b_s1;
    end

    // -------------------
    // Stage 3: Add/Sub
    // -------------------
    wire [25:0] raw_sum3;
    wire        raw_sign3;
    fp_add_sub u_addsub (
        .mant_a(mant_a_s2), .mant_b(mant_b_s2),
        .sign_a(sign_a_s2), .sign_b(sign_b_s2),
        .add_sub(op_s2),
        .sum(raw_sum3), .sign_out(raw_sign3)
    );
    // regs
    reg [25:0] raw_sum_s3;
    reg [7:0]  exp_max_s3;
    reg        raw_sign_s3, op_s3;
    reg        z_a_s3, z_b_s3, i_a_s3, i_b_s3, n_a_s3, n_b_s3;
    always @(posedge clk) if (!rst) begin
        raw_sum_s3 <= raw_sum3;
        raw_sign_s3<= raw_sign3;
        exp_max_s3 <= exp_max_s2;
        op_s3      <= op_s2;
        z_a_s3 <= z_a_s2; z_b_s3 <= z_b_s2;
        i_a_s3 <= i_a_s2; i_b_s3 <= i_b_s2;
        n_a_s3 <= n_a_s2; n_b_s3 <= n_b_s2;
    end

    // -------------------
    // Stage 4: Normalize
    // -------------------
    wire [7:0]  exp_n4;
    wire [25:0] norm_m4;
    fp_normalize u_norm (
        .raw_sum(raw_sum_s3), .exp_in(exp_max_s3),
        .exp_out(exp_n4), .mant_out(norm_m4)
    );
    // regs
    reg [25:0] norm_m_s4;
    reg [7:0]  exp_s4;
    reg        raw_sign_s4, op_s4;
    reg        z_a_s4, z_b_s4, i_a_s4, i_b_s4, n_a_s4, n_b_s4;
    always @(posedge clk) if (!rst) begin
        norm_m_s4 <= norm_m4;
        exp_s4    <= exp_n4;
        raw_sign_s4<= raw_sign_s3;
        op_s4      <= op_s3;
        z_a_s4 <= z_a_s3; z_b_s4 <= z_b_s3;
        i_a_s4 <= i_a_s3; i_b_s4 <= i_b_s3;
        n_a_s4 <= n_a_s3; n_b_s4 <= n_b_s3;
    end

    // -------------------
    // Stage 5: Round & Pack
    // -------------------
    wire [31:0] packed5;
    fp_round_pack u_roundpack (
        .sign_in(raw_sign_s4),
        .exp_in(exp_s4),
        .mant_in(norm_m_s4),
        .is_zero_a(z_a_s4), .is_zero_b(z_b_s4),
        .is_inf_a(i_a_s4),  .is_inf_b(i_b_s4),
        .is_nan_a(n_a_s4),  .is_nan_b(n_b_s4),
        .op(add_sub),       // original op for hack
        .exp_a(exp_a_s1),   // hack inputs
        .exp_b(exp_b_s1),
        .sign_a(sign_a_s1),
        .sign_b(sign_b_s1),
        .result(packed5)
    );
    always @(posedge clk) if (!rst) begin
        result <= packed5;
    end

endmodule