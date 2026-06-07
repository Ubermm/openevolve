"""
A four-module compositional Verilog problem for the crossover ablation.

Modules (varying difficulty), an empty seed, and a hierarchical suite:
  * unit tests, one per module (add8, bshift, scmp, popcnt)
  * integration tests, each combining two modules
  * a system test using all four

Because the integration/system tests only pass once *multiple* modules are
correct, a candidate that has fixed a subset passes a strict subset of tests —
exactly the complementary coverage that crossover grafts. With one module fixed
per candidate per generation, no single lineage can fix all four modules in
fewer than four generations, so under a tight generation budget crossover (which
combines partial solutions) is *necessary*, not merely faster.

`reference()` returns a fully-correct codebase (used to validate the suite and as
the offline reference-injecting mutator).
"""

from __future__ import annotations

from typing import Dict

from openevolve.tdes.fpga.verilog_suite import VerilogTest, VerilogTestSuite
from openevolve.tdes.types import TestLevel

MODULES = ["add8", "bshift", "scmp", "popcnt"]

SEED: Dict[str, str] = {
    "add8": "module add8(input [7:0] a, b, input cin, output [7:0] sum, output cout);\n  // TODO\nendmodule\n",
    "bshift": "module bshift(input [7:0] a, input [2:0] sh, output [7:0] y);\n  // TODO\nendmodule\n",
    "scmp": "module scmp(input [7:0] a, b, output lt);\n  // TODO\nendmodule\n",
    "popcnt": "module popcnt(input [7:0] a, output [3:0] cnt);\n  // TODO\nendmodule\n",
}

REFERENCE: Dict[str, str] = {
    "add8": "module add8(input [7:0] a, b, input cin, output [7:0] sum, output cout);\n"
    "  assign {cout, sum} = a + b + cin;\nendmodule\n",
    "bshift": "module bshift(input [7:0] a, input [2:0] sh, output [7:0] y);\n"
    "  assign y = a << sh;\nendmodule\n",
    "scmp": "module scmp(input [7:0] a, b, output lt);\n"
    "  assign lt = ($signed(a) < $signed(b));\nendmodule\n",
    "popcnt": "module popcnt(input [7:0] a, output [3:0] cnt);\n"
    "  assign cnt = a[0]+a[1]+a[2]+a[3]+a[4]+a[5]+a[6]+a[7];\nendmodule\n",
}


def reference() -> Dict[str, str]:
    return dict(REFERENCE)


# --- testbenches (TDES protocol). TID is replaced with the test id. ---------

_TB_ADD = """`timescale 1ns/1ps
module tb;
  reg [7:0] a,b; reg cin; wire [7:0] sum; wire cout; integer f=0;
  add8 u(.a(a),.b(b),.cin(cin),.sum(sum),.cout(cout));
  task chk(input [7:0] x,y, input c, input [8:0] e);
   begin a=x;b=y;cin=c;#5;
    if ({cout,sum}!==e) begin $display("TDES_FAIL: test_id=TID | input=a=%0d,b=%0d,cin=%0d | expected=%0d | got=%0d",x,y,c,e,{cout,sum}); f=f+1; end end
  endtask
  initial begin chk(3,4,0,9'd7); chk(255,1,0,9'd256); chk(200,100,1,9'd301);
   if(f==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

_TB_SHIFT = """`timescale 1ns/1ps
module tb;
  reg [7:0] a; reg [2:0] sh; wire [7:0] y; integer f=0;
  bshift u(.a(a),.sh(sh),.y(y));
  task chk(input [7:0] x, input [2:0] s, input [7:0] e);
   begin a=x;sh=s;#5;
    if (y!==e) begin $display("TDES_FAIL: test_id=TID | input=a=%0d,sh=%0d | expected=%0d | got=%0d",x,s,e,y); f=f+1; end end
  endtask
  initial begin chk(8'b00000001,3,8'b00001000); chk(8'hFF,4,8'hF0); chk(8'h0F,0,8'h0F);
   if(f==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

_TB_SCMP = """`timescale 1ns/1ps
module tb;
  reg [7:0] a,b; wire lt; integer f=0;
  scmp u(.a(a),.b(b),.lt(lt));
  task chk(input [7:0] x,y, input e);
   begin a=x;b=y;#5;
    if (lt!==e) begin $display("TDES_FAIL: test_id=TID | input=a=%0d,b=%0d | expected=%0d | got=%0d",$signed(x),$signed(y),e,lt); f=f+1; end end
  endtask
  initial begin chk(8'hFF,8'h01,1'b1); chk(8'h7F,8'h80,1'b0); chk(8'h05,8'h05,1'b0);
   if(f==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

_TB_POP = """`timescale 1ns/1ps
module tb;
  reg [7:0] a; wire [3:0] cnt; integer f=0;
  popcnt u(.a(a),.cnt(cnt));
  task chk(input [7:0] x, input [3:0] e);
   begin a=x;#5;
    if (cnt!==e) begin $display("TDES_FAIL: test_id=TID | input=a=%0d | expected=%0d | got=%0d",x,e,cnt); f=f+1; end end
  endtask
  initial begin chk(8'hFF,4'd8); chk(8'h00,4'd0); chk(8'h0F,4'd4); chk(8'hA5,4'd4);
   if(f==0) $display("TDES_PASS: test_id=TID"); $finish; end
endmodule
"""

# Integration: (a+b) then shift left by 1 — needs add8 AND bshift.
_TB_ADD_SHIFT = """`timescale 1ns/1ps
module tb;
  reg [7:0] a,b; wire [7:0] sum; wire cout; wire [7:0] y;
  add8 ua(.a(a),.b(b),.cin(1'b0),.sum(sum),.cout(cout));
  bshift us(.a(sum),.sh(3'd1),.y(y));
  initial begin a=8'd3;b=8'd4;#5;
   if (y===8'd14) $display("TDES_PASS: test_id=TID");
   else $display("TDES_FAIL: test_id=TID | input=a=3,b=4 | expected=14 | got=%0d",y); $finish; end
endmodule
"""

# Integration: popcount of the byte whose value is the signed-less-than result
# replicated — needs scmp AND popcnt.
_TB_CMP_POP = """`timescale 1ns/1ps
module tb;
  reg [7:0] a,b; wire lt; wire [3:0] cnt;
  scmp uc(.a(a),.b(b),.lt(lt));
  popcnt up(.a({8{lt}}),.cnt(cnt));
  initial begin a=8'hFF;b=8'h01;#5;   // -1 < 1 -> lt=1 -> {8{1}}=0xFF -> popcount 8
   if (lt===1'b1 && cnt===4'd8) $display("TDES_PASS: test_id=TID");
   else $display("TDES_FAIL: test_id=TID | input=a=-1,b=1 | expected=lt=1,cnt=8 | got=lt=%0d,cnt=%0d",lt,cnt); $finish; end
endmodule
"""

# System: all four modules in one datapath.
_TB_ALL = """`timescale 1ns/1ps
module tb;
  reg [7:0] a,b; wire [7:0] sum; wire cout; wire [7:0] y; wire lt; wire [3:0] cnt;
  add8 ua(.a(a),.b(b),.cin(1'b0),.sum(sum),.cout(cout));
  bshift us(.a(sum),.sh(3'd2),.y(y));
  scmp uc(.a(a),.b(b),.lt(lt));
  popcnt up(.a(y),.cnt(cnt));
  initial begin a=8'd5;b=8'd3;#5;   // sum=8, y=32(0x20)->popcount1, 5<3 signed -> 0
   if (sum===8'd8 && y===8'd32 && lt===1'b0 && cnt===4'd1) $display("TDES_PASS: test_id=TID");
   else $display("TDES_FAIL: test_id=TID | input=a=5,b=3 | expected=sum=8,y=32,lt=0,cnt=1 | got=sum=%0d,y=%0d,lt=%0d,cnt=%0d",sum,y,lt,cnt); $finish; end
endmodule
"""


def build_suite() -> VerilogTestSuite:
    def tb(src, tid):
        return src.replace("TID", tid)

    tests = [
        VerilogTest(
            "u_add", TestLevel.UNIT, "add8", "8-bit adder with carry", tb(_TB_ADD, "u_add")
        ),
        VerilogTest(
            "u_shift",
            TestLevel.UNIT,
            "bshift",
            "logical left barrel shift",
            tb(_TB_SHIFT, "u_shift"),
        ),
        VerilogTest("u_scmp", TestLevel.UNIT, "scmp", "signed less-than", tb(_TB_SCMP, "u_scmp")),
        VerilogTest(
            "u_pop", TestLevel.UNIT, "popcnt", "population count of a byte", tb(_TB_POP, "u_pop")
        ),
        VerilogTest(
            "i_add_shift",
            TestLevel.INTEGRATION,
            "add8",
            "(a+b) shifted left by 1 (add8+bshift)",
            tb(_TB_ADD_SHIFT, "i_add_shift"),
            modules=["add8", "bshift"],
        ),
        VerilogTest(
            "i_cmp_pop",
            TestLevel.INTEGRATION,
            "scmp",
            "popcount of replicated signed-compare bit (scmp+popcnt)",
            tb(_TB_CMP_POP, "i_cmp_pop"),
            modules=["scmp", "popcnt"],
        ),
        VerilogTest(
            "s_all",
            TestLevel.SYSTEM,
            "add8",
            "full datapath using all four modules",
            tb(_TB_ALL, "s_all"),
            modules=MODULES,
        ),
    ]
    return VerilogTestSuite(module_names=MODULES, tests=tests, top_module="add8")
