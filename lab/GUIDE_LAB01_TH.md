# Lab 1 — Explore `synpnr_osoc1_cpu`
## RTL Architecture, Source-Set Validation, Lint และ NOP Smoke Test

**Project:** `synpnr_osoc1_cpu`  
**Target flow ใน Lab ถัดไป:** LibreLane + IHP SG13G2  
**ระดับ:** Intermediate ASIC / RTL-to-GDSII  
**รูปแบบ:** Ready-to-run  
**Top module ที่ใช้ใน Lab นี้:** `osoc1_cpu_core`

---

## 1. วัตถุประสงค์ของ Lab

ก่อนนำ RTL เข้า Synthesis หรือ Full-Chip Flow สิ่งแรกที่ต้องทำไม่ใช่เขียน `config.yaml`
แต่คือการตอบคำถามต่อไปนี้ให้ได้จาก source code จริง:

1. Top module ของ CPU คืออะไร
2. RTL ต้อง compile ด้วยลำดับใด
3. มี SystemVerilog package หรือไม่
4. CPU interface ติดต่อกับ instruction/data memory อย่างไร
5. Module hierarchy ภายใน CPU เป็นอย่างไร
6. มี source file ที่เป็น implementation ซ้ำกันหรือไม่
7. RTL lint ผ่านหรือไม่
8. CPU สามารถ execute instruction ขั้นต่ำและเดิน Program Counter ได้หรือไม่

Lab นี้จึงทำหน้าที่เป็น **Pre-Synthesis Design Understanding Gate**

ถ้า Lab 1 ยังไม่ผ่าน ไม่ควรเริ่ม LibreLane synthesis เพราะ error ในขั้นหลังจะมี root cause ที่ซับซ้อนขึ้นอย่างมาก

---

# 2. Learning Outcomes

เมื่อจบ Lab ผู้เรียนควรสามารถ:

- ระบุ `osoc1_cpu_core` เป็น CPU core top module
- อธิบาย Harvard-like instruction/data interfaces ของ CPU
- อธิบายบทบาทของ `cpu_sv_package.sv`
- ระบุ RTL source set ที่ควรใช้กับ synthesis
- อธิบายความเสี่ยงของ `rf_wb_mux.sv` กับ `rf_wb_mux.flat.v`
- สร้าง module inventory อัตโนมัติ
- สร้าง top-level port report
- สร้าง hierarchy report
- รัน Verilator lint
- รัน NOP smoke test
- ตรวจว่า `PC = PC + 4`
- ตรวจว่า NOP ไม่สร้าง data-memory write

---

# 3. โครงสร้าง Lab Package

หลังแตก ZIP จะได้:

```text
lab01_explore_synpnr_osoc1_cpu/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB01_TH.md
│
├── scripts/
│   ├── check_env.sh
│   ├── rtl_inventory.py
│   ├── extract_ports.py
│   ├── module_graph.py
│   ├── find_duplicate_modules.py
│   └── build_report.py
│
├── tb/
│   └── tb_osoc1_cpu.sv
│
└── reports/
    └── .gitkeep
```

Lab package นี้ **ไม่ copy CPU RTL ซ้ำ** เพื่อป้องกัน source divergence

CPU RTL จะถูกอ่านตรงจาก repository:

```text
synpnr_osoc1_cpu/src/
```

---

# 4. ตำแหน่งติดตั้งที่แนะนำ

Clone repository ก่อน:

```bash
mkdir -p ~/workshop
cd ~/workshop

git clone https://github.com/chumnarn/synpnr_osoc1_cpu.git
cd synpnr_osoc1_cpu
```

สร้าง directory:

```bash
mkdir -p labs
```

แตก Lab package ให้ได้:

```text
~/workshop/synpnr_osoc1_cpu/
├── src/
├── src_sv2v/
├── ...
└── labs/
    └── lab01_explore_synpnr_osoc1_cpu/
```

เข้า Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab01_explore_synpnr_osoc1_cpu
```

ตรวจ path:

```bash
pwd
```

ควรได้ประมาณ:

```text
/home/<user>/workshop/synpnr_osoc1_cpu/labs/lab01_explore_synpnr_osoc1_cpu
```

---

# 5. ตรวจ Repository Revision

เพื่อให้ผล Lab reproducible ควรบันทึก Git revision ทุกครั้ง

```bash
cd ~/workshop/synpnr_osoc1_cpu

git status
git branch --show-current
git rev-parse HEAD
git log -1 --oneline
```

แนะนำบันทึก commit hash ลง Lab report

เหตุผลคือ RTL อาจเปลี่ยนในอนาคต และผล lint/synthesis อาจเปลี่ยนตาม source revision

---

# 6. สำรวจโครงสร้าง Repository

จาก repository root:

```bash
find . -maxdepth 2 -type f | sort
```

โครงสร้างหลักที่เกี่ยวข้องกับ flow คือ:

```text
synpnr_osoc1_cpu/
├── src/
├── src_sv2v/
├── syn_netlist/
├── sdc/
├── scripts/
├── librelane/
├── cocotb/
└── doc/
```

สำหรับ Lab 1 เราสนใจ:

```text
src/
```

เป็นหลัก

---

# 7. สำรวจ RTL Source จริง

รัน:

```bash
find src -maxdepth 1 -type f | sort
```

ควรพบไฟล์หลัก เช่น:

```text
src/alu.sv
src/alu_in_muxes.sv
src/bcu.sv
src/chip_core.sv
src/chip_top.sv
src/cpu_sv_package.sv
src/ctrl.sv
src/decoder.sv
src/lau.sv
src/next_pc_logic.sv
src/osoc1_cpu_core.sv
src/pc_plus_4.sv
src/pc_reg.sv
src/reg_file.sv
src/rf_wb_mux.flat.v
src/rf_wb_mux.sv
src/sau.sv
```

จุดสังเกตสำคัญ:

```text
osoc1_cpu_core.sv
```

คือ CPU core

ขณะที่:

```text
chip_core.sv
chip_top.sv
```

เป็น full-chip integration layer ซึ่งเราจะศึกษาใน Lab ต่อไป

---

# 8. ตรวจ Environment

กลับเข้า Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab01_explore_synpnr_osoc1_cpu
```

รัน:

```bash
make check-env
```

Script จะตรวจ:

```text
python3
verilator
grep
sed
awk
```

ตัวอย่างผลลัพธ์:

```text
== Lab 1 environment check ==
PASS python3      /usr/bin/python3
PASS verilator    /path/to/verilator
PASS grep         /usr/bin/grep
PASS sed          /usr/bin/sed
PASS awk          /usr/bin/awk

Python 3.x.x
Verilator 5.x
PASS: environment is ready.
```

## Pass criterion

ต้องไม่มี:

```text
FAIL ... not found
```

ถ้า `verilator` ไม่พบ แนะนำรัน Lab ภายใน Nix shell เดียวกับ LibreLane/IHP SG13G2

---

# 9. ตรวจ Source Files ที่ Lab ต้องใช้

รัน:

```bash
make check-src
```

Makefile คาดหวัง source set:

```text
cpu_sv_package.sv
pc_reg.sv
pc_plus_4.sv
decoder.sv
ctrl.sv
alu_in_muxes.sv
alu.sv
sau.sv
lau.sv
rf_wb_mux.sv
reg_file.sv
bcu.sv
next_pc_logic.sv
osoc1_cpu_core.sv
```

ถ้าไฟล์หายจะหยุดทันที เช่น:

```text
ERROR: missing .../src/alu.sv
```

นี่สำคัญมากเพราะไม่ควรปล่อยให้ synthesis เป็นขั้นแรกที่บอกว่า source file หาย

---

# 10. ทำไม `cpu_sv_package.sv` ต้องอยู่ก่อน

SystemVerilog อนุญาตให้ประกาศ type, enum, constant และ function ใน package

รูปแบบทั่วไป:

```systemverilog
package cpu_sv_package;

    typedef enum logic [...] {
        ...
    } some_type_t;

endpackage
```

module อื่นอาจใช้:

```systemverilog
import cpu_sv_package::*;
```

ดังนั้น compiler ต้องรู้จัก package ก่อน

source order จึงเริ่มจาก:

```text
cpu_sv_package.sv
```

แล้วตามด้วย modules

นี่เป็นเหตุผลที่ Lab ใช้ explicit file list แทน:

```bash
src/*.sv
```

เพราะ wildcard ไม่รับประกัน semantic compile order ที่เราต้องการ

---

# 11. สร้าง RTL Inventory

รัน:

```bash
make inventory
```

script:

```text
scripts/rtl_inventory.py
```

จะ:

1. scan `.sv`
2. scan `.v`
3. หา `package`
4. หา `module`
5. map module → filename

ผลลัพธ์:

```text
reports/01_inventory.txt
```

เปิดดู:

```bash
cat reports/01_inventory.txt
```

จุดประสงค์ไม่ใช่แค่รู้จำนวนไฟล์ แต่ใช้เป็น **Source-of-Truth Inventory** สำหรับ Lab ถัดไป

---

# 12. ระบุ Top Module

ค้นหา:

```bash
grep -R "^module " ../../src
```

หรือ:

```bash
grep -n "^module" ../../src/osoc1_cpu_core.sv
```

ควรพบ:

```text
module osoc1_cpu_core
```

ดังนั้น synthesis top สำหรับ CPU core-only คือ:

```text
DESIGN_NAME = osoc1_cpu_core
```

ไม่ใช่:

```text
osoc1_cpu
```

---

# 13. สร้าง Top-Level Port Report

รัน:

```bash
make ports
```

ผล:

```text
reports/02_top_ports.txt
```

เปิด:

```bash
cat reports/02_top_ports.txt
```

interface ที่ต้องเข้าใจ:

```text
clk_i
rst_ni

pc_o[31:0]
instr_i[31:0]

dmem_we_o[3:0]
dmem_addr_o[31:0]
dmem_wdata_o[31:0]
dmem_rdata_i[31:0]
```

---

# 14. วิเคราะห์ Clock และ Reset

```text
clk_i
```

เป็น clock input

```text
rst_ni
```

suffix:

```text
_ni
```

โดย convention หมายถึง:

```text
n = active low
i = input
```

ดังนั้น reset asserted เมื่อ:

```text
rst_ni = 0
```

และ deasserted เมื่อ:

```text
rst_ni = 1
```

Lab smoke test จะเริ่มด้วย:

```systemverilog
rst_ni = 1'b0;
```

แล้วปล่อย reset ก่อนทดสอบ CPU

---

# 15. วิเคราะห์ Instruction Interface

CPU มี:

```text
pc_o[31:0]
instr_i[31:0]
```

conceptual connection:

```text
             pc_o[31:0]
       +--------------------->
       |
+------+-------+        +-------------------+
|              |        | Instruction Memory|
| CPU Core     |        | / ROM / SRAM      |
|              |<-------|                   |
+--------------+ instr_i+-------------------+
```

sequence:

1. CPU สร้าง Program Counter
2. `pc_o` ใช้เป็น instruction address
3. instruction memory คืน instruction
4. instruction เข้า `instr_i`
5. CPU decode/execute

จึงกล่าวได้ว่า CPU core ไม่ได้มี program memory อยู่ภายใน interface นี้

---

# 16. วิเคราะห์ Data-Memory Interface

CPU มี:

```text
dmem_we_o[3:0]
dmem_addr_o[31:0]
dmem_wdata_o[31:0]
dmem_rdata_i[31:0]
```

conceptual connection:

```text
CPU Core                          Data Memory
--------                          -----------
dmem_addr_o[31:0] -------------> address
dmem_wdata_o[31:0] ------------> write-data
dmem_we_o[3:0] ----------------> byte write-enable
dmem_rdata_i[31:0] <------------ read-data
```

`dmem_we_o[3:0]` มี 4 bits สำหรับ datapath 32-bit

จึงเหมาะกับ byte-lane write enable:

```text
bit 0 -> byte [7:0]
bit 1 -> byte [15:8]
bit 2 -> byte [23:16]
bit 3 -> byte [31:24]
```

---

# 17. ทำไม CPU Core นี้ยังไม่ใช่ SoC

SoC โดยทั่วไปต้องมีองค์ประกอบเพิ่ม เช่น:

```text
CPU
ROM / Boot memory
RAM
interconnect
GPIO
UART
timer
interrupt controller
clock/reset infrastructure
IO pads
power pads
```

แต่ `osoc1_cpu_core` expose memory interfaces ออกมา

จึงควรเรียกว่า:

```text
CPU core
```

ไม่ใช่:

```text
standalone SoC
```

นี่จะเป็นเหตุผลที่ใน Full-Chip flow เราต้องมี:

```text
osoc1_cpu_core
       |
       v
chip_core
       |
       v
chip_top
```

---

# 18. วิเคราะห์ Pad-Count Problem

ถ้านำ CPU buses ออก pads โดยตรง:

```text
pc_o             32
instr_i          32
dmem_we_o         4
dmem_addr_o      32
dmem_wdata_o     32
dmem_rdata_i     32
clk_i             1
rst_ni            1
--------------------
signal bits      166
```

ยังไม่รวม:

```text
VDD
VSS
IOVDD
IOVSS
```

ดังนั้น architecture แบบ "CPU bus directly to pads" ไม่เหมาะกับ test chip ขนาดเล็ก

ข้อสรุปจาก Lab 1:

> Full-chip wrapper ควร keep instruction/data memory on-chip และ expose เฉพาะ debug/observable signals ที่จำเป็น

---

# 19. สร้าง Module Hierarchy

รัน:

```bash
make hierarchy
```

ผล:

```text
reports/03_hierarchy.txt
```

เปิด:

```bash
cat reports/03_hierarchy.txt
```

script จะเริ่มจาก:

```text
osoc1_cpu_core
```

แล้วค้น instantiated modules ที่ประกาศอยู่ใน source set

expected architectural blocks ได้แก่:

```text
PC register
PC + 4
decoder
controller
register file
ALU input muxes
ALU
store alignment unit
load alignment unit
writeback mux
branch control
next-PC logic
```

---

# 20. อ่าน Architecture จากชื่อ Module

## `pc_reg`

ทำหน้าที่เก็บ Program Counter state

เป็น sequential element หลักของ instruction flow

---

## `pc_plus_4`

คำนวณ:

```text
next sequential PC = PC + 4
```

เพราะ instruction RV32I ปกติยาว 32 bits = 4 bytes

---

## `decoder`

แยก field ของ instruction เช่น:

```text
opcode
rd
rs1
rs2
funct3
funct7
immediate
```

---

## `ctrl`

สร้าง control signals จาก decoded instruction

เช่น:

```text
ALU operation
writeback select
register write enable
memory control
branch/jump behavior
```

---

## `reg_file`

เก็บ integer registers

สำหรับ RV32I:

```text
x0 ... x31
```

โดย:

```text
x0 = 0
```

---

## `alu`

ดำเนินการ arithmetic/logic เช่น:

```text
ADD
SUB
AND
OR
XOR
shift
compare
```

---

## `sau`

Store Alignment Unit

จัด write-data และ byte enable สำหรับ:

```text
SB
SH
SW
```

---

## `lau`

Load Alignment Unit

เลือก/จัดรูป data สำหรับ:

```text
LB
LBU
LH
LHU
LW
```

---

## `rf_wb_mux`

เลือกข้อมูล write-back เข้าสู่ register file

อาจมาจาก:

```text
ALU
load data
PC+4
```

---

## `bcu`

Branch Control Unit

ใช้ตัดสินใจ branch condition

---

## `next_pc_logic`

เลือก next PC ระหว่าง:

```text
PC + 4
branch target
jump target
```

---

# 21. ตรวจ Duplicate Module Definitions

รัน:

```bash
make duplicates
```

ผล:

```text
reports/04_duplicate_modules.txt
```

repository มี:

```text
rf_wb_mux.sv
rf_wb_mux.flat.v
```

ไฟล์ `.flat.v` มักเป็นผลจาก preprocessing/flatten/translation บางขั้น

ถ้าทั้งสองประกาศ:

```systemverilog
module rf_wb_mux
```

แล้ว compile พร้อมกัน จะได้ error ลักษณะ:

```text
Duplicate module
Module redefinition
```

ดังนั้น Lab กำหนด source-of-truth เป็น:

```text
src/rf_wb_mux.sv
```

และไม่ใช้ `.flat.v` ใน RTL source set นี้

---

# 22. รัน Verilator Lint

รัน:

```bash
make lint
```

Makefile จะเรียก:

```bash
verilator \
  --lint-only \
  --Wall \
  --Wno-DECLFILENAME \
  --Wno-UNUSEDSIGNAL \
  --top-module osoc1_cpu_core \
  <ordered RTL source list>
```

log:

```text
reports/05_verilator_lint.log
```

เปิด:

```bash
less reports/05_verilator_lint.log
```

---

# 23. สิ่งที่ Lint ตรวจให้เรา

Lint ช่วยจับปัญหาเช่น:

```text
syntax errors
missing modules
undefined symbols
width mismatch
unused signals
unconnected ports
latch risk
multiple drivers
case issues
```

แต่ต้องเข้าใจว่า:

> lint pass ไม่ได้แปลว่า CPU function ถูกต้อง

มันหมายถึง:

> RTL structure พร้อมเข้าสู่ functional test และ synthesis มากขึ้น

---

# 24. Pass Criteria สำหรับ Lint

ต้องไม่มี:

```text
%Error
```

และต้องไม่มี fatal issues เช่น:

```text
Cannot find file
Cannot find module
Package not found
Unsupported syntax
```

warning สามารถมีได้ใน Lab exploratory แต่ต้องอ่านและจัดประเภท

ตัวอย่าง warning ที่อาจเป็น benign:

```text
UNUSEDSIGNAL
```

ใน block ที่มี signal สำหรับ instruction type อื่นที่ smoke test ยังไม่ได้ใช้

---

# 25. ทำไมต้องมี Functional Smoke Test ก่อน Synthesis

ถ้า lint ผ่านแต่:

```text
PC ไม่เดิน
reset ผิด polarity
NOP decode ผิด
next-PC mux ผิด
```

synthesis ก็ยังสามารถสร้าง hardware ที่ "ผิดอย่างถูก syntax" ได้

ดังนั้นก่อน synthesis เราต้องมี minimum functional proof

สำหรับ CPU นี้ test ที่ง่ายและทรงพลังที่สุดคือ:

```text
execute NOP repeatedly
```

---

# 26. RISC-V NOP ที่ใช้ใน Lab

instruction:

```text
0x00000013
```

decode เป็น:

```assembly
addi x0, x0, 0
```

เนื่องจาก:

```text
x0 = 0
```

การเขียนกลับเข้า `x0` ไม่มีผล

จึงเป็น architectural NOP

---

# 27. Expected PC Behavior

ถ้า reset PC เริ่มที่:

```text
0x00000000
```

และทุก instruction เป็น 32-bit NOP

expected sequence:

```text
Cycle 0 : 0x00000000
Cycle 1 : 0x00000004
Cycle 2 : 0x00000008
Cycle 3 : 0x0000000C
Cycle 4 : 0x00000010
...
```

นี่ตรวจเส้นทางสำคัญ:

```text
PC register
   |
   v
PC + 4
   |
   v
next_pc_logic
   |
   v
PC register
```

พร้อม control path สำหรับ NOP

---

# 28. Testbench จริง — `tb/tb_osoc1_cpu.sv`

ไฟล์ใน Lab package:

```systemverilog
`timescale 1ns/1ps

module tb_osoc1_cpu;

    logic        clk_i;
    logic        rst_ni;
    logic [31:0] pc_o;
    logic [31:0] instr_i;

    logic [3:0]  dmem_we_o;
    logic [31:0] dmem_addr_o;
    logic [31:0] dmem_wdata_o;
    logic [31:0] dmem_rdata_i;

    localparam logic [31:0] RV32_NOP = 32'h0000_0013;

    osoc1_cpu_core dut (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .pc_o         (pc_o),
        .instr_i      (instr_i),
        .dmem_we_o    (dmem_we_o),
        .dmem_addr_o  (dmem_addr_o),
        .dmem_wdata_o (dmem_wdata_o),
        .dmem_rdata_i (dmem_rdata_i)
    );

    initial clk_i = 1'b0;
    always #5 clk_i = ~clk_i;

    initial begin
        instr_i      = RV32_NOP;
        dmem_rdata_i = 32'h0000_0000;
        rst_ni       = 1'b0;

        #2;
        if (pc_o !== 32'h0000_0000) begin
            $error("Reset failed: PC=%08x expected 00000000", pc_o);
            $fatal(1);
        end

        @(negedge clk_i);
        rst_ni = 1'b1;

        for (int cycle = 1; cycle <= 16; cycle++) begin
            @(posedge clk_i);
            #1;

            if (pc_o !== (cycle * 4)) begin
                $error("Cycle %0d: PC=%08x expected=%08x",
                       cycle, pc_o, cycle * 4);
                $fatal(1);
            end

            if (dmem_we_o !== 4'b0000) begin
                $error("NOP unexpectedly asserted dmem_we_o=%b",
                       dmem_we_o);
                $fatal(1);
            end

            $display("cycle=%0d pc=%08x dmem_we=%b PASS",
                     cycle, pc_o, dmem_we_o);
        end

        $display(
          "PASS: osoc1_cpu_core executes RV32 NOP and PC increments by 4."
        );

        $finish;
    end

endmodule
```

---

# 29. วิเคราะห์ Testbench ทีละส่วน

## 29.1 Clock

```systemverilog
initial clk_i = 1'b0;
always #5 clk_i = ~clk_i;
```

period:

```text
10 ns
```

frequency:

```text
100 MHz
```

นี่เป็น simulation clock เท่านั้น

ไม่ได้หมายความว่า ASIC target frequency ต้องเป็น 100 MHz

---

## 29.2 Instruction Source

```systemverilog
instr_i = RV32_NOP;
```

หมายความว่าไม่ว่า `pc_o` จะเป็น address ใด instruction memory สมมติจะคืน NOP เสมอ

เทียบเท่า ROM:

```text
address 0x00000000 -> NOP
address 0x00000004 -> NOP
address 0x00000008 -> NOP
...
```

---

## 29.3 Data Memory

```systemverilog
dmem_rdata_i = 32'h00000000;
```

NOP ไม่ควร access data memory

ดังนั้นค่า read data ไม่มีผลต่อ functional outcome ใน test นี้

---

## 29.4 Reset Check

```systemverilog
rst_ni = 1'b0;
```

แล้วตรวจ:

```systemverilog
pc_o === 0
```

ถ้า reset architecture ผิด test จะหยุดทันที

---

## 29.5 PC Check

แต่ละ cycle:

```systemverilog
pc_o == cycle * 4
```

หากผิด:

```text
$fatal
```

ทำให้ CI/Makefile เห็น exit failure จริง

---

## 29.6 Memory Write Check

NOP ต้องไม่ store

ดังนั้น:

```systemverilog
dmem_we_o == 4'b0000
```

หากมี bit ใดเป็น 1 แสดงว่า control decode มี behavior ผิดสำหรับ NOP

---

# 30. รัน NOP Smoke Test

รัน:

```bash
make sim
```

Makefile จะ:

1. สร้าง Verilator C++ simulation model
2. compile model
3. สร้าง executable
4. run executable
5. tee log ลง reports

expected output:

```text
cycle=1 pc=00000004 dmem_we=0000 PASS
cycle=2 pc=00000008 dmem_we=0000 PASS
cycle=3 pc=0000000c dmem_we=0000 PASS
...
cycle=16 pc=00000040 dmem_we=0000 PASS

PASS: osoc1_cpu_core executes RV32 NOP and PC increments by 4.
```

log:

```text
reports/07_nop_smoke_test.log
```

---

# 31. Run ทุกขั้นในคำสั่งเดียว

หลังทดสอบแต่ละ target แล้วให้รัน:

```bash
make clean
make all
```

ลำดับอัตโนมัติ:

```text
check-env
   |
check-src
   |
inventory
   |
ports
   |
hierarchy
   |
duplicates
   |
lint
   |
sim
   |
report
```

expected final message:

```text
============================================================
LAB 1 PASS
Report: reports/LAB01_REPORT.md
============================================================
```

---

# 32. Lab Report ที่สร้างอัตโนมัติ

ไฟล์:

```text
reports/LAB01_REPORT.md
```

ประกอบด้วย:

```text
Git revision
RTL inventory
top ports
hierarchy
duplicate-module findings
Verilator lint log
NOP smoke-test log
```

นี่ควรเก็บเป็น artifact ก่อนเริ่ม Lab 2

---

# 33. Makefile จริง

หัวใจของ Makefile คือ explicit CPU source set:

```make
RTL_FILES := \
    $(SRC_DIR)/cpu_sv_package.sv \
    $(SRC_DIR)/pc_reg.sv \
    $(SRC_DIR)/pc_plus_4.sv \
    $(SRC_DIR)/decoder.sv \
    $(SRC_DIR)/ctrl.sv \
    $(SRC_DIR)/alu_in_muxes.sv \
    $(SRC_DIR)/alu.sv \
    $(SRC_DIR)/sau.sv \
    $(SRC_DIR)/lau.sv \
    $(SRC_DIR)/rf_wb_mux.sv \
    $(SRC_DIR)/reg_file.sv \
    $(SRC_DIR)/bcu.sv \
    $(SRC_DIR)/next_pc_logic.sv \
    $(SRC_DIR)/osoc1_cpu_core.sv
```

จุดสำคัญ:

- package มาก่อน
- CPU submodules ตามด้วย top
- ไม่มี `rf_wb_mux.flat.v`
- ไม่มี `chip_top.sv`
- ไม่มี `chip_core.sv`

เพราะ Lab นี้ต้อง isolate CPU core

---

# 34. รัน Lab จาก Directory อื่น

ถ้าไม่วางใต้ `repo/labs/`

สามารถใช้:

```bash
make \
  REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu \
  all
```

หรือ:

```bash
./QUICKSTART.sh \
  $HOME/workshop/synpnr_osoc1_cpu
```

---

# 35. Troubleshooting — `src/ not found`

อาการ:

```text
ERROR: src/ not found
```

สาเหตุ:

```text
REPO_ROOT ผิด
```

ตรวจ:

```bash
pwd
realpath ../..
ls ../../src
```

หรือระบุ explicit:

```bash
make REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu all
```

---

# 36. Troubleshooting — `verilator: command not found`

ตรวจ:

```bash
which verilator
```

ถ้าไม่พบ:

- เข้า LibreLane/IHP Nix shell
- หรือใช้ environment ที่ติดตั้ง Verilator แล้ว

อย่าเปลี่ยนไปใช้ simulator อื่นโดยไม่บันทึก เพราะ Lab ต้องการ reproducibility

---

# 37. Troubleshooting — Package Not Found

อาการอาจคล้าย:

```text
Can't find package
Unknown type
Unknown identifier
```

ตรวจ:

```bash
grep -R "import cpu_sv_package" ../../src
```

และยืนยันว่า:

```text
cpu_sv_package.sv
```

อยู่ก่อน modules ใน compile command

---

# 38. Troubleshooting — Duplicate Module

อาการ:

```text
Duplicate declaration
Module redefinition: rf_wb_mux
```

ตรวจ:

```bash
grep -n "^module" \
  ../../src/rf_wb_mux.sv \
  ../../src/rf_wb_mux.flat.v
```

solution:

```text
compile เพียง rf_wb_mux.sv
```

สำหรับ RTL source set นี้

---

# 39. Troubleshooting — PC ไม่เพิ่มทีละ 4

ถ้า smoke test fail:

```text
Cycle N: PC=... expected=...
```

ตรวจตามลำดับ:

```text
pc_reg
pc_plus_4
next_pc_logic
decoder
ctrl
```

แล้วตรวจว่า:

```text
instr_i = 0x00000013
```

จริง

---

# 40. Troubleshooting — `dmem_we_o != 0`

NOP ไม่ควรเขียน memory

ถ้า:

```text
dmem_we_o != 0000
```

ให้ตรวจ:

```text
decoder
ctrl
sau
```

และ instruction decode ของ opcode:

```text
0010011
```

ซึ่งเป็น OP-IMM

---

# 41. Design Review Questions

ผู้เรียนต้องตอบได้ก่อนผ่าน Lab:

### Q1
ทำไม `osoc1_cpu_core` ไม่ใช่ SoC?

### Q2
`pc_o` เป็น address หรือ instruction data?

### Q3
ทำไม `instr_i` เป็น input ของ CPU?

### Q4
`dmem_we_o[3:0]` มี 4 bit เพราะอะไร?

### Q5
ทำไมเราไม่ควรนำ 166 signal bits ออก pad ตรง ๆ?

### Q6
ทำไม `cpu_sv_package.sv` ต้องมาก่อน module files?

### Q7
ทำไมไม่ compile `rf_wb_mux.sv` และ `.flat.v` พร้อมกัน?

### Q8
NOP smoke test ยืนยัน block ใดบ้าง?

### Q9
NOP smoke test ไม่ได้ยืนยันอะไรบ้าง?

คำตอบข้อ 9 ควรครอบคลุมว่า test นี้ยังไม่ได้ verify:

```text
branch
jump
load
store
all ALU operations
register dependencies
memory timing
exceptions
interrupts
```

---

# 42. Pass/Fail Criteria

Lab 1 PASS เมื่อครบ:

```text
[ ] Repository path ถูกต้อง
[ ] Git revision ถูกบันทึก
[ ] make check-env PASS
[ ] make check-src PASS
[ ] inventory ถูกสร้าง
[ ] top module = osoc1_cpu_core
[ ] top-level interfaces ถูกระบุครบ
[ ] hierarchy report ถูกสร้าง
[ ] duplicate-module risk ถูกตรวจ
[ ] rf_wb_mux.flat.v ไม่อยู่ใน RTL source set
[ ] Verilator lint ไม่มี Error
[ ] NOP smoke test PASS
[ ] reset ทำให้ PC = 0
[ ] PC เพิ่มทีละ 4
[ ] NOP ทำให้ dmem_we_o = 0000
[ ] reports/LAB01_REPORT.md ถูกสร้าง
```

---

# 43. Deliverables

ผู้เรียนต้องส่ง:

```text
reports/01_inventory.txt
reports/02_top_ports.txt
reports/03_hierarchy.txt
reports/04_duplicate_modules.txt
reports/05_verilator_lint.log
reports/07_nop_smoke_test.log
reports/LAB01_REPORT.md
```

และตอบ design-review questions

---

# 44. สิ่งที่ Freeze จาก Lab 1 สำหรับ Lab 2

หลัง Lab 1 ให้ถือว่า configuration ต่อไปนี้เป็น baseline:

```text
CPU_TOP = osoc1_cpu_core

RTL frontend:
SystemVerilog

Package:
cpu_sv_package.sv first

Writeback mux source:
rf_wb_mux.sv

Do not use in CPU core-only synthesis:
chip_core.sv
chip_top.sv
rf_wb_mux.flat.v
```

---

# 45. Transition ไป Lab 2

Lab 2 จะเปลี่ยนจาก:

```text
RTL understanding
+
lint
+
functional smoke test
```

ไปเป็น:

```text
osoc1_cpu_core
      |
      v
LibreLane / Yosys
      |
      v
IHP SG13G2 standard cells
```

หัวข้อสำคัญของ Lab 2 ได้แก่:

```text
Core-only LibreLane config
USE_SLANG
IHP SG13G2 PDK
SDC clock
Yosys synthesis
unmapped-cell check
cell statistics
area
timing baseline
```

หลักการสำคัญคือ:

> อย่าเริ่ม Full-Chip pad-ring integration จนกว่า CPU core-only synthesis จะ clean

นี่ทำให้เราสามารถแยกปัญหา RTL/synthesis ออกจาก IO/PDN/floorplan problems ได้อย่างชัดเจน
