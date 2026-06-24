`timescale 1ns/1ps

module conv1d #(
    parameter DATA_W      = 8,
    parameter KERNEL_SIZE = 5,
    parameter GAIN_W      = 4
) (
    input                       clk,
    input                       rst,
    input                       valid_in,
    input      [DATA_W-1:0]     data_in,
    output                      valid_out,
    output     [DATA_W+GAIN_W-1:0] data_out
);

    function integer conv1d_clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            conv1d_clog2 = 0;
            while (v > 0) begin
                v = v >> 1;
                conv1d_clog2 = conv1d_clog2 + 1;
            end
        end
    endfunction

    localparam OUT_W     = DATA_W + GAIN_W;
    localparam COEFF_W   = OUT_W;
    localparam SAMPLE_SW = DATA_W + 1;
    localparam PROD_W    = SAMPLE_SW + COEFF_W;
    localparam ACC_W     = PROD_W + conv1d_clog2(KERNEL_SIZE) + 1;
    localparam COUNT_W   = conv1d_clog2(KERNEL_SIZE + 1);

    reg  [KERNEL_SIZE*DATA_W-1:0] window_reg;
    reg  [COUNT_W-1:0]            valid_count;

    wire [KERNEL_SIZE*DATA_W-1:0] next_window;
    wire [KERNEL_SIZE*COEFF_W-1:0] coeffs_flat;
    wire signed [ACC_W-1:0]        acc_value;
    wire [OUT_W-1:0]               cast_value;

    conv1d_window_next #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE)
    ) u_window_next (
        .current_window(window_reg),
        .data_in(data_in),
        .valid_in(valid_in),
        .next_window(next_window)
    );

    conv1d_coeff_bank #(
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W)
    ) u_coeff_bank (
        .coeffs_flat(coeffs_flat)
    );

    conv1d_mac #(
        .DATA_W(DATA_W),
        .KERNEL_SIZE(KERNEL_SIZE),
        .COEFF_W(COEFF_W),
        .ACC_W(ACC_W)
    ) u_mac (
        .window_flat(next_window),
        .coeffs_flat(coeffs_flat),
        .acc_out(acc_value)
    );

    conv1d_output_cast #(
        .ACC_W(ACC_W),
        .OUT_W(OUT_W)
    ) u_output_cast (
        .acc_in(acc_value),
        .data_out(cast_value)
    );

    assign valid_out = valid_in && (valid_count >= (KERNEL_SIZE - 1));
    assign data_out  = valid_out ? cast_value : {OUT_W{1'b0}};

    always @(posedge clk) begin
        if (rst) begin
            window_reg  <= {KERNEL_SIZE*DATA_W{1'b0}};
            valid_count <= {COUNT_W{1'b0}};
        end else begin
            if (valid_in) begin
                window_reg <= next_window;

                if (valid_count < (KERNEL_SIZE - 1))
                    valid_count <= valid_count + {{(COUNT_W-1){1'b0}}, 1'b1};
                else
                    valid_count <= valid_count;
            end
        end
    end

endmodule