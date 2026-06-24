// Top-level High-Pass FIR filter: 101-tap streaming MAC pipeline
module highpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output                      valid_out,
    output signed [DATA_W+GAIN_W-1:0] data_out
);
    // internal widths
    localparam COEFF_W = 16;
    localparam MULT_W  = DATA_W + COEFF_W;
    localparam ACC_W   = 64;
    localparam OUT_W   = DATA_W + GAIN_W;
    localparam SHIFT   = DATA_W;

    // sample delay pipeline [0..TAP_CNT-1]
    reg signed [DATA_W-1:0] sample_pipe [0:TAP_CNT-1];
    // accumulator pipeline [0..TAP_CNT]
    reg signed [ACC_W-1:0]   sum_pipe    [0:TAP_CNT];
    // valid signal pipeline
    reg                      valid_pipe  [0:TAP_CNT];

    // combinational wires
    wire signed [MULT_W-1:0] mult_wire [0:TAP_CNT-1];
    wire signed [ACC_W-1:0]  sum_wire  [1:TAP_CNT];

    // final scaled output
    wire signed [OUT_W-1:0]  data_out_wire;

    // coefficient lookup function
    function automatic signed [COEFF_W-1:0] get_coeff;
        input integer idx;
        begin
            case(idx)
                0:   get_coeff = 16'sd0;
                1:   get_coeff = 16'sd10;
                2:   get_coeff = 16'sd17;
                3:   get_coeff = 16'sd19;
                4:   get_coeff = 16'sd13;
                5:   get_coeff = 16'sd0;
                6:   get_coeff = -16'sd16;
                7:   get_coeff = -16'sd29;
                8:   get_coeff = -16'sd32;
                9:   get_coeff = -16'sd23;
                10:  get_coeff = 16'sd0;
                11:  get_coeff = 16'sd29;
                12:  get_coeff = 16'sd53;
                13:  get_coeff = 16'sd60;
                14:  get_coeff = 16'sd42;
                15:  get_coeff = 16'sd0;
                16:  get_coeff = -16'sd53;
                17:  get_coeff = -16'sd96;
                18:  get_coeff = -16'sd107;
                19:  get_coeff = -16'sd73;
                20:  get_coeff = 16'sd0;
                21:  get_coeff = 16'sd90;
                22:  get_coeff = 16'sd161;
                23:  get_coeff = 16'sd177;
                24:  get_coeff = 16'sd121;
                25:  get_coeff = 16'sd0;
                26:  get_coeff = -16'sd145;
                27:  get_coeff = -16'sd258;
                28:  get_coeff = -16'sd282;
                29:  get_coeff = -16'sd191;
                30:  get_coeff = 16'sd0;
                31:  get_coeff = 16'sd229;
                32:  get_coeff = 16'sd406;
                33:  get_coeff = 16'sd444;
                34:  get_coeff = 16'sd301;
                35:  get_coeff = 16'sd0;
                36:  get_coeff = -16'sd365;
                37:  get_coeff = -16'sd652;
                38:  get_coeff = -16'sd724;
                39:  get_coeff = -16'sd499;
                40:  get_coeff = 16'sd0;
                41:  get_coeff = 16'sd633;
                42:  get_coeff = 16'sd1170;
                43:  get_coeff = 16'sd1355;
                44:  get_coeff = 16'sd989;
                45:  get_coeff = 16'sd0;
                46:  get_coeff = -16'sd1511;
                47:  get_coeff = -16'sd3280;
                48:  get_coeff = -16'sd4943;
                49:  get_coeff = -16'sd6126;
                50:  get_coeff = 16'sd26219;
                51:  get_coeff = -16'sd6126;
                52:  get_coeff = -16'sd4943;
                53:  get_coeff = -16'sd3280;
                54:  get_coeff = -16'sd1511;
                55:  get_coeff = 16'sd0;
                56:  get_coeff = 16'sd989;
                57:  get_coeff = 16'sd1355;
                58:  get_coeff = 16'sd1170;
                59:  get_coeff = 16'sd633;
                60:  get_coeff = 16'sd0;
                61:  get_coeff = -16'sd499;
                62:  get_coeff = -16'sd724;
                63:  get_coeff = -16'sd652;
                64:  get_coeff = -16'sd365;
                65:  get_coeff = 16'sd0;
                66:  get_coeff = 16'sd301;
                67:  get_coeff = 16'sd444;
                68:  get_coeff = 16'sd406;
                69:  get_coeff = 16'sd229;
                70:  get_coeff = 16'sd0;
                71:  get_coeff = -16'sd191;
                72:  get_coeff = -16'sd282;
                73:  get_coeff = -16'sd258;
                74:  get_coeff = -16'sd145;
                75:  get_coeff = 16'sd0;
                76:  get_coeff = 16'sd121;
                77:  get_coeff = 16'sd177;
                78:  get_coeff = 16'sd161;
                79:  get_coeff = 16'sd90;
                80:  get_coeff = 16'sd0;
                81:  get_coeff = -16'sd73;
                82:  get_coeff = -16'sd107;
                83:  get_coeff = -16'sd96;
                84:  get_coeff = -16'sd53;
                85:  get_coeff = 16'sd0;
                86:  get_coeff = 16'sd42;
                87:  get_coeff = 16'sd60;
                88:  get_coeff = 16'sd53;
                89:  get_coeff = 16'sd29;
                90:  get_coeff = 16'sd0;
                91:  get_coeff = -16'sd23;
                92:  get_coeff = -16'sd32;
                93:  get_coeff = -16'sd29;
                94:  get_coeff = -16'sd16;
                95:  get_coeff = 16'sd0;
                96:  get_coeff = 16'sd13;
                97:  get_coeff = 16'sd19;
                98:  get_coeff = 16'sd17;
                99:  get_coeff = 16'sd10;
                100: get_coeff = 16'sd0;
                default: get_coeff = 16'sd0;
            endcase
        end
    endfunction

    // generate 101 multiply-add stages
    genvar i;
    generate
      for (i = 0; i < TAP_CNT; i = i + 1) begin : MAC_STAGES
        comb_mult #(
          .DATA_W(DATA_W),
          .COEFF_W(COEFF_W),
          .COEFF(get_coeff(i))
        ) mult_i (
          .data_in    (sample_pipe[i]),
          .mult_out   (mult_wire[i])
        );
        comb_add #(
          .ACC_W(ACC_W),
          .MULT_W(MULT_W)
        ) add_i (
          .sum_in     (sum_pipe[i]),
          .mult_in    (mult_wire[i]),
          .sum_out    (sum_wire[i+1])
        );
      end
    endgenerate

    // final output scaling
    output_stage #(
      .ACC_W(ACC_W),
      .OUT_W(OUT_W),
      .SHIFT(SHIFT)
    ) u_out (
      .sum_in  (sum_pipe[TAP_CNT]),
      .data_out(data_out_wire)
    );

    // sequential pipelines
    integer j;
    always @(posedge clk) begin
      if (rst) begin
        for (j = 0; j < TAP_CNT; j = j + 1) begin
          sample_pipe[j] <= '0;
        end
        for (j = 0; j <= TAP_CNT; j = j + 1) begin
          sum_pipe[j]   <= '0;
          valid_pipe[j] <= 1'b0;
        end
      end else begin
        // shift samples
        sample_pipe[0] <= $signed(data_in);
        for (j = 1; j < TAP_CNT; j = j + 1)
          sample_pipe[j] <= sample_pipe[j-1];
        // shift sums
        sum_pipe[0] <= '0;
        for (j = 1; j <= TAP_CNT; j = j + 1)
          sum_pipe[j] <= sum_wire[j];
        // shift valids
        valid_pipe[0] <= valid_in;
        for (j = 1; j <= TAP_CNT; j = j + 1)
          valid_pipe[j] <= valid_pipe[j-1];
      end
    end

    // outputs
    assign valid_out = valid_pipe[TAP_CNT];
    assign data_out  = data_out_wire;

endmodule