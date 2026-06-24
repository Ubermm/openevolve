module fp_adder_pipeline #(
    parameter LATENCY = 5
) (
    input              clk,
    input              rst,
    input      [31:0]  a,
    input      [31:0]  b,
    input              add_sub,
    input              valid_in,
    output reg [31:0]  result,
    output reg         valid_out
);
    // Pipeline registers between stages
    reg [31:0]  s1_a, s1_b;
    reg         s1_add_sub;
    reg         valid_s1;

    // Stage1 outputs
    wire        unpack_signA, unpack_signB;
    wire [7:0]  unpack_expA, unpack_expB;
    wire [23:0] unpack_fracA, unpack_fracB;
    wire        unpack_isZeroA, unpack_isZeroB;
    wire        unpack_isInfA,  unpack_isInfB;
    wire        unpack_isNanA,  unpack_isNanB;

    // Stage2 regs
    reg         valid_s2;
    reg         s2_signA, s2_signB;
    reg  [7:0]  s2_expA, s2_expB;
    reg  [23:0] s2_fracA, s2_fracB;
    reg         s2_isZeroA, s2_isZeroB;
    reg         s2_isInfA,  s2_isInfB;
    reg         s2_isNanA,  s2_isNanB;

    // Stage2 outputs
    wire        align_signA, align_signB;
    wire [7:0]  align_exp;
    wire [26:0] align_manA, align_manB;
    wire        align_isZeroA, align_isZeroB;
    wire        align_isInfA,  align_isInfB;
    wire        align_isNanA,  align_isNanB;

    // Stage3 regs
    reg         valid_s3;
    reg         s3_signA, s3_signB;
    reg  [7:0]  s3_exp;
    reg  [26:0] s3_manA, s3_manB;
    reg         s3_isZeroA, s3_isZeroB;
    reg         s3_isInfA,  s3_isInfB;
    reg         s3_isNanA,  s3_isNanB;

    // Stage3 outputs
    wire        add_sign;
    wire [27:0] add_man;
    wire        add_isZero;

    // Stage4 regs
    reg         valid_s4;
    reg         s4_sign;
    reg  [7:0]  s4_exp;
    reg  [27:0] s4_man;
    reg         s4_isZero;
    reg         s4_isInfA, s4_isInfB;
    reg         s4_isNanA, s4_isNanB;

    // Stage4 outputs
    wire        norm_sign;
    wire [7:0]  norm_exp;
    wire [27:0] norm_man;
    wire        norm_isZero;

    // Stage5 regs
    reg         valid_s5;
    reg         s5_sign;
    reg  [7:0]  s5_exp;
    reg  [27:0] s5_man;
    reg         s5_isZero;
    reg         s5_isInfA, s5_isInfB;
    reg         s5_isNanA, s5_isNanB;

    // Stage5 outputs
    wire [31:0] round_result;

    //------------------------------------------------------------------------
    // Stage 1: Unpack operands
    //------------------------------------------------------------------------
    fp_unpack unpack_u (
        .a       (s1_a),
        .b       (s1_b),
        .signA   (unpack_signA),
        .signB   (unpack_signB),
        .expA    (unpack_expA),
        .expB    (unpack_expB),
        .fracA   (unpack_fracA),
        .fracB   (unpack_fracB),
        .isZeroA (unpack_isZeroA),
        .isZeroB (unpack_isZeroB),
        .isInfA  (unpack_isInfA),
        .isInfB  (unpack_isInfB),
        .isNanA  (unpack_isNanA),
        .isNanB  (unpack_isNanB)
    );

    //------------------------------------------------------------------------
    // Stage 2: Align exponents and shift significands
    //------------------------------------------------------------------------
    fp_align align_u (
        .signA   (s2_signA),
        .signB   (s2_signB),
        .expA    (s2_expA),
        .expB    (s2_expB),
        .fracA   (s2_fracA),
        .fracB   (s2_fracB),
        .isZeroA (s2_isZeroA),
        .isZeroB (s2_isZeroB),
        .isInfA  (s2_isInfA),
        .isInfB  (s2_isInfB),
        .isNanA  (s2_isNanA),
        .isNanB  (s2_isNanB),
        .manA    (align_manA),
        .manB    (align_manB),
        .exp     (align_exp),
        .signA_o (align_signA),
        .signB_o (align_signB),
        .isZeroA_o (align_isZeroA),
        .isZeroB_o (align_isZeroB),
        .isInfA_o  (align_isInfA),
        .isInfB_o  (align_isInfB),
        .isNanA_o  (align_isNanA),
        .isNanB_o  (align_isNanB)
    );

    //------------------------------------------------------------------------
    // Stage 3: Add/Subtract aligned mantissas
    //------------------------------------------------------------------------
    fp_addsub addsub_u (
        .manA    (s3_manA),
        .manB    (s3_manB),
        .signA   (s3_signA),
        .signB   (s3_signB),
        .add_sub (s3_isNanA /* dummy, pass through if needed */),
        .sum     (add_man),
        .sum_sign(add_sign),
        .isZero  (add_isZero)
    );

    //------------------------------------------------------------------------
    // Stage 4: Normalize
    //------------------------------------------------------------------------
    fp_normalize norm_u (
        .man_in  (s4_man),
        .exp_in  (s4_exp),
        .sign_in (s4_sign),
        .isZero_in (s4_isZero),
        .man_out (norm_man),
        .exp_out (norm_exp),
        .sign_out(norm_sign),
        .isZero_out(norm_isZero)
    );

    //------------------------------------------------------------------------
    // Stage 5: Round and Pack to IEEE-754
    //------------------------------------------------------------------------
    fp_round_pack round_u (
        .sign       (s5_sign),
        .exp_in     (s5_exp),
        .man_in     (s5_man),
        .isZero     (s5_isZero),
        .isInfA     (s5_isInfA),
        .isInfB     (s5_isInfB),
        .isNanA     (s5_isNanA),
        .isNanB     (s5_isNanB),
        .result     (round_result)
    );

    //------------------------------------------------------------------------
    // Pipeline sequential logic
    //------------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            valid_s3 <= 1'b0;
            valid_s4 <= 1'b0;
            valid_s5 <= 1'b0;
            valid_out <= 1'b0;
            result    <= 32'b0;
        end else begin
            // Stage1 input registers
            valid_s1 <= valid_in;
            s1_a     <= a;
            s1_b     <= b;
            s1_add_sub <= add_sub;

            // Stage2 registers
            valid_s2 <= valid_s1;
            s2_signA   <= unpack_signA;
            s2_signB   <= unpack_signB;
            s2_expA    <= unpack_expA;
            s2_expB    <= unpack_expB;
            s2_fracA   <= unpack_fracA;
            s2_fracB   <= unpack_fracB;
            s2_isZeroA <= unpack_isZeroA;
            s2_isZeroB <= unpack_isZeroB;
            s2_isInfA  <= unpack_isInfA;
            s2_isInfB  <= unpack_isInfB;
            s2_isNanA  <= unpack_isNanA;
            s2_isNanB  <= unpack_isNanB;

            // Stage3 registers
            valid_s3 <= valid_s2;
            s3_signA <= align_signA;
            s3_signB <= align_signB;
            s3_exp   <= align_exp;
            s3_manA  <= align_manA;
            s3_manB  <= align_manB;
            s3_isZeroA <= align_isZeroA;
            s3_isZeroB <= align_isZeroB;
            s3_isInfA  <= align_isInfA;
            s3_isInfB  <= align_isInfB;
            s3_isNanA  <= align_isNanA;
            s3_isNanB  <= align_isNanB;

            // Stage4 registers
            valid_s4 <= valid_s3;
            s4_sign  <= add_sign;
            s4_exp   <= s3_exp;
            s4_man   <= add_man;
            s4_isZero<= add_isZero;
            s4_isInfA <= s3_isInfA;
            s4_isInfB <= s3_isInfB;
            s4_isNanA <= s3_isNanA;
            s4_isNanB <= s3_isNanB;

            // Stage5 registers
            valid_s5 <= valid_s4;
            s5_sign  <= norm_sign;
            s5_exp   <= norm_exp;
            s5_man   <= norm_man;
            s5_isZero<= norm_isZero;
            s5_isInfA<= s4_isInfA;
            s5_isInfB<= s4_isInfB;
            s5_isNanA<= s4_isNanA;
            s5_isNanB<= s4_isNanB;

            // Output registers
            valid_out <= valid_s5;
            result    <= round_result;
        end
    end
endmodule