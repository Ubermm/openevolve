"""
Real multi-module crossover harness over *published* ArchXBench hierarchical
designs (Experiment 2).

ArchXBench ships these designs as a single top-level testbench with **no**
submodule tests and **no** reference RTL, so the default
``benchmark_loader.load_archxbench`` builds a single-module black box — and
complementary-coverage crossover (TDES's primary contribution) structurally
cannot fire (nothing to graft). This harness turns each design — whose own spec
is *"X built from sub-component Y"* (e.g. *"8-bit comparator using two 4-bit
comparators"*) — into a genuine **two-module** TDES problem ``{TOP, SUB}`` with a
3-tier suite:

    UNIT(SUB)         golden check on SUB alone                  -> module [SUB]
    INTEGRATION(TOP)  TOP wiring vs golden, tb carries an
                      *inline golden SUB*  (so TOP is scored
                      independently of the candidate's SUB)      -> module [TOP]
    SYSTEM            the **native ArchXBench testbench**         -> [TOP, SUB]

The INTEGRATION tier relies on ``VerilogTestSuite(isolate_modules=True)`` so that
the candidate's own (possibly broken) ``SUB`` is *not* compiled for that test —
only the candidate's ``TOP`` plus the golden ``SUB`` defined inline in the
testbench. This yields the complementary-coverage scenario crossover needs:

    A = good SUB / bad TOP  -> passes {UNIT}            (fails INTEGRATION, SYSTEM)
    B = bad SUB / good TOP  -> passes {INTEGRATION}     (golden SUB injected)
    graft TOP from B into A -> passes ALL incl. SYSTEM  (a jump no mutation made)

Reference-gated exactly like the rest of the layer
(``benchmark_loader.is_usable``): the full reference ``{golden TOP, golden SUB}``
passes every tier and the skeleton seed fails at least one, or the design is
excluded.

**Honesty note (carried into RESULTS.md).** The UNIT + INTEGRATION tiers and the
submodule goldens here are *authored by us* — ArchXBench provides only the
top-level testbench. The goldens are small, and the full hierarchical reference
passes every tier (verified by ``tests/test_hierarchical_archx.py``). The SYSTEM
tier is the unmodified native benchmark testbench.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from openevolve.tdes.fpga import benchmark_loader
from openevolve.tdes.fpga.verilog_suite import VerilogTest, VerilogTestSuite
from openevolve.tdes.mutation import ScriptedMutator
from openevolve.tdes.types import Candidate, TestLevel

LoaderResult = Tuple[Candidate, VerilogTestSuite, Optional[ScriptedMutator]]


@dataclass
class HierDesign:
    """A published hierarchical ArchXBench design decomposed into {TOP, SUB}."""

    key: str  # registry key (used as the experiment "design" id)
    bench_design: str  # folder under benchmarks/archxbench/level-*/
    top: str  # top module name (matches the native testbench's DUT)
    sub: str  # submodule the spec says the top is "built from"
    sub_golden: str
    top_golden: str
    sub_skeleton: str
    top_skeleton: str
    sub_unit_tb: str  # TDES-protocol tb, test_id = f"{sub}_unit"
    top_integration_tb: str  # TDES-protocol tb (inline golden SUB), id = f"{top}_integ"
    description: str


# ===========================================================================
# Design registry  (goldens hand-verified against each native testbench)
# ===========================================================================

_DESIGNS: Dict[str, HierDesign] = {}


def _register(d: HierDesign) -> None:
    _DESIGNS[d.key] = d


# --- comparator-8bit  (two 4-bit comparators) ------------------------------
_register(
    HierDesign(
        key="comparator-8bit",
        bench_design="comparator-8bit",
        top="comparator_8bit",
        sub="comparator_4bit",
        sub_golden=(
            "module comparator_4bit(input [3:0] a, input [3:0] b, output gt, eq, lt);\n"
            "  assign gt = (a > b);\n"
            "  assign eq = (a == b);\n"
            "  assign lt = (a < b);\n"
            "endmodule\n"
        ),
        top_golden=(
            "module comparator_8bit(input [7:0] a, input [7:0] b, output gt, eq, lt);\n"
            "  wire hgt, heq, hlt, lgt, leq, llt;\n"
            "  comparator_4bit hi(.a(a[7:4]), .b(b[7:4]), .gt(hgt), .eq(heq), .lt(hlt));\n"
            "  comparator_4bit lo(.a(a[3:0]), .b(b[3:0]), .gt(lgt), .eq(leq), .lt(llt));\n"
            "  assign gt = hgt | (heq & lgt);\n"
            "  assign eq = heq & leq;\n"
            "  assign lt = hlt | (heq & llt);\n"
            "endmodule\n"
        ),
        sub_skeleton=(
            "module comparator_4bit(input [3:0] a, input [3:0] b, output gt, eq, lt);\n"
            "  // TODO: 4-bit magnitude comparator (gt, eq, lt)\n"
            "endmodule\n"
        ),
        top_skeleton=(
            "module comparator_8bit(input [7:0] a, input [7:0] b, output gt, eq, lt);\n"
            "  // TODO: build from two comparator_4bit instances\n"
            "endmodule\n"
        ),
        sub_unit_tb=(
            "`timescale 1ns/1ps\n"
            "module tb;\n"
            "  reg [3:0] a,b; wire gt,eq,lt; integer f=0;\n"
            "  comparator_4bit u(.a(a),.b(b),.gt(gt),.eq(eq),.lt(lt));\n"
            "  task chk; input [3:0] x,y; input eg,ee,el; begin a=x;b=y;#5;\n"
            "    if (gt!==eg||eq!==ee||lt!==el) begin\n"
            '      $display("TDES_FAIL: test_id=comparator_4bit_unit | input=a=%0d,b=%0d |'
            ' expected=gt%0d_eq%0d_lt%0d | got=gt%0d_eq%0d_lt%0d",x,y,eg,ee,el,gt,eq,lt);'
            " f=f+1; end end\n"
            "  endtask\n"
            "  initial begin\n"
            "    chk(4'd5,4'd3,1,0,0); chk(4'd3,4'd5,0,0,1); chk(4'd7,4'd7,0,1,0);\n"
            "    chk(4'd0,4'd15,0,0,1); chk(4'd15,4'd0,1,0,0);\n"
            '    if(f==0) $display("TDES_PASS: test_id=comparator_4bit_unit"); $finish; end\n'
            "endmodule\n"
        ),
        top_integration_tb=(
            "`timescale 1ns/1ps\n"
            "module comparator_4bit(input [3:0] a, input [3:0] b, output gt, eq, lt);\n"
            "  assign gt=(a>b); assign eq=(a==b); assign lt=(a<b);\n"
            "endmodule\n"
            "module tb;\n"
            "  reg [7:0] a,b; wire gt,eq,lt; integer f=0;\n"
            "  comparator_8bit u(.a(a),.b(b),.gt(gt),.eq(eq),.lt(lt));\n"
            "  task chk; input [7:0] x,y; begin a=x;b=y;#5;\n"
            "    if (gt!==(x>y)||eq!==(x==y)||lt!==(x<y)) begin\n"
            '      $display("TDES_FAIL: test_id=comparator_8bit_integ | input=a=%0d,b=%0d |'
            ' expected=gt%0d_eq%0d_lt%0d | got=gt%0d_eq%0d_lt%0d",x,y,(x>y),(x==y),(x<y),'
            "gt,eq,lt); f=f+1; end end\n"
            "  endtask\n"
            "  initial begin\n"
            "    chk(8'd100,8'd50); chk(8'd50,8'd100); chk(8'd200,8'd200);\n"
            "    chk(8'd0,8'd255); chk(8'd255,8'd0); chk(8'h3C,8'h3D);\n"
            '    if(f==0) $display("TDES_PASS: test_id=comparator_8bit_integ"); $finish; end\n'
            "endmodule\n"
        ),
        description="8-bit magnitude comparator built from two 4-bit comparators",
    )
)

# --- decoder-3to8  (two 2-to-4 decoders) -----------------------------------
_register(
    HierDesign(
        key="decoder-3to8",
        bench_design="decoder-3to8",
        top="decoder3to8",
        sub="decoder2to4",
        sub_golden=(
            "module decoder2to4(input [1:0] in, input enable, output [3:0] out);\n"
            "  assign out = enable ? (4'b0001 << in) : 4'b0000;\n"
            "endmodule\n"
        ),
        top_golden=(
            "module decoder3to8(input [2:0] in, input enable, output [7:0] out);\n"
            "  decoder2to4 lo(.in(in[1:0]), .enable(enable & ~in[2]), .out(out[3:0]));\n"
            "  decoder2to4 hi(.in(in[1:0]), .enable(enable &  in[2]), .out(out[7:4]));\n"
            "endmodule\n"
        ),
        sub_skeleton=(
            "module decoder2to4(input [1:0] in, input enable, output [3:0] out);\n"
            "  // TODO: 2-to-4 one-hot decoder with enable\n"
            "endmodule\n"
        ),
        top_skeleton=(
            "module decoder3to8(input [2:0] in, input enable, output [7:0] out);\n"
            "  // TODO: build from two decoder2to4 instances\n"
            "endmodule\n"
        ),
        sub_unit_tb=(
            "`timescale 1ns/1ps\n"
            "module tb;\n"
            "  reg [1:0] in; reg en; wire [3:0] out; integer f=0;\n"
            "  decoder2to4 u(.in(in),.enable(en),.out(out));\n"
            "  task chk; input [1:0] x; input e; input [3:0] exp; begin in=x;en=e;#5;\n"
            "    if (out!==exp) begin\n"
            '      $display("TDES_FAIL: test_id=decoder2to4_unit | input=in=%0d,en=%0d |'
            ' expected=%b | got=%b",x,e,exp,out); f=f+1; end end\n'
            "  endtask\n"
            "  initial begin\n"
            "    chk(2'd0,1,4'b0001); chk(2'd1,1,4'b0010); chk(2'd2,1,4'b0100);\n"
            "    chk(2'd3,1,4'b1000); chk(2'd2,0,4'b0000);\n"
            '    if(f==0) $display("TDES_PASS: test_id=decoder2to4_unit"); $finish; end\n'
            "endmodule\n"
        ),
        top_integration_tb=(
            "`timescale 1ns/1ps\n"
            "module decoder2to4(input [1:0] in, input enable, output [3:0] out);\n"
            "  assign out = enable ? (4'b0001 << in) : 4'b0000;\n"
            "endmodule\n"
            "module tb;\n"
            "  reg [2:0] in; reg en; wire [7:0] out; integer f=0; integer i;\n"
            "  decoder3to8 u(.in(in),.enable(en),.out(out));\n"
            "  task chk; input [7:0] exp; begin #5;\n"
            "    if (out!==exp) begin\n"
            '      $display("TDES_FAIL: test_id=decoder3to8_integ | input=in=%0d,en=%0d |'
            ' expected=%b | got=%b",in,en,exp,out); f=f+1; end end\n'
            "  endtask\n"
            "  initial begin\n"
            "    en=1; for(i=0;i<8;i=i+1) begin in=i; chk(8'b1<<i); end\n"
            "    en=0; in=3'd3; chk(8'b0); in=3'd7; chk(8'b0);\n"
            '    if(f==0) $display("TDES_PASS: test_id=decoder3to8_integ"); $finish; end\n'
            "endmodule\n"
        ),
        description="3-to-8 one-hot decoder built from two 2-to-4 decoders",
    )
)

# --- mux4to1  (three 2-to-1 muxes) -----------------------------------------
_register(
    HierDesign(
        key="mux4to1",
        bench_design="mux4to1",
        top="mux_4to1",
        sub="mux2to1",
        sub_golden=(
            "module mux2to1(input a, input b, input sel, output out);\n"
            "  assign out = sel ? b : a;\n"
            "endmodule\n"
        ),
        top_golden=(
            "module mux_4to1(input [3:0] in, input [1:0] sel, output out);\n"
            "  wire l, h;\n"
            "  mux2to1 u0(.a(in[0]), .b(in[1]), .sel(sel[0]), .out(l));\n"
            "  mux2to1 u1(.a(in[2]), .b(in[3]), .sel(sel[0]), .out(h));\n"
            "  mux2to1 u2(.a(l), .b(h), .sel(sel[1]), .out(out));\n"
            "endmodule\n"
        ),
        sub_skeleton=(
            "module mux2to1(input a, input b, input sel, output out);\n"
            "  // TODO: 2-to-1 multiplexer (sel=0 -> a, sel=1 -> b)\n"
            "endmodule\n"
        ),
        top_skeleton=(
            "module mux_4to1(input [3:0] in, input [1:0] sel, output out);\n"
            "  // TODO: build from three mux2to1 instances\n"
            "endmodule\n"
        ),
        sub_unit_tb=(
            "`timescale 1ns/1ps\n"
            "module tb;\n"
            "  reg a,b,sel; wire out; integer f=0;\n"
            "  mux2to1 u(.a(a),.b(b),.sel(sel),.out(out));\n"
            "  task chk; input xa,xb,xs,exp; begin a=xa;b=xb;sel=xs;#5;\n"
            "    if (out!==exp) begin\n"
            '      $display("TDES_FAIL: test_id=mux2to1_unit | input=a=%0d,b=%0d,sel=%0d |'
            ' expected=%0d | got=%0d",xa,xb,xs,exp,out); f=f+1; end end\n'
            "  endtask\n"
            "  initial begin\n"
            "    chk(1'b0,1'b1,1'b0,1'b0); chk(1'b0,1'b1,1'b1,1'b1);\n"
            "    chk(1'b1,1'b0,1'b0,1'b1); chk(1'b1,1'b0,1'b1,1'b0);\n"
            '    if(f==0) $display("TDES_PASS: test_id=mux2to1_unit"); $finish; end\n'
            "endmodule\n"
        ),
        top_integration_tb=(
            "`timescale 1ns/1ps\n"
            "module mux2to1(input a, input b, input sel, output out);\n"
            "  assign out = sel ? b : a;\n"
            "endmodule\n"
            "module tb;\n"
            "  reg [3:0] in; reg [1:0] sel; wire out; integer f=0; integer s,i;\n"
            "  mux_4to1 u(.in(in),.sel(sel),.out(out));\n"
            "  initial begin\n"
            "    for(s=0;s<4;s=s+1) for(i=0;i<16;i=i+1) begin\n"
            "      sel=s; in=i; #5;\n"
            "      if (out!==in[sel]) begin\n"
            '        $display("TDES_FAIL: test_id=mux_4to1_integ | input=sel=%0d,in=%b |'
            ' expected=%0d | got=%0d",sel,in,in[sel],out); f=f+1; end\n'
            "    end\n"
            '    if(f==0) $display("TDES_PASS: test_id=mux_4to1_integ"); $finish; end\n'
            "endmodule\n"
        ),
        description="4-to-1 multiplexer built from three 2-to-1 multiplexers",
    )
)

# --- demux-1to4  (three 1-to-2 demuxes) ------------------------------------
_register(
    HierDesign(
        key="demux-1to4",
        bench_design="demux-1to4",
        top="demux_1to4",
        sub="demux_1to2",
        sub_golden=(
            "module demux_1to2(input in, input sel, output out0, output out1);\n"
            "  assign out0 = sel ? 1'b0 : in;\n"
            "  assign out1 = sel ? in : 1'b0;\n"
            "endmodule\n"
        ),
        top_golden=(
            "module demux_1to4(input in, input [1:0] sel,\n"
            "                  output out0, output out1, output out2, output out3);\n"
            "  wire i_low, i_high;\n"
            "  demux_1to2 u0(.in(in),     .sel(sel[1]), .out0(i_low),  .out1(i_high));\n"
            "  demux_1to2 u1(.in(i_low),  .sel(sel[0]), .out0(out0),   .out1(out1));\n"
            "  demux_1to2 u2(.in(i_high), .sel(sel[0]), .out0(out2),   .out1(out3));\n"
            "endmodule\n"
        ),
        sub_skeleton=(
            "module demux_1to2(input in, input sel, output out0, output out1);\n"
            "  // TODO: 1-to-2 demultiplexer\n"
            "endmodule\n"
        ),
        top_skeleton=(
            "module demux_1to4(input in, input [1:0] sel,\n"
            "                  output out0, output out1, output out2, output out3);\n"
            "  // TODO: build from three demux_1to2 instances\n"
            "endmodule\n"
        ),
        sub_unit_tb=(
            "`timescale 1ns/1ps\n"
            "module tb;\n"
            "  reg in,sel; wire out0,out1; integer f=0;\n"
            "  demux_1to2 u(.in(in),.sel(sel),.out0(out0),.out1(out1));\n"
            "  task chk; input xi,xs,e0,e1; begin in=xi;sel=xs;#5;\n"
            "    if (out0!==e0||out1!==e1) begin\n"
            '      $display("TDES_FAIL: test_id=demux_1to2_unit | input=in=%0d,sel=%0d |'
            ' expected=%0d_%0d | got=%0d_%0d",xi,xs,e0,e1,out0,out1); f=f+1; end end\n'
            "  endtask\n"
            "  initial begin\n"
            "    chk(1'b1,1'b0,1'b1,1'b0); chk(1'b1,1'b1,1'b0,1'b1);\n"
            "    chk(1'b0,1'b0,1'b0,1'b0); chk(1'b0,1'b1,1'b0,1'b0);\n"
            '    if(f==0) $display("TDES_PASS: test_id=demux_1to2_unit"); $finish; end\n'
            "endmodule\n"
        ),
        top_integration_tb=(
            "`timescale 1ns/1ps\n"
            "module demux_1to2(input in, input sel, output out0, output out1);\n"
            "  assign out0 = sel ? 1'b0 : in;\n"
            "  assign out1 = sel ? in : 1'b0;\n"
            "endmodule\n"
            "module tb;\n"
            "  reg in; reg [1:0] sel; wire o0,o1,o2,o3; integer f=0; integer s;\n"
            "  demux_1to4 u(.in(in),.sel(sel),.out0(o0),.out1(o1),.out2(o2),.out3(o3));\n"
            "  task chk; input e0,e1,e2,e3; begin #5;\n"
            "    if (o0!==e0||o1!==e1||o2!==e2||o3!==e3) begin\n"
            '      $display("TDES_FAIL: test_id=demux_1to4_integ | input=in=%0d,sel=%0d |'
            ' expected=%0d%0d%0d%0d | got=%0d%0d%0d%0d",in,sel,e0,e1,e2,e3,o0,o1,o2,o3);'
            " f=f+1; end end\n"
            "  endtask\n"
            "  initial begin\n"
            "    in=1; sel=2'b00; chk(1,0,0,0); sel=2'b01; chk(0,1,0,0);\n"
            "    sel=2'b10; chk(0,0,1,0); sel=2'b11; chk(0,0,0,1);\n"
            "    in=0; for(s=0;s<4;s=s+1) begin sel=s; chk(0,0,0,0); end\n"
            '    if(f==0) $display("TDES_PASS: test_id=demux_1to4_integ"); $finish; end\n'
            "endmodule\n"
        ),
        description="1-to-4 demultiplexer built from three 1-to-2 demultiplexers",
    )
)

# --- carry_select_adder_32bit  (eight 4-bit adder blocks) ------------------
_register(
    HierDesign(
        key="carry_select_adder_32bit",
        bench_design="carry_select_adder_32bit",
        top="carry_select_adder_32bit",
        sub="adder_4bit",
        sub_golden=(
            "module adder_4bit(input [3:0] a, input [3:0] b, input cin,\n"
            "                 output [3:0] sum, output cout);\n"
            "  assign {cout, sum} = a + b + cin;\n"
            "endmodule\n"
        ),
        top_golden=(
            "module carry_select_adder_32bit(input [31:0] A, input [31:0] B, input cin,\n"
            "                                output [31:0] sum, output cout);\n"
            "  wire [8:0] c; assign c[0] = cin;\n"
            "  genvar i;\n"
            "  generate for (i=0;i<8;i=i+1) begin: blk\n"
            "    adder_4bit u(.a(A[i*4+:4]), .b(B[i*4+:4]), .cin(c[i]),\n"
            "                 .sum(sum[i*4+:4]), .cout(c[i+1]));\n"
            "  end endgenerate\n"
            "  assign cout = c[8];\n"
            "endmodule\n"
        ),
        sub_skeleton=(
            "module adder_4bit(input [3:0] a, input [3:0] b, input cin,\n"
            "                 output [3:0] sum, output cout);\n"
            "  // TODO: 4-bit full adder ({cout,sum} = a+b+cin)\n"
            "endmodule\n"
        ),
        top_skeleton=(
            "module carry_select_adder_32bit(input [31:0] A, input [31:0] B, input cin,\n"
            "                                output [31:0] sum, output cout);\n"
            "  // TODO: build from eight adder_4bit blocks\n"
            "endmodule\n"
        ),
        sub_unit_tb=(
            "`timescale 1ns/1ps\n"
            "module tb;\n"
            "  reg [3:0] a,b; reg cin; wire [3:0] sum; wire cout; integer f=0;\n"
            "  adder_4bit u(.a(a),.b(b),.cin(cin),.sum(sum),.cout(cout));\n"
            "  task chk; input [3:0] x,y; input c; input [4:0] e; begin a=x;b=y;cin=c;#5;\n"
            "    if ({cout,sum}!==e) begin\n"
            '      $display("TDES_FAIL: test_id=adder_4bit_unit | input=a=%0d,b=%0d,cin=%0d |'
            ' expected=%0d | got=%0d",x,y,c,e,{cout,sum}); f=f+1; end end\n'
            "  endtask\n"
            "  initial begin\n"
            "    chk(4'd3,4'd4,0,5'd7); chk(4'd15,4'd1,0,5'd16); chk(4'd15,4'd15,1,5'd31);\n"
            "    chk(4'd0,4'd0,0,5'd0); chk(4'd8,4'd8,0,5'd16);\n"
            '    if(f==0) $display("TDES_PASS: test_id=adder_4bit_unit"); $finish; end\n'
            "endmodule\n"
        ),
        top_integration_tb=(
            "`timescale 1ns/1ps\n"
            "module adder_4bit(input [3:0] a, input [3:0] b, input cin,\n"
            "                 output [3:0] sum, output cout);\n"
            "  assign {cout,sum} = a + b + cin;\n"
            "endmodule\n"
            "module tb;\n"
            "  reg [31:0] A,B; reg cin; wire [31:0] sum; wire cout; integer f=0;\n"
            "  reg [32:0] e;\n"
            "  carry_select_adder_32bit u(.A(A),.B(B),.cin(cin),.sum(sum),.cout(cout));\n"
            "  task chk; input [31:0] x,y; input c; begin A=x;B=y;cin=c;#5; e=x+y+c;\n"
            "    if ({cout,sum}!==e) begin\n"
            '      $display("TDES_FAIL: test_id=carry_select_adder_32bit_integ |'
            ' input=A=%0d,B=%0d,cin=%0d | expected=%0d | got=%0d",x,y,c,e,{cout,sum});'
            " f=f+1; end end\n"
            "  endtask\n"
            "  initial begin\n"
            "    chk(32'd0,32'd0,0); chk(32'hFFFFFFFF,32'd1,0); chk(32'hFFFFFFFF,32'd0,1);\n"
            "    chk(32'hAAAAAAAA,32'h55555555,0); chk(32'h12345678,32'h0FEDCBA9,1);\n"
            "    chk(32'h80000000,32'h80000000,0);\n"
            '    if(f==0) $display("TDES_PASS: test_id=carry_select_adder_32bit_integ");'
            " $finish; end\n"
            "endmodule\n"
        ),
        description="32-bit carry-select adder built from eight 4-bit adder blocks",
    )
)


# ===========================================================================
# Public API
# ===========================================================================

DESIGNS: List[str] = list(_DESIGNS.keys())


def get(design: str) -> HierDesign:
    if design not in _DESIGNS:
        raise KeyError(f"unknown hierarchical design '{design}'; have {DESIGNS}")
    return _DESIGNS[design]


def _native_system_tb(design: HierDesign, bench_dir: Optional[str]) -> str:
    """Read the unmodified ArchXBench top-level testbench (the SYSTEM tier)."""
    root = bench_dir or os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "benchmarks", "archxbench"
    )
    ddir = benchmark_loader._find_archxbench_design(design.bench_design, root)
    tb_file = next((fn for fn in os.listdir(ddir) if fn.endswith(".v")), None)
    if tb_file is None:
        raise FileNotFoundError(f"no testbench .v in {ddir}")
    with open(os.path.join(ddir, tb_file), "r", encoding="utf-8", errors="ignore") as f:
        return f.read()


def build_suite(design: HierDesign, *, bench_dir: Optional[str] = None) -> VerilogTestSuite:
    """The 3-tier hierarchical suite (UNIT sub, INTEGRATION top, SYSTEM native)."""
    native_tb = _native_system_tb(design, bench_dir)
    tests = [
        VerilogTest(
            id=f"{design.sub}_unit",
            level=TestLevel.UNIT,
            module=design.sub,
            description=f"{design.sub}: submodule correct in isolation",
            testbench_source=design.sub_unit_tb,
            modules=[design.sub],
        ),
        VerilogTest(
            # UNIT tier (co-equal with the SUB test) so a top-fixing lineage and a
            # sub-fixing lineage are ranked equally and BOTH survive selection —
            # the diversity complementary-coverage crossover needs. (Tagging this
            # INTEGRATION would outrank the SUB unit test and let selection cull
            # the sub-fixers, starving crossover.)
            id=f"{design.top}_integ",
            level=TestLevel.UNIT,
            module=design.top,
            description=f"{design.top}: top-level wiring (verified against a golden {design.sub})",
            testbench_source=design.top_integration_tb,
            modules=[design.top],
        ),
        VerilogTest(
            id=f"{design.top}_system",
            level=TestLevel.SYSTEM,
            module=design.top,
            description=f"{design.description} (native ArchXBench testbench)",
            testbench_source=native_tb,
            modules=[design.top, design.sub],
        ),
    ]
    return VerilogTestSuite(
        module_names=[design.sub, design.top],
        tests=tests,
        top_module=design.top,
        isolate_modules=True,
    )


def _reference_mutator(design: HierDesign) -> ScriptedMutator:
    golden = {design.sub: design.sub_golden, design.top: design.top_golden}

    def fix(module, source, feedback, memory_text):
        if module in golden:
            return golden[module], f"inject reference {module}"
        return None

    mutator = ScriptedMutator(fix)
    mutator.reference = dict(golden)  # introspectable by experiments
    return mutator


def load_hierarchical(
    design: str, *, with_mutator: bool = False, bench_dir: Optional[str] = None, **_ignore
) -> LoaderResult:
    """Turn a published hierarchical ArchXBench design into a 2-module TDES problem.

    Signature mirrors ``benchmark_loader.load_*`` so it slots into the experiment
    runner's loader registry. Extra kwargs (e.g. ``decompose``) are accepted and
    ignored — this loader owns its own (already hierarchical) decomposition.
    """
    d = get(design)
    seed = Candidate(
        modules={d.top: d.top_skeleton, d.sub: d.sub_skeleton},
        metadata={
            "origin": "seed",
            "design": design,
            "reference": {d.top: d.top_golden, d.sub: d.sub_golden},
        },
    )
    suite = build_suite(d, bench_dir=bench_dir)
    mutator = _reference_mutator(d) if with_mutator else None
    return seed, suite, mutator
