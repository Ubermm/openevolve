// Top-level streaming band-pass FIR filter
// Parameterizable: DATA_W=20, TAP_CNT=101, GAIN_W=4
module bandpass_fir #(
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
    // Shift-register for samples (zero-extended when valid_in==0)
    reg [DATA_W-1:0] shift_reg [0:TAP_CNT-1];
    integer i;
    // Valid pipeline: delay valid_in by TAP_CNT cycles
    reg [0:TAP_CNT] valid_pipe;

    // Concatenate shift_reg into wide bus for MAC
    wire [DATA_W*TAP_CNT-1:0] data_bus;
    genvar gi;
    generate
        for (gi = 0; gi < TAP_CNT; gi = gi + 1) begin : PACK
            assign data_bus[gi*DATA_W +: DATA_W] = shift_reg[gi];
        end
    endgenerate

    // FIR multiply-accumulate
    wire signed [63:0] mac_acc;
    fir_mac #(
        .DATA_W(DATA_W),
        .TAP_CNT(TAP_CNT)
    ) u_mac (
        .data_in(data_bus),
        .mac_out(mac_acc)
    );

    // Scale (right-shift by DATA_W)
    scaler #(
        .DATA_W(DATA_W),
        .GAIN_W(GAIN_W)
    ) u_scaler (
        .mac_in(mac_acc),
        .data_out(data_out)
    );

    // Valid output
    assign valid_out = valid_pipe[TAP_CNT];

    // Sequential logic: shift register + valid pipeline
    always @(posedge clk) begin
        if (rst) begin
            // Zero samples and valid pipeline
            for (i = 0; i < TAP_CNT; i = i + 1)
                shift_reg[i] <= {DATA_W{1'b0}};
            valid_pipe <= { (TAP_CNT+1) {1'b0} };
        end else begin
            // Shift sample buffer: new input or zero if not valid
            shift_reg[0] <= valid_in ? data_in : {DATA_W{1'b0}};
            for (i = 1; i < TAP_CNT; i = i + 1)
                shift_reg[i] <= shift_reg[i-1];
            // Advance valid pipeline
            valid_pipe <= { valid_pipe[0 +: TAP_CNT], valid_in };
        end
    end

endmodule