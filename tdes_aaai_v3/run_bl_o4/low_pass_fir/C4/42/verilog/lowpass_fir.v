module lowpass_fir #(
    parameter DATA_W  = 20,
    parameter TAP_CNT = 101,
    parameter GAIN_W  = 4,
    parameter COEFF_W = 16
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);
    // signed versions
    wire signed [DATA_W-1:0] din = data_in;
    // shift register of taps: x[n], x[n-1], ..., x[n-100]
    reg signed [DATA_W-1:0] taps [0:TAP_CNT-1];
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i=0; i<TAP_CNT; i=i+1) taps[i] <= 0;
        end else begin
            // shift
            taps[0] <= din;
            for (i=1; i<TAP_CNT; i=i+1)
                taps[i] <= taps[i-1];
        end
    end

    // compute partial products for k=0..49 and center k=50
    localparam PAIR_COUNT = (TAP_CNT-1)/2;
    // partials width: sum=a+b [DATA_W:0], mult = signed* signed yields width DATA_W+1 + COEFF_W => DATA_W+COEFF_W+1
    localparam PART_W = DATA_W + COEFF_W + 1;
    // total partials = PAIR_COUNT + 1 = 50 +1 =51
    wire signed [PART_W-1:0] parts_flat [0:PAIR_COUNT]; 

    genvar gi;
    // pairs
    generate
        for (gi = 0; gi < PAIR_COUNT; gi = gi + 1) begin : MAKE_PAIR
            wire signed [DATA_W:0] sum_ab = taps[gi] + taps[TAP_CNT-1-gi];
            wire signed [COEFF_W-1:0] coeff;
            coeff_rom #(.TAP_CNT(TAP_CNT), .COEFF_W(COEFF_W)) rom0 (
                .idx(gi), .coeff(coeff)
            );
            mult_pair #(.DATA_W(DATA_W+1), .COEFF_W(COEFF_W)) mp (
                .a(sum_ab), .b(0), .c(coeff), .p(parts_flat[gi])
            );
        end
    endgenerate

    // center tap
    wire signed [COEFF_W-1:0] coeff_c;
    coeff_rom #(.TAP_CNT(TAP_CNT), .COEFF_W(COEFF_W)) romc (
        .idx(PAIR_COUNT), .coeff(coeff_c)
    );
    wire signed [PART_W-1:0] part_center;
    mult_pair #(.DATA_W(DATA_W), .COEFF_W(COEFF_W)) mpc (
        .a(taps[PAIR_COUNT]), .b(0), .c(coeff_c), .p(part_center)
    );
    assign parts_flat[PAIR_COUNT] = part_center;

    // flatten parts into wide bus for add_tree
    localparam N_PART = PAIR_COUNT+1;
    localparam FLAT_W = N_PART * PART_W;
    wire [FLAT_W-1:0] parts_bus;
    generate
        for (gi=0; gi<N_PART; gi=gi+1) begin : FLAT
            assign parts_bus[gi*PART_W +: PART_W] = parts_flat[gi];
        end
    endgenerate

    // sum all partials
    wire signed [63:0] acc;
    add_tree #(.N(N_PART), .W_IN(PART_W), .W_OUT(64)) atree (
        .in_data(parts_bus), .out(acc)
    );

    // scale down: shift right DATA_W bits
    wire signed [63:0] scaled = acc >>> DATA_W;
    // truncate to output width
    wire signed [DATA_W+GAIN_W-1:0] dout = scaled[DATA_W+GAIN_W-1:0];

    // valid pipeline: direct pass-through
    reg vld;
    always @(posedge clk) begin
        if (rst) vld <= 0;
        else vld <= valid_in;
    end
    assign valid_out = vld;
    assign data_out  = dout;

endmodule