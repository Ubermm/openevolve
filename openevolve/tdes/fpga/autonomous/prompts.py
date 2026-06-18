"""Prompt templates for the autonomous decompose-test-evolve pipeline."""

DECOMPOSE_SYSTEM = """\
You are a digital design architect. You decompose complex RTL specifications \
into independent sub-modules that can be developed and verified separately. \
You produce correct, compilable Verilog on the first attempt."""

DECOMPOSE_USER = """\
## Design Specification

{problem_description}

## Design Interface

{design_specs}

## Original System Testbench

This testbench is the GROUND TRUTH. Your decomposed design must pass every \
test case in this testbench when composed.

```verilog
{testbench}
```

## Task

Decompose this design into 3-7 independent sub-modules and one top-level \
module that wires them together.

### Architecture Rules

1. Sub-modules should be purely combinational where possible (no clk, no rst). \
ALL sequential logic (pipeline registers, state machines, counters, valid \
shift registers, reset) goes in the top module.
2. The top module instantiates every sub-module, connects them through \
pipeline register stages (if pipelined) or combinational wiring (if not), \
and handles any control logic.
3. Any status/flag signals that are computed early but consumed late MUST be \
forwarded through all intermediate pipeline stages in the top module.
4. The top module name MUST be `{top_module_name}` with the exact port \
signature from the design interface above.
5. Read the testbench carefully — match its expected timing, latency, and \
I/O behavior exactly.

### Design Guidelines

- Study the testbench to understand the exact expected behavior
- Use wide intermediates where needed to detect overflow/underflow
- Handle all edge cases the testbench covers (special values, boundaries)
- If the design is pipelined, count the exact pipeline stages from the spec
- If the design uses fixed-point or floating-point, get bit widths exactly right

### Output Format

Wrap each file in XML-style tags. The ONLY format accepted is:

<file name="module_name.v" type="top">
...verilog source...
</file>

<file name="module_name.v" type="reference">
...verilog source...
</file>

<file name="module_name.v" type="skeleton">
...verilog source...
</file>

Produce IN ORDER:
1. One file type="top" — the complete top-level wrapper (fully implemented)
2. One file type="reference" per sub-module — complete working implementation
3. One file type="skeleton" per sub-module — correct ports, all outputs = 0

After all files, a JSON summary:

<json>
{{"top_module": "{top_module_name}", "sub_modules": [{{"name": "...", "description": "..."}}]}}
</json>
"""

TEST_GEN_SYSTEM = """\
You are a hardware verification engineer. Write short, simple Verilog \
testbenches. Use inline checks with if/else — NO helper tasks. Keep it under 150 lines."""

TEST_GEN_USER = """\
## Module Under Test

```verilog
{port_list}
```

Description: {description}
Context: Part of a pipelined {design_description}. {context}

## Write a testbench

Rules:
1. `timescale 1ns/1ps, module tb, declare reg for inputs, wire for outputs
2. Instantiate as `dut` using EXACTLY the port names from the module above
3. Write 5-8 inline test cases (NO helper tasks). Pattern for each:

   <input_reg> = <value>; #10;
   if (<output_wire> !== <expected>)
     $display("TDES_FAIL: test_id={module_name}_testN | input=%h | expected=%h | got=%h", <input>, <expected>, <output>);
   else
     $display("TDES_PASS: test_id={module_name}_testN");

4. End with $finish
5. Timeout: initial begin #5000; $display("TDES_FAIL: test_id={module_name}_timeout | input=timeout | expected=done | got=hang"); $finish; end
6. DO NOT include the module source — only instantiate it
7. Check ALL outputs for each test, not just one

Wrap output in:
<file name="unit_{module_name}_tb.v" type="testbench">
...source...
</file>
"""
