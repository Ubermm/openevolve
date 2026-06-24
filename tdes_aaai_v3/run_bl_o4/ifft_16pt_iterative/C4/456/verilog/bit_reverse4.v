module bit_reverse4 (
    input  wire [3:0] addr,
    output wire [3:0] rev
);
    // 4-bit reversal for bit-reversal permutation (N=16)
    // Mapping: 0→0, 1→8, 2→4, 3→12, 4→2, 5→10, 6→6, 7→14,
    //          8→1, 9→9, 10→5, 11→13, 12→3, 13→11, 14→7, 15→15
    reg [3:0] rev_r;
    always @* begin
        case (addr)
            4'd0:  rev_r = 4'd0;
            4'd1:  rev_r = 4'd8;
            4'd2:  rev_r = 4'd4;
            4'd3:  rev_r = 4'd12;
            4'd4:  rev_r = 4'd2;
            4'd5:  rev_r = 4'd10;
            4'd6:  rev_r = 4'd6;
            4'd7:  rev_r = 4'd14;
            4'd8:  rev_r = 4'd1;
            4'd9:  rev_r = 4'd9;
            4'd10: rev_r = 4'd5;
            4'd11: rev_r = 4'd13;
            4'd12: rev_r = 4'd3;
            4'd13: rev_r = 4'd11;
            4'd14: rev_r = 4'd7;
            4'd15: rev_r = 4'd15;
            default: rev_r = 4'd0;
        endcase
    end

    assign rev = rev_r;
endmodule