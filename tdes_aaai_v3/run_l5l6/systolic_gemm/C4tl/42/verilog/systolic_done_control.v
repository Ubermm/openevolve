`timescale 1ns/1ps

module systolic_done_control(cycle_count, done_in, cycle_count_next, done_next);
    input  [3:0] cycle_count;
    input        done_in;
    output [3:0] cycle_count_next;
    output       done_next;

    /*
     * A 4x4 systolic array with skewed inputs requires cycles 0 through 9
     * for the final PE accumulator update to occur.  Therefore done must
     * assert when the current cycle_count reaches 9, not 8.
     *
     * Keep done sticky and saturate the counter once complete.
     */
    assign done_next = done_in ? 1'b1 :
                       (cycle_count >= 4'd9) ? 1'b1 :
                       1'b0;

    assign cycle_count_next = done_in ? cycle_count :
                              (cycle_count >= 4'd9) ? cycle_count :
                              (cycle_count + 4'd1);

endmodule