โครงสร้าง repo ปัจจุบันมี 3 จุดที่ควรแก้จาก draft เดิมก่อนนำไปทำคู่มือจริง: RTL top คือ `osoc1_cpu_core`, CPU ใช้ Harvard-style instruction/data interfaces ไม่ใช่ GPIO และ official IHP Full-Chip template ปัจจุบันใช้ `meta.version: 3`, `flow: Chip`, `PL_TARGET_DENSITY_PCT`, `PAD_*` เป็น **รายชื่อ instance ของ pad** ไม่ใช่ mapping `{instance: cell-type}` แบบตัวอย่างเก่า ([GitHub][1])

ด้านล่างคือฉบับที่สามารถนำไปวางเป็นบทหลักของคู่มือได้ โดยออกแบบให้เริ่มจาก CPU RTL เดิม → Core-only validation → สร้าง observable test-chip wrapper → IHP IO pad ring → LibreLane Chip Flow → timing/PDN/routing/signoff และเตรียมทางต่อยอดไป SRAM macro

# Full-Chip Implementation of `synpnr_osoc1_cpu`

## ด้วย LibreLane และ IHP SG13G2 Open PDK

**Target design:** `synpnr_osoc1_cpu`
**Original repository:** ChipDesignRashid/synpnr_osoc1_cpu
**Working fork:** chumnarn/synpnr_osoc1_cpu
**Implementation flow:** LibreLane Chip Flow
**Target technology:** IHP SG13G2 130-nm BiCMOS Open PDK
**Implementation style:** RTL → Synthesis → Floorplan → Pad Ring → PDN → Placement → CTS → Routing → Signoff → GDSII

---

# 1. วัตถุประสงค์ของบทนี้

บทนี้อธิบายการนำ CPU RTL จากโครงการ `synpnr_osoc1_cpu` มาพัฒนาเป็น **Full-Chip ASIC** ที่ประกอบด้วย

```text
          +---------------------------------------+
          |               chip_top                |
          |                                       |
clk_PAD --> IHP Input Pad                         |
rst_PAD --> IHP Input Pad                         |
          |          +------------------+         |
          |          |    chip_core     |         |
          |          |                  |         |
          |          | +--------------+ |         |
          |          | | osoc1_cpu    | |         |
          |          | |    core      | |         |
          |          | +--------------+ |         |
          |          |        |         |         |
          |          | test ROM / RAM   |         |
          |          +------------------+         |
          |                    |                  |
          |            IHP Output Pads ---------> |
          |                                       |
          | VDD/VSS + IOVDD/IOVSS Pads            |
          +---------------------------------------+
```

เป้าหมายแรกของ implementation นี้ไม่ใช่การสร้าง SoC ที่สมบูรณ์ แต่เป็นการสร้าง **CPU test chip ที่สามารถตรวจสอบการทำงานทางกายภาพได้ง่าย**

แนวคิดคือให้ CPU execute คำสั่ง `NOP` อย่างต่อเนื่อง และนำบางบิตของ Program Counter ออกสู่ output pads

ดังนั้นเมื่อ clock ทำงาน จะสามารถสังเกตได้ว่า

```text
PC = 0x00000000
PC = 0x00000004
PC = 0x00000008
PC = 0x0000000C
...
```

และใช้ `PC[9:2]` เป็น observable output

```text
output_PAD[7:0] = PC[9:2]
```

วิธีนี้มีข้อดีคือ

* ไม่ต้องนำ memory bus 32-bit จำนวนมากออก pad
* ไม่ต้องใช้ SRAM macro ตั้งแต่ iteration แรก
* ตรวจสอบ CPU datapath ได้
* ตรวจสอบ clock/reset path ได้
* ทำ Full-Chip Pad Ring ได้ด้วยจำนวน pad ที่เหมาะสม
* เหมาะสำหรับใช้เป็น baseline ก่อนเพิ่ม SRAM/UART/GPIO ในขั้นต่อไป

---

# 2. ทำความเข้าใจ RTL ของ `synpnr_osoc1_cpu`

Repository เดิมประกอบด้วย module สำคัญ เช่น

```text
src/
├── alu.sv
├── alu_in_muxes.sv
├── bcu.sv
├── cpu_sv_package.sv
├── ctrl.sv
├── decoder.sv
├── lau.sv
├── next_pc_logic.sv
├── osoc1_cpu_core.sv
├── pc_plus_4.sv
├── pc_reg.sv
├── reg_file.sv
├── rf_wb_mux.sv
└── sau.sv
```

Top-level RTL สำหรับ CPU คือ

```systemverilog
module osoc1_cpu_core (
    input  logic        clk_i,
    input  logic        rst_ni,

    output logic [31:0] pc_o,
    input  logic [31:0] instr_i,

    output logic [3:0]  dmem_we_o,
    output logic [31:0] dmem_addr_o,
    output logic [31:0] dmem_wdata_o,
    input  logic [31:0] dmem_rdata_i
);
```

CPU จึงมี interface สองกลุ่มหลัก

### Instruction interface

```text
CPU ---> pc_o[31:0] ----> Instruction Memory
CPU <--- instr_i[31:0] <-- Instruction Memory
```

### Data interface

```text
CPU ---> dmem_addr_o[31:0]
CPU ---> dmem_wdata_o[31:0]
CPU ---> dmem_we_o[3:0]
CPU <--- dmem_rdata_i[31:0]
```

CPU ไม่มี instruction memory หรือ data memory อยู่ภายในตัวเอง

ดังนั้น

> `osoc1_cpu_core` เป็น CPU core ไม่ใช่ SoC

นี่เป็น distinction สำคัญมากก่อนออกแบบ Full Chip

---

# 3. เหตุใดจึงไม่ควรนำ Memory Bus ออก Pad โดยตรง

ถ้านำ interface ทั้งหมดออกสู่ package จะต้องใช้ประมาณ

```text
pc_o          32 outputs
instr_i       32 inputs

dmem_addr     32 outputs
dmem_wdata    32 outputs
dmem_we        4 outputs
dmem_rdata    32 inputs

clock          1 input
reset          1 input
------------------------
Total        166 signal pads
```

ยังไม่รวม

```text
VDD
VSS
IOVDD
IOVSS
```

ดังนั้น architecture นี้ไม่เหมาะกับ test chip ขนาดประมาณ 1.5 mm × 1.5 mm

สำหรับ workshop นี้เราจะใช้

```text
CPU
 |
 +--- internal instruction source
 |
 +--- internal dummy/test data memory
 |
 +--- PC observation output
```

ทำให้ signal pads ลดเหลือประมาณ

```text
clock       1
reset       1
output      8
----------------
           10 signal pads
```

---

# 4. Architecture ของ Full-Chip Baseline

Baseline architecture จะเป็น

```text
                         +-----------------------+
                         |       chip_core       |
                         |                       |
       clk ------------->|                       |
       rst_n ------------>|   +---------------+   |
                         |   | osoc1_cpu_core|   |
                         |   +---------------+   |
                         |       |       ^       |
                         |       | PC    | instr |
                         |       v       |       |
                         |   NOP Generator       |
                         |                       |
                         | dmem_rdata = 0        |
                         |                       |
                         | output = PC[9:2]      |
                         +----------+------------+
                                    |
                                    v
                             output pads
```

Instruction ทุก address เป็น

```text
0x00000013
```

ซึ่งคือ

```assembly
addi x0, x0, 0
```

หรือ RISC-V `NOP`

ดังนั้น CPU จะเดิน PC ทีละ 4 bytes

---

# 5. เตรียม Working Directory

Clone repository สำหรับทำงาน

```bash
cd ~/workshop

git clone https://github.com/chumnarn/synpnr_osoc1_cpu.git
cd synpnr_osoc1_cpu
```

ตรวจสอบ

```bash
git status
git log --oneline -5
```

จากนั้น clone official IHP LibreLane full-chip template แยกไว้

```bash
cd ~/workshop

git clone \
  https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template.git \
  osoc1_fullchip
```

เข้า project

```bash
cd ~/workshop/osoc1_fullchip
```

โครงสร้างที่เราจะสร้างคือ

```text
osoc1_fullchip/
├── src/
│   ├── cpu/
│   │   ├── cpu_sv_package.sv
│   │   ├── alu.sv
│   │   ├── ...
│   │   └── osoc1_cpu_core.sv
│   │
│   ├── chip_core.sv
│   └── chip_top.sv
│
├── librelane/
│   ├── config.yaml
│   ├── chip_top.sdc
│   └── pdn_cfg.tcl
│
├── cocotb/
├── ip/
├── Makefile
├── flake.nix
└── shell.nix
```

---

# 6. เข้า LibreLane Development Environment

Official IHP template เตรียม Nix environment ไว้แล้ว

รัน

```bash
nix-shell
```

ตรวจสอบ tool

```bash
which librelane
which yosys
which openroad
which verilator
which klayout
```

ตรวจ version

```bash
librelane --version
yosys -V
openroad -version
verilator --version
```

หากคำสั่งทั้งหมดทำงานได้ ให้ถือว่า environment พร้อม

---

# 7. ติดตั้ง IHP SG13G2 PDK

จาก root ของ template

```bash
make clone-pdk
```

ตรวจสอบ

```bash
ls ~/.ciel
```

และ

```bash
find ~/.ciel \
  -path '*sg13g2_stdcell*' \
  -type d | head
```

ตรวจ IO library

```bash
find ~/.ciel \
  -path '*sg13g2_io*' \
  -type d | head
```

ตรวจ SRAM library

```bash
find ~/.ciel \
  -name 'RM_IHPSG13_1P_1024x32_c2_bm_bist*'
```

---

# 8. Copy CPU RTL เข้าสู่ Full-Chip Project

สร้าง directory

```bash
mkdir -p src/cpu
```

copy RTL

```bash
cp ~/workshop/synpnr_osoc1_cpu/src/*.sv src/cpu/
```

ตรวจ

```bash
find src/cpu -maxdepth 1 -type f | sort
```

---

# 9. ตรวจ RTL Dependency ก่อนแตะ Physical Design

ห้ามเริ่ม LibreLane Full Chip ทันที

ควรตรวจ RTL ก่อนเสมอ

## 9.1 ตรวจ module

```bash
grep -R "^module " src/cpu
```

ตรวจ package

```bash
grep -R "^package " src/cpu
```

ควรพบ

```text
package cpu_sv_package
module alu
module alu_in_muxes
...
module osoc1_cpu_core
```

---

# 10. RTL Lint ด้วย Verilator

Package ต้องอ่านก่อน module ที่ import package

ตัวอย่าง

```bash
verilator \
  --lint-only \
  --Wall \
  --Wno-DECLFILENAME \
  --top-module osoc1_cpu_core \
  src/cpu/cpu_sv_package.sv \
  src/cpu/pc_reg.sv \
  src/cpu/pc_plus_4.sv \
  src/cpu/decoder.sv \
  src/cpu/ctrl.sv \
  src/cpu/alu_in_muxes.sv \
  src/cpu/alu.sv \
  src/cpu/sau.sv \
  src/cpu/lau.sv \
  src/cpu/rf_wb_mux.sv \
  src/cpu/reg_file.sv \
  src/cpu/bcu.sv \
  src/cpu/next_pc_logic.sv \
  src/cpu/osoc1_cpu_core.sv
```

เป้าหมายคือ

```text
0 Error
```

Warning บางประเภทอาจยอมรับได้ แต่ต้องตรวจทุก warning ก่อน synthesis

---

# 11. สร้าง `chip_core.sv`

`chip_core` ทำหน้าที่เป็น SoC wrapper ระหว่าง CPU กับ Full-Chip I/O system

สร้าง

```bash
nano src/chip_core.sv
```

ใช้ baseline ดังนี้

```systemverilog
`default_nettype none

module chip_core #(
    parameter integer NUM_INPUT_PADS  = 2,
    parameter integer NUM_OUTPUT_PADS = 8,
    parameter integer NUM_BIDIR_PADS  = 0,
    parameter integer NUM_ANALOG_PADS = 0
)(
    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_INPUT_PADS-1:0]   input_in,
    output wire [NUM_OUTPUT_PADS-1:0]  output_out,

    input  wire [NUM_BIDIR_PADS-1:0]   bidir_in,
    output wire [NUM_BIDIR_PADS-1:0]   bidir_out,
    output wire [NUM_BIDIR_PADS-1:0]   bidir_oe,

    inout wire [NUM_ANALOG_PADS-1:0]   analog
);

    wire [31:0] pc;
    wire [31:0] instr;

    wire [3:0]  dmem_we;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_rdata;

    /*
     * Baseline instruction source.
     *
     * 0x00000013 = ADDI x0, x0, 0 = RISC-V NOP
     */
    assign instr = 32'h0000_0013;

    /*
     * Baseline data memory response.
     *
     * CPU benchmark program contains only NOP,
     * therefore no data-memory access is required.
     */
    assign dmem_rdata = 32'h0000_0000;

    osoc1_cpu_core u_cpu (
        .clk_i        (clk),
        .rst_ni       (rst_n),

        .pc_o         (pc),
        .instr_i      (instr),

        .dmem_we_o    (dmem_we),
        .dmem_addr_o  (dmem_addr),
        .dmem_wdata_o (dmem_wdata),
        .dmem_rdata_i (dmem_rdata)
    );

    /*
     * Make CPU execution externally observable.
     *
     * PC increments by four, therefore PC[1:0]
     * are normally zero. Export PC[9:2].
     */
    assign output_out = pc[9:2];

    /*
     * Unused generic template interfaces.
     */
    assign bidir_out = '0;
    assign bidir_oe  = '0;

endmodule

`default_nettype wire
```

---

# 12. เหตุผลที่ใช้ `PC[9:2]`

หาก CPU ทำงานถูกต้อง

```text
PC[9:2]
```

จะมีลักษณะเหมือน binary counter

ตัวอย่าง

```text
PC            PC[9:2]
--------------------------------
0x00000000    00000000
0x00000004    00000001
0x00000008    00000010
0x0000000C    00000011
0x00000010    00000100
```

ดังนั้นหลัง fabrication สามารถต่อ logic analyzer เข้ากับ output pads แล้วตรวจการทำงานของ

* clock input
* reset input
* PC register
* next-PC logic
* control/datapath ขั้นพื้นฐาน

ได้โดยไม่ต้องมี UART

---

# 13. ตรวจ Wrapper ก่อน Full Chip

รัน lint โดยเพิ่ม `chip_core`

```bash
verilator \
  --lint-only \
  --Wall \
  --Wno-DECLFILENAME \
  --top-module chip_core \
  src/cpu/cpu_sv_package.sv \
  src/cpu/pc_reg.sv \
  src/cpu/pc_plus_4.sv \
  src/cpu/decoder.sv \
  src/cpu/ctrl.sv \
  src/cpu/alu_in_muxes.sv \
  src/cpu/alu.sv \
  src/cpu/sau.sv \
  src/cpu/lau.sv \
  src/cpu/rf_wb_mux.sv \
  src/cpu/reg_file.sv \
  src/cpu/bcu.sv \
  src/cpu/next_pc_logic.sv \
  src/cpu/osoc1_cpu_core.sv \
  src/chip_core.sv
```

ถ้าเจอ

```text
MULTITOP
```

ไม่ใช่ synthesis error โดยตรง แต่ควรระบุ

```bash
--top-module chip_core
```

---

# 14. ใช้ `chip_top.sv` จาก Official IHP Template

ไม่ควรเขียน IO pads เองตั้งแต่ศูนย์

Official template มีการ instantiate cell ที่ถูกต้อง เช่น

```text
sg13g2_IOPadIOVdd
sg13g2_IOPadIOVss
sg13g2_IOPadVdd
sg13g2_IOPadVss
sg13g2_IOPadIn
sg13g2_IOPadOut30mA
sg13g2_IOPadInOut30mA
sg13g2_IOPadAnalog
```

ดังนั้นให้ใช้ `chip_top.sv` เดิมจาก official template แล้วปรับ parameter

สำหรับ baseline CPU test chip ใช้

```systemverilog
parameter NUM_VDD_PADS    = 2;
parameter NUM_VSS_PADS    = 2;

parameter NUM_IOVDD_PADS  = 2;
parameter NUM_IOVSS_PADS  = 2;

parameter NUM_INPUT_PADS  = 2;
parameter NUM_OUTPUT_PADS = 8;

parameter NUM_BIDIR_PADS  = 0;
parameter NUM_ANALOG_PADS = 0;
```

หมายเหตุ:

`clk_PAD` และ `rst_n_PAD` เป็น dedicated pads อยู่แล้ว จึงไม่รวมใน `NUM_INPUT_PADS`

input pads เพิ่มอีก 2 ขาสามารถใช้ในอนาคตเป็น

```text
input_PAD[0] = test_mode
input_PAD[1] = boot_sel
```

---

# 15. Full-Chip I/O Architecture

IHP Pad Ring จะมี

```text
Core power:
  2 × VDD
  2 × VSS

I/O power:
  2 × IOVDD
  2 × IOVSS

Signals:
  1 × clock
  1 × reset
  2 × generic input
  8 × output
```

รวมประมาณ

```text
20 pads
```

ซึ่งเหมาะกว่าการนำ memory bus 166 สัญญาณออกโดยตรงมาก

---

# 16. Synthesis Source Order

เนื่องจาก RTL ใช้ SystemVerilog package ควรใช้ Slang frontend

ใน

```text
librelane/config.yaml
```

กำหนด

```yaml
USE_SLANG: true
```

และเรียง source file ให้ package มาก่อน

```yaml
VERILOG_FILES:
  - dir::../src/cpu/cpu_sv_package.sv

  - dir::../src/cpu/pc_reg.sv
  - dir::../src/cpu/pc_plus_4.sv

  - dir::../src/cpu/decoder.sv
  - dir::../src/cpu/ctrl.sv

  - dir::../src/cpu/alu_in_muxes.sv
  - dir::../src/cpu/alu.sv

  - dir::../src/cpu/sau.sv
  - dir::../src/cpu/lau.sv

  - dir::../src/cpu/rf_wb_mux.sv
  - dir::../src/cpu/reg_file.sv

  - dir::../src/cpu/bcu.sv
  - dir::../src/cpu/next_pc_logic.sv

  - dir::../src/cpu/osoc1_cpu_core.sv

  - dir::../src/chip_core.sv
  - dir::../src/chip_top.sv
```

ไม่ควรใส่ทั้ง

```text
rf_wb_mux.sv
```

และ

```text
rf_wb_mux.flat.v
```

พร้อมกัน หากทั้งสองประกาศ module ชื่อเดียวกัน

เพราะจะเกิด

```text
module redefinition
```

---

# 17. สร้าง SDC Constraint

สร้าง

```text
librelane/chip_top.sdc
```

ใช้ baseline 50 MHz

```tcl
# ============================================================
# Clock
# ============================================================

create_clock \
    -name core_clk \
    -period 20.000 \
    [get_ports clk_PAD]

# ============================================================
# Clock uncertainty
# ============================================================

set_clock_uncertainty 0.25 [get_clocks core_clk]

# ============================================================
# Input timing
# ============================================================

set_input_delay 2.0 \
    -clock core_clk \
    [get_ports {input_PAD[*]}]

# ============================================================
# Output timing
# ============================================================

set_output_delay 4.0 \
    -clock core_clk \
    [get_ports {output_PAD[*]}]

# ============================================================
# Transition
# ============================================================

set_input_transition 0.15 \
    [get_ports {input_PAD[*]}]

# ============================================================
# Output load
# ============================================================

set_load 0.033442 \
    [get_ports {output_PAD[*]}]

# Reset is asynchronous/non-timing critical
set_false_path \
    -from [get_ports rst_n_PAD]
```

---

# 18. Clock Port กับ Clock Net ต้องไม่สับสน

ใน Full Chip มี clock สองระดับ

```text
clk_PAD
   |
   v
sg13g2_IOPadIn
   |
   +---- p2c
          |
          v
       CPU clock
```

ดังนั้น configuration ควรเป็นลักษณะ

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
CLOCK_PERIOD: 20
```

ไม่ควรใช้ internal CPU net เป็น `CLOCK_PORT`

เพราะ `CLOCK_PORT` หมายถึง top-level chip input port

---

# 19. สร้าง `config.yaml`

เริ่มจาก official IHP configuration แล้วแก้เฉพาะส่วนที่จำเป็น

โครงสร้างเริ่มต้น

```yaml
meta:
  version: 3
  flow: Chip

DESIGN_NAME: chip_top
```

ตามด้วย RTL

```yaml
VERILOG_FILES:
  - dir::../src/cpu/cpu_sv_package.sv
  - dir::../src/cpu/pc_reg.sv
  - dir::../src/cpu/pc_plus_4.sv
  - dir::../src/cpu/decoder.sv
  - dir::../src/cpu/ctrl.sv
  - dir::../src/cpu/alu_in_muxes.sv
  - dir::../src/cpu/alu.sv
  - dir::../src/cpu/sau.sv
  - dir::../src/cpu/lau.sv
  - dir::../src/cpu/rf_wb_mux.sv
  - dir::../src/cpu/reg_file.sv
  - dir::../src/cpu/bcu.sv
  - dir::../src/cpu/next_pc_logic.sv
  - dir::../src/cpu/osoc1_cpu_core.sv
  - dir::../src/chip_core.sv
  - dir::../src/chip_top.sv
```

เปิด SystemVerilog frontend

```yaml
USE_SLANG: true
```

ถ้าต้องการรักษา hierarchy

```yaml
SLANG_ARGUMENTS:
  - --keep-hierarchy
```

---

# 20. Power/Ground Configuration

กำหนด

```yaml
VDD_NETS:
  - VDD

GND_NETS:
  - VSS
```

อย่าใช้ syntax เก่า

```yaml
VDD_NET: VDD
VSS_NET: VSS
```

หาก LibreLane version ปัจจุบันคาดหวัง list form

---

# 21. Floorplan Baseline

เริ่มจาก die

```yaml
FP_SIZING: absolute

DIE_AREA:
  - 0
  - 0
  - 1600
  - 1600

CORE_AREA:
  - 365
  - 365
  - 1235
  - 1235
```

มีพื้นที่ core

```text
870 µm × 870 µm
```

หรือประมาณ

```text
0.7569 mm²
```

ขนาดนี้เหมาะสำหรับ iteration แรกของ CPU core ขนาดเล็ก

---

# 22. Placement Density

LibreLane v3-style configuration ใช้

```yaml
PL_TARGET_DENSITY_PCT: 30
```

แนะนำเริ่ม

```text
25–35 %
```

สำหรับ CPU

เพราะ datapath 32-bit มี routing จำนวนมาก

หาก density สูงเกินไป

```text
45–60 %
```

อาจทำให้

```text
Global Routing congestion
Detailed Routing failure
Hold fixing difficulty
Antenna repair difficulty
```

---

# 23. Pad Placement

สำหรับ baseline ใช้ layout แบบสมดุล

```text
              NORTH
    +-------------------------+
    | OUT7 OUT6 OUT5 OUT4     |
    | VDD VSS                 |
    |                         |
WEST|                         |EAST
    |                         |
    |                         |
    |                         |
    | IN0 IN1                 |
    | IOVDD IOVSS             |
    +-------------------------+
             SOUTH
```

ตัวอย่าง

```yaml
PAD_SOUTH:
  - clk_pad
  - rst_n_pad
  - "inputs\\[0\\].input_pad"
  - "inputs\\[1\\].input_pad"
  - "iovdd_pads\\[0\\].iovdd_pad"
  - "iovss_pads\\[0\\].iovss_pad"

PAD_EAST:
  - "outputs\\[0\\].output_pad"
  - "outputs\\[1\\].output_pad"
  - "outputs\\[2\\].output_pad"
  - "outputs\\[3\\].output_pad"
  - "vdd_pads\\[0\\].vdd_pad"
  - "vss_pads\\[0\\].vss_pad"

PAD_NORTH:
  - "outputs\\[7\\].output_pad"
  - "outputs\\[6\\].output_pad"
  - "outputs\\[5\\].output_pad"
  - "outputs\\[4\\].output_pad"
  - "iovdd_pads\\[1\\].iovdd_pad"
  - "iovss_pads\\[1\\].iovss_pad"

PAD_WEST:
  - "vdd_pads\\[1\\].vdd_pad"
  - "vss_pads\\[1\\].vss_pad"
```

จุดสำคัญ:

`PAD_SOUTH`, `PAD_EAST`, `PAD_NORTH`, `PAD_WEST`

ต้องอ้าง **instance hierarchy ใน `chip_top.sv`**

ไม่ใช่ชื่อ top-level port

---

# 24. Bond Pad

Official IHP template มี external bondpad

ตัวอย่าง

```yaml
PAD_BONDPAD_NAME: bondpad_70x70_novias
```

และ

```yaml
EXTRA_GDS:
  - dir::../ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds

EXTRA_LEFS:
  - dir::../ip/bondpad_70x70_novias/lef/bondpad_70x70_novias.lef
```

ตรวจไฟล์ก่อน run

```bash
ls -lh \
  ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds

ls -lh \
  ip/bondpad_70x70_novias/lef/bondpad_70x70_novias.lef
```

หาก GDS/LEF ไม่พบ ห้ามเริ่ม full flow

---

# 25. SDC Configuration

ใส่

```yaml
PNR_SDC_FILE: dir::chip_top.sdc
SIGNOFF_SDC_FILE: dir::chip_top.sdc
FALLBACK_SDC: dir::chip_top.sdc
```

และ

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
CLOCK_PERIOD: 20
```

---

# 26. Power Distribution Network

เปิด core ring

```yaml
PDN_CORE_RING: true
```

เชื่อม ring กับ pads

```yaml
PDN_CORE_RING_CONNECT_TO_PADS: true
```

baseline width

```yaml
PDN_CORE_RING_VWIDTH: 15
PDN_CORE_RING_HWIDTH: 15
```

spacing

```yaml
PDN_CORE_RING_VSPACING: 5
PDN_CORE_RING_HSPACING: 5
```

และ

```yaml
PDN_ENABLE_PINS: false
```

---

# 27. Routing

เริ่มจาก

```yaml
GRT_ALLOW_CONGESTION: true
```

เฉพาะ bring-up

ไม่ได้หมายความว่ายอมรับ congestion ใน final design

หลังจาก flow ทำงานแล้วควรกลับมาเปลี่ยนเป็น

```yaml
GRT_ALLOW_CONGESTION: false
```

และแก้ floorplan ให้ routing clean จริง

---

# 28. Preflight ก่อน LibreLane

ก่อน run flow ทุกครั้งให้ตรวจตามลำดับ

## 28.1 RTL files

```bash
find src -type f \
  \( -name '*.sv' -o -name '*.v' \) \
  | sort
```

## 28.2 Top modules

```bash
grep -R "^module chip_top" src
grep -R "^module chip_core" src
grep -R "^module osoc1_cpu_core" src
```

## 28.3 Package

```bash
grep -R "^package cpu_sv_package" src
```

## 28.4 YAML

```bash
python3 - <<'PY'
import yaml

with open("librelane/config.yaml") as f:
    yaml.safe_load(f)

print("PASS: YAML syntax OK")
PY
```

## 28.5 SDC

```bash
test -f librelane/chip_top.sdc &&
echo "PASS: SDC exists"
```

## 28.6 Bond pad

```bash
test -f \
ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds \
&& echo "PASS: bondpad GDS exists"
```

---

# 29. Stage 1 — รันเฉพาะ Synthesis

ไม่ควรรัน GDS เต็มทันที

เริ่มจาก

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag osoc1_synth01 \
  --to Yosys.Synthesis \
  librelane/config.yaml
```

เป้าหมายคือ

```text
Yosys.Synthesis
        |
        +-- SUCCESS
```

---

# 30. ตรวจ Synthesis Log

ค้นหา error

```bash
grep -Rni \
  -E 'error|failed|unmapped|not found' \
  runs/osoc1_synth01
```

ตรวจ warning

```bash
grep -Rni \
  -E 'warning' \
  runs/osoc1_synth01 | head -100
```

---

# 31. ตรวจ Unmapped Cells

หลัง synthesis ต้องไม่มี logical cell ที่ map ไม่ได้

ค้นหา

```bash
grep -Rni \
  "unmapped" \
  runs/osoc1_synth01
```

หากพบ

```text
1 Unmapped Yosys instances found
```

ให้ตรวจ module

```bash
grep -R "^module " src/cpu src
```

และดู instantiated modules

```bash
grep -Rni \
  -E '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]+[A-Za-z_]' \
  src/cpu
```

---

# 32. ตรวจ Synthesis Statistics

สิ่งที่ควรบันทึกลง Lab report

```text
Number of cells
Number of sequential cells
Number of combinational cells
Chip area
Flip-flop count
Buffer count
Inverter count
Estimated timing
```

ใช้ข้อมูลนี้เป็น baseline สำหรับ PPA comparison

---

# 33. Stage 2 — Floorplan

เมื่อ synthesis clean แล้วจึง run ต่อถึง floorplan

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag osoc1_fp01 \
  --to OpenROAD.Floorplan \
  librelane/config.yaml
```

ตรวจ

```text
Die
Core
Rows
Tracks
Power domains
```

---

# 34. Floorplan Quality Check

หลัง Floorplan ให้ถาม 5 คำถาม

### 1. Core ใหญ่พอหรือไม่

```text
standard-cell area / core area
```

ไม่ควรสูงเกินไป

### 2. Pad ring มีพื้นที่พอหรือไม่

core ต้องไม่ชน IO pads

### 3. PDN ring มีพื้นที่พอหรือไม่

ต้องเหลือ channel ระหว่าง

```text
pad ring
core PDN
placement region
```

### 4. Clock pad อยู่ในตำแหน่งเหมาะสมหรือไม่

ควรหลีกเลี่ยง path จาก pad ถึง clock root ที่ยาวโดยไม่จำเป็น

### 5. Output pads กระจายตัวเหมาะสมหรือไม่

ควรแบ่ง bus ให้อยู่ติดกันเพื่อง่ายต่อ package routing

---

# 35. Stage 3 — Global Placement

รันต่อ

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag osoc1_place01 \
  --to OpenROAD.GlobalPlacement \
  librelane/config.yaml
```

ตรวจ

```text
utilization
overflow
wirelength
congestion
timing
```

---

# 36. แก้ Placement Congestion

ถ้าพบ congestion

วิธีที่ควรลองตามลำดับคือ

```text
1. ลด placement density
2. ขยาย core
3. ขยาย die
4. ปรับ macro/pad placement
5. ปรับ synthesis strategy
```

ตัวอย่าง

```yaml
PL_TARGET_DENSITY_PCT: 25
```

แทน

```yaml
PL_TARGET_DENSITY_PCT: 35
```

---

# 37. Stage 4 — Clock Tree Synthesis

Clock flow คือ

```text
clk_PAD
   |
IHP input pad
   |
p2c
   |
CTS root
   |
buffers
   |
CPU registers
```

รัน full flow ต่อจน CTS หรือใช้ run control ตาม LibreLane version ที่ติดตั้ง

หลัง CTS ตรวจ

```text
clock latency
clock skew
setup slack
hold slack
buffer count
```

---

# 38. วิเคราะห์ Setup Timing

หลักการ

```text
Setup Slack =
Required Time - Arrival Time
```

ต้องการ

```text
WNS >= 0
TNS = 0
```

ถ้า setup fail

ตัวอย่าง

```text
WNS = -2.1 ns
```

ให้แก้จาก

```text
20 ns
```

เป็น

```text
25 ns
```

ก่อนใน baseline

```yaml
CLOCK_PERIOD: 25
```

เท่ากับ

```text
40 MHz
```

---

# 39. วิเคราะห์ Hold Timing

Hold violation ไม่ควรแก้โดยเพิ่ม clock period

เพราะ hold เป็น local timing problem

LibreLane/OpenROAD จะพยายาม insert delay buffers

ถ้าพบ

```text
unresolved hold violations
```

ให้ตรวจ

```text
clock skew
placement congestion
hold buffer count
short data paths
CTS quality
```

---

# 40. Stage 5 — Global Routing

เป้าหมายคือพิสูจน์ว่า topology route ได้

ตรวจ

```text
routing congestion
overflow
unrouted nets
antenna estimation
via usage
```

หากพบ

```text
routing overflow
```

อย่าแก้ด้วย

```yaml
GRT_ALLOW_CONGESTION: true
```

เพียงอย่างเดียว

ต้องกลับไปแก้ placement/floorplan ด้วย

---

# 41. Stage 6 — Detailed Routing

Detailed router ต้องสร้าง geometry จริงบน metal layers

หลังจบควรมี

```text
0 unrouted nets
0 shorts
0 routing errors
```

หาก detailed route fail ทั้งที่ global route ผ่าน มักเกี่ยวข้องกับ

```text
local congestion
pin access
PDN obstruction
pad access
cell density
```

---

# 42. Antenna Check

Antenna violation เกิดจาก conductor ยาวสะสม charge ระหว่าง fabrication

flow อาจแก้โดย

```text
antenna diode
route modification
layer hopping
```

final design ต้องตรวจ report

```text
antenna violations = 0
```

---

# 43. Signoff STA

หลัง routing timing จะเปลี่ยนจาก pre-route เพราะมี

```text
real routed wire capacitance
real resistance
clock-tree parasitics
buffer insertion
```

ดังนั้นห้ามสรุป timing จาก synthesis เพียงอย่างเดียว

ต้องตรวจ post-route STA

ต้องการอย่างน้อย

```text
Setup WNS >= 0
Setup TNS = 0

Hold WNS >= 0
Hold TNS = 0
```

---

# 44. DRC

Design Rule Check ตรวจ physical layout rules เช่น

```text
minimum width
minimum spacing
via enclosure
metal density
notch
overlap
extension
```

Final target คือ

```text
DRC = 0
```

หาก workshop flow จำเป็นต้อง skip DRC บาง engine ระหว่าง debug ต้องระบุชัดว่า

> flow completion ไม่เท่ากับ tapeout clean

---

# 45. LVS

Layout Versus Schematic ตรวจว่า

```text
Physical Layout
       ==
Extracted Circuit
       ==
Logical Netlist
```

LVS mismatch ใน full chip มักเกิดจาก

```text
power pad connectivity
IO power domain
bondpad
VDD/VSS naming
macro power pins
hierarchy flattening
```

ต้องการ

```text
LVS clean
```

---

# 46. ตรวจ Layout ด้วย OpenROAD GUI

หลัง flow ถึง placement/routing สามารถเปิด OpenROAD

```bash
make librelane-openroad
```

ตรวจทีละ layer

```text
1. Die boundary
2. Pad ring
3. Core ring
4. Placement
5. Clock tree
6. Global routing
7. Detailed routing
8. PDN
```

---

# 47. ตรวจ GDS ด้วย KLayout

เปิด

```bash
make librelane-klayout
```

ตรวจ

```text
bondpads
IO cells
power pads
core boundary
metal routing
seal ring
fill
```

ควร zoom ตรวจ corner ทั้งสี่ด้านเป็นพิเศษ

เพราะ corner ของ pad ring เป็นตำแหน่งที่พบ geometry/spacing issue ได้ง่าย

---

# 48. Run Full Flow

เมื่อ checkpoint ก่อนหน้าผ่านแล้วจึงรันเต็ม

```bash
make librelane
```

หรือ

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag osoc1_fullchip01 \
  librelane/config.yaml
```

บันทึก log

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag osoc1_fullchip01 \
  librelane/config.yaml \
  2>&1 | tee osoc1_fullchip01.log
```

---

# 49. Final Artifacts

เมื่อ flow ผ่าน ควรเก็บอย่างน้อย

```text
GDSII
DEF
LEF
gate-level Verilog
SDF
timing reports
DRC reports
LVS reports
antenna reports
metrics
configuration snapshot
```

จาก official template สามารถใช้

```bash
make copy-final
```

---

# 50. Gate-Level Simulation

ขั้นถัดไปหลัง implementation คือ

```text
RTL simulation
        vs
gate-level simulation
```

Official template รองรับ

```bash
make sim
```

สำหรับ RTL และ

```bash
make sim-gl
```

สำหรับ Gate-Level

หลัง GL simulation ต้องตรวจว่า

```text
reset
PC sequence
output pads
```

ยังให้ผลเหมือน RTL

---

# 51. Functional Success Criteria

Test chip baseline นี้ถือว่าทำงานถูกต้องเมื่อ

หลัง reset

```text
PC = 0
```

และแต่ละ rising edge

```text
PC <= PC + 4
```

ดังนั้น

```text
output_PAD
```

ต้องเพิ่มแบบ binary counter

ตัวอย่าง

```text
cycle  output
----------------
0      00
1      01
2      02
3      03
4      04
...
```

---

# 52. Recommended Lab Structure

เพื่อใช้เป็น workshop แนะนำแบ่งออกเป็น 10 Labs

## Lab 1 — Explore `synpnr_osoc1_cpu`

เรียนรู้

```text
RTL hierarchy
CPU interface
instruction interface
data interface
```

Deliverable:

```text
CPU architecture diagram
module hierarchy
```

---

## Lab 2 — RTL Lint and Synthesis Readiness

ทำ

```text
Verilator lint
package ordering
module dependency
```

Deliverable:

```text
lint-clean CPU
```

---

## Lab 3 — Core-Only Synthesis

ใช้

```text
DESIGN_NAME = osoc1_cpu_core
```

เป้าหมาย

```text
technology mapping
cell count
area
timing
```

Deliverable:

```text
CPU synthesis baseline
```

---

## Lab 4 — Build Full-Chip Wrapper

สร้าง

```text
chip_core
chip_top
```

และ NOP generator

Deliverable:

```text
observable CPU test chip
```

---

## Lab 5 — IHP SG13G2 Pad Ring

ศึกษา

```text
IOPadIn
IOPadOut
VDD
VSS
IOVDD
IOVSS
```

Deliverable:

```text
20-pad floorplan
```

---

## Lab 6 — Floorplan and PDN

ศึกษา

```text
die/core area
power ring
pad-to-core power connection
```

Deliverable:

```text
PDN-complete floorplan
```

---

## Lab 7 — Placement and CTS

วิเคราะห์

```text
placement density
clock skew
setup timing
hold timing
```

Deliverable:

```text
post-CTS timing report
```

---

## Lab 8 — Routing

ศึกษา

```text
global routing
detailed routing
congestion
antenna
```

Deliverable:

```text
routed DEF
```

---

## Lab 9 — Signoff

ตรวจ

```text
STA
DRC
LVS
antenna
```

Deliverable:

```text
signoff checklist
```

---

## Lab 10 — GDS and Gate-Level Verification

ทำ

```text
GDS inspection
GL simulation
SDF simulation
```

Deliverable:

```text
final chip_top.gds
final chip_top.v
final reports
```

---

# 53. ขั้นต่อยอด: Full SoC Version

หลัง baseline ผ่านแล้วจึงเปลี่ยน architecture เป็น

```text
             +----------------------+
             |       CPU Core       |
             +----------+-----------+
                        |
           +------------+------------+
           |                         |
           v                         v
     Instruction SRAM           Data SRAM
        1024 × 32                1024 × 32
           |                         |
           +------------+------------+
                        |
                     MMIO
                        |
        +---------------+---------------+
        |               |               |
      GPIO             UART            Timer
```

นี่จะเปลี่ยน project จาก

```text
CPU test chip
```

เป็น

```text
small RISC-V SoC
```

---

# 54. IHP SRAM Macro Extension

IHP SG13G2 LibreLane template ปัจจุบันมีตัวอย่าง macro

```text
RM_IHPSG13_1P_1024x32_c2_bm_bist
```

พร้อม

```text
GDS
LEF
Verilog model
Liberty
```

ดังนั้น Phase 2 สามารถสร้าง Harvard memory

```text
CPU
 |
 +--- SRAM0 = instruction memory
 |
 +--- SRAM1 = data memory
```

แต่ต้องเพิ่ม

```text
MACROS
PDN_MACRO_CONNECTIONS
PDN_CFG
macro placement
SRAM timing model
functional initialization strategy
```

จึงควรทำหลัง baseline full-chip ผ่านแล้ว

---

# 55. Implementation Ladder ที่แนะนำ

ไม่ควรกระโดดจาก RTL ไป GDS โดยตรง

ใช้ขั้นบันได

```text
Level 0
RTL lint
    |
Level 1
CPU standalone synthesis
    |
Level 2
chip_core RTL simulation
    |
Level 3
chip_top RTL simulation
    |
Level 4
Full-chip synthesis
    |
Level 5
Floorplan
    |
Level 6
Pad Ring + PDN
    |
Level 7
Placement
    |
Level 8
CTS
    |
Level 9
Routing
    |
Level 10
STA + DRC + LVS
    |
Level 11
Gate-level simulation
    |
Level 12
Tapeout package
```

หลักการนี้ทำให้ root cause ของ error แคบลงอย่างมาก

---

# 56. Debug Strategy

เมื่อ flow fail ให้จำแนก error ก่อน

## RTL error

```text
module not found
package not found
syntax error
multiple drivers
```

กลับไปแก้ RTL

---

## Synthesis error

```text
unmapped cells
unsupported construct
hierarchy error
```

ตรวจ

```text
source files
module name
Slang
black box
```

---

## Floorplan error

```text
pad overlap
core too large
invalid die/core dimensions
```

แก้ geometry

---

## Placement error

```text
high utilization
overflow
congestion
```

แก้ density/core area

---

## CTS error

```text
max buffer count
unresolved hold
clock root incorrect
```

แก้ clock constraint และ placement

---

## Routing error

```text
GRT congestion
unrouted nets
DRT violations
```

กลับไปแก้ floorplan/placement

---

## LVS error

```text
net mismatch
power mismatch
macro mismatch
```

ตรวจ

```text
VDD/VSS
pad power
macro power
black-box model
```

---

# 57. Tapeout Readiness Checklist

ก่อนเรียก design ว่า ready ต้องตอบ “ผ่าน” ทุกข้อ

### RTL

```text
[ ] Lint clean
[ ] Simulation pass
[ ] Reset verified
[ ] CPU observable
```

### Synthesis

```text
[ ] No unmapped cells
[ ] No unresolved modules
[ ] Cell count reasonable
```

### Floorplan

```text
[ ] Pads legal
[ ] Core utilization reasonable
[ ] No overlap
```

### Power

```text
[ ] VDD connected
[ ] VSS connected
[ ] IOVDD connected
[ ] IOVSS connected
[ ] Core ring complete
```

### Timing

```text
[ ] Setup WNS >= 0
[ ] Setup TNS = 0
[ ] Hold WNS >= 0
[ ] Hold TNS = 0
```

### Routing

```text
[ ] 0 unrouted nets
[ ] No congestion overflow
```

### Physical Verification

```text
[ ] Antenna clean
[ ] DRC clean
[ ] LVS clean
```

### Deliverables

```text
[ ] GDS
[ ] LEF
[ ] DEF
[ ] netlist
[ ] SDF
[ ] timing reports
[ ] DRC report
[ ] LVS report
[ ] exact config snapshot
```

---

# 58. Recommended Version Roadmap

แนะนำพัฒนา project เป็น version ต่อเนื่อง

```text
V1.0
CPU + NOP source + PC output
Full-chip baseline

V1.1
CPU + small instruction ROM
Run real instruction sequence

V1.2
CPU + instruction ROM + data RAM
Load/store verification

V2.0
CPU + IHP SRAM macro

V2.1
CPU + SRAM + GPIO

V2.2
CPU + SRAM + UART

V3.0
Minimal RISC-V SoC

V4.0
Tapeout-oriented full chip
```

---

# 59. สรุป

หัวใจสำคัญของ Full-Chip Implementation ของ `synpnr_osoc1_cpu` คือการเข้าใจก่อนว่า CPU RTL เดิมเป็น **processor core ที่ต้องการ external instruction/data memory**

ดังนั้นการนำ CPU ออกสู่ IHP pad ring โดยตรงจะทำให้จำนวน IO สูงเกินความจำเป็น

วิธี implementation ที่เหมาะสมกว่าคือ

```text
osoc1_cpu_core
      |
      v
chip_core
      |
      +-- internal instruction source
      +-- internal data response
      +-- observable PC outputs
      |
      v
chip_top
      |
      +-- IHP IO pads
      +-- VDD/VSS pads
      +-- IOVDD/IOVSS pads
      +-- bondpads
      |
      v
LibreLane Chip Flow
      |
      v
GDSII
```

เมื่อ baseline นี้ผ่าน Synthesis → Floorplan → Pad Ring → PDN → Placement → CTS → Routing → STA → DRC → LVS แล้ว จึงค่อยเพิ่ม IHP SRAM macros และ peripherals เพื่อยกระดับจาก CPU test chip ไปสู่ RISC-V SoC เต็มรูปแบบ

ข้อมูลที่ยึดเป็นฐานในฉบับนี้คือ repo ต้นฉบับปัจจุบันซึ่งมี `osoc1_cpu_core.sv` และโมดูลย่อยหลายไฟล์ รวมทั้งสำเนา `src_sv2v` และ netlist SKY130 เดิม ([GitHub][1]) ตัว CPU จริงมี ports `clk_i`, `rst_ni`, `pc_o`, `instr_i`, `dmem_we_o`, `dmem_addr_o`, `dmem_wdata_o`, `dmem_rdata_i` ตามที่ใช้ใน wrapper ด้านบน ([github.com][2])

ส่วน Full-Chip infrastructure ปรับให้ตรงกับ official IHP template ปัจจุบัน ซึ่งใช้ `chip_top` + `chip_core`, IHP cells `sg13g2_IOPadIn`, `sg13g2_IOPadOut30mA`, power pads และ generic arrays สำหรับ input/output/bidir/analog pads ([GitHub][3]) Template ปัจจุบันยังแสดงตัวอย่าง `DIE_AREA [0,0,1600,1600]`, `CORE_AREA [365,365,1235,1235]`, `VDD_NETS/GND_NETS`, `CLOCK_NET: clk_pad/p2c`, PDN core ring และการประกาศ SRAM macro `RM_IHPSG13_1P_1024x32_c2_bm_bist` ซึ่งเหมาะมากสำหรับทำ **V2 ต่อจากคู่มือนี้** ([GitHub][4])

จุดที่แนะนำให้ทำต่อทันทีคือ **Lab 1–Lab 4 แบบ ready-to-run พร้อมไฟล์จริงทั้งหมด** ได้แก่ `chip_core.sv`, `chip_top.sv`, `config.yaml`, `chip_top.sdc`, testbench และ Makefile เพื่อให้เริ่มจาก `git clone` แล้วรันถึง `Yosys.Synthesis` ได้จริงก่อน จากนั้นค่อยต่อ Floorplan/PDN/CTS/Routing.

[1]: https://github.com/ChipDesignRashid/synpnr_osoc1_cpu/tree/main/src "synpnr_osoc1_cpu/src at main · ChipDesignRashid/synpnr_osoc1_cpu · GitHub"
[2]: https://github.com/ChipDesignRashid/synpnr_osoc1_cpu/blob/main/src/osoc1_cpu_core.sv "synpnr_osoc1_cpu/src/osoc1_cpu_core.sv at main · ChipDesignRashid/synpnr_osoc1_cpu · GitHub"
[3]: https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template/blob/main/src/chip_top.sv "ihp-sg13g2-librelane-template/src/chip_top.sv at main · IHP-GmbH/ihp-sg13g2-librelane-template · GitHub"
[4]: https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template/blob/main/librelane/config.yaml "ihp-sg13g2-librelane-template/librelane/config.yaml at main · IHP-GmbH/ihp-sg13g2-librelane-template · GitHub"
