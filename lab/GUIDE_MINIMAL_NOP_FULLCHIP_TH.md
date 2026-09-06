# Minimal NOP Full-Chip
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**CPU:** `osoc1_cpu_core`  
**Core wrapper:** `chip_core`  
**Chip top:** `chip_top`  
**Instruction:** `32'h0000_0013` = RV32I NOP  
**Clock:** 50 MHz / 20 ns  
**Observable output:** `PC[9:2]`  
**Output pads:** 8 × `sg13g2_IOPadOut30mA`  
**Input pads:** clock + reset  
**Core power:** VDD/VSS  
**I/O power:** IOVDD/IOVSS

---

# 1. วัตถุประสงค์

ก่อนสร้าง O'SoC 1.0 ที่มี:

```text
ROM
SRAM
System Bus
GPIO
Timer
SPI
PLIC
Debug
```

ควรมี full-chip reference ที่ง่ายที่สุดซึ่งตอบคำถามว่า:

> CPU จริงของเรา สามารถถูกห่อด้วย IHP SG13G2 pads และผ่าน full-chip flow ได้หรือไม่?

minimal reference นี้จึงตัด subsystem อื่นออกทั้งหมด

เหลือเพียง:

```text
CPU
clock
reset
constant instruction
observable output
I/O pads
power pads
```

---

# 2. Architecture

```text
                PACKAGE / CHIP BOUNDARY

 clk_PAD
    |
    v
sg13g2_IOPadIn
    |
    v
+------------------------------------------------+
|                  chip_core                     |
|                                                |
|  instr_i = 0x00000013                          |
|                                                |
|              +-------------------+             |
|              | osoc1_cpu_core    |             |
|              |                   |             |
|              | PC -> 0,4,8,...   |             |
|              +---------+---------+             |
|                        |                       |
|                     PC[9:2]                    |
+------------------------+-----------------------+
                         |
                         v
             8 x sg13g2_IOPadOut30mA
                         |
                         v
                output_PAD[7:0]
```

---

# 3. ทำไม NOP

RV32I instruction:

```text
0x00000013
```

decode เป็น:

```assembly
addi x0, x0, 0
```

ไม่มี architectural side effect

ดังนั้น datapath ที่สำคัญที่สุดที่ต้องทำงานคือ:

```text
fetch
decode
PC + 4
next PC
PC register
```

เหมาะกับ first-silicon/full-chip bring-up

---

# 4. Expected Behavior

reset:

```text
PC = 0
```

แต่ละ clock:

```text
PC <- PC + 4
```

ดังนั้น:

```text
PC:
0x00000000
0x00000004
0x00000008
0x0000000C
0x00000010
...
```

observable output:

```text
PC[9:2]
```

จึงเป็น:

```text
00
01
02
03
04
...
```

หลัง release reset แล้ว clock edge แรก:

```text
01
```

---

# 5. ทำไมใช้ PC[9:2]

ถ้า expose:

```text
PC[7:0]
```

จะเห็น:

```text
00,04,08,0C,...
```

ถ้า expose:

```text
PC[9:2]
```

จะเห็น:

```text
00,01,02,03,...
```

อ่านง่ายกว่าใน logic analyzer หรือ FPGA/silicon bring-up

---

# 6. Current CPU Interface

CPU จริง:

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

minimal wrapper ไม่เปลี่ยน CPU core

---

# 7. `chip_core.sv`

instruction:

```systemverilog
localparam logic [31:0] RV32_NOP = 32'h0000_0013;

assign instr = RV32_NOP;
```

data-memory read:

```systemverilog
assign dmem_rdata = 32'h0000_0000;
```

output:

```systemverilog
assign output_o = pc[9:2];
```

---

# 8. CPU Instance

```systemverilog
osoc1_cpu_core u_cpu (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .pc_o         (pc),
    .instr_i      (instr),
    .dmem_we_o    (dmem_we),
    .dmem_addr_o  (dmem_addr),
    .dmem_wdata_o (dmem_wdata),
    .dmem_rdata_i (dmem_rdata)
);
```

นี่คือ CPU จริง

ไม่ใช่ mock core

---

# 9. Expected Data-Memory Behavior

NOP ไม่ควรเขียน memory

ดังนั้น:

```text
dmem_we_o = 0000
```

ทุก cycle

testbench ตรวจ property นี้

---

# 10. Full-Chip Top

top-level:

```text
chip_top
```

ports:

```text
clk_PAD
rst_n_PAD
output_PAD[7:0]
```

และ optional physical supplies:

```text
VDD
VSS
IOVDD
IOVSS
```

ภายใต้:

```systemverilog
`ifdef USE_POWER_PINS
```

---

# 11. Clock Pad

```systemverilog
sg13g2_IOPadIn clk_pad (
    .pad (clk_PAD),
    .p2c (clk_core)
);
```

`p2c`:

```text
pad-to-core
```

---

# 12. Reset Pad

```systemverilog
sg13g2_IOPadIn rst_n_pad (
    .pad (rst_n_PAD),
    .p2c (rst_n_core)
);
```

reset เป็น:

```text
active-low
asynchronous
```

ตาม `pc_reg`

---

# 13. Output Pads

แต่ละ output bit:

```systemverilog
sg13g2_IOPadOut30mA output_pad (
    .c2p (output_core[i]),
    .pad (output_PAD[i])
);
```

`c2p`:

```text
core-to-pad
```

---

# 14. Signal Pad Count

```text
clock      1
reset      1
output     8
----------------
signal    10
```

---

# 15. Power Pad Count

baseline:

```text
VDD       2
VSS       2
IOVDD     2
IOVSS     2
----------------
power     8
```

รวม:

```text
18 pad cells
```

---

# 16. ทำไม 18 Pads เหมาะกับ Minimal Reference

ถ้า expose CPU memory buses ตรงออก package จะต้องใช้ pads มากกว่า 160

minimal NOP chip ลด interface เหลือ:

```text
clock
reset
8 debug outputs
power
```

จึงทำ full-chip integration ได้ง่ายกว่าอย่างมาก

---

# 17. Directory Structure

```text
minimal_nop_fullchip/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_MINIMAL_NOP_FULLCHIP_TH.md
│
├── rtl/
│   ├── chip_core.sv
│   └── chip_top.sv
│
├── sim/
│   └── ihp_io_stubs.v
│
├── tb/
│   ├── tb_chip_core.sv
│   └── tb_chip_top.sv
│
├── config/
│   ├── cpu_source_manifest.txt
│   └── pad_plan.yaml
│
├── constraints/
│   └── chip_top.sdc
│
├── scripts/
│   ├── setup_bondpad.sh
│   ├── check_env.sh
│   ├── check_repo.py
│   ├── check_bondpad.py
│   ├── gen_config.py
│   ├── check_generated_config.py
│   └── build_report.py
│
├── ip/
│   └── bondpad_70x70_novias/
├── build/
└── reports/
```

---

# 18. Recommended Installation

วางใต้ repository:

```text
synpnr_osoc1_cpu/
└── labs/
    └── minimal_nop_fullchip/
```

จากนั้น:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/minimal_nop_fullchip
```

---

# 19. Step 1 — Enter IHP/LibreLane Environment

ตัวอย่าง:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

กลับ:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/minimal_nop_fullchip
```

---

# 20. Step 2 — Environment Check

```bash
make check-env
```

required:

```text
python3
verilator
librelane
```

recommended:

```text
yosys
openroad
klayout
git
```

---

# 21. Step 3 — Verify CPU Source Set

```bash
make REPO_ROOT=../.. check-repo
```

ตรวจ:

```text
14 canonical CPU source files
CPU top exists
required ports exist
SHA-256 fingerprints
```

---

# 22. Canonical CPU Source Set

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

---

# 23. Files Intentionally Excluded

ไม่ใช้:

```text
rf_wb_mux.flat.v
```

เพราะใช้ source RTL:

```text
rf_wb_mux.sv
```

ไม่ใช้ wrapper เก่าของ repo:

```text
src/chip_core.sv
src/chip_top.sv
```

เพราะ package นี้มี minimal wrappers ที่ชัดเจน

---

# 24. Step 4 — Lint Core Wrapper

```bash
make REPO_ROOT=../.. lint-core
```

top:

```text
chip_core
```

ต้องไม่มี fatal errors

---

# 25. Step 5 — Core Simulation

```bash
make REPO_ROOT=../.. sim-core
```

expected:

```text
CORE cycle=1 output=01 ... PASS
CORE cycle=2 output=02 ... PASS
...
CORE cycle=32 output=20 ... PASS

PASS: chip_core NOP smoke test.
```

---

# 26. What Core Test Checks

```text
reset output = 0
PC progresses
observable output increments
dmem_we_o remains 0000
```

---

# 27. Step 6 — Pad-Level RTL Lint

```bash
make REPO_ROOT=../.. lint-top
```

ใช้:

```text
sim/ihp_io_stubs.v
```

เฉพาะ RTL simulation

---

# 28. Simulation I/O Stubs

input:

```systemverilog
assign p2c = pad;
```

output:

```systemverilog
assign pad = c2p;
```

power pads เป็น empty behavioral modules

---

# 29. Critical Rule

`sim/ihp_io_stubs.v`:

```text
ห้ามเข้า LibreLane synthesis
```

physical flow ต้องใช้ IHP PDK cell views จริง

---

# 30. Step 7 — Pad-Level Simulation

```bash
make REPO_ROOT=../.. sim-top
```

expected:

```text
PAD cycle=1 output_PAD=01 PASS
...
PAD cycle=32 output_PAD=20 PASS

PASS: minimal NOP full-chip pad-level smoke test.
```

---

# 31. Why Test Both Core and Top

core simulation isolates:

```text
CPU + minimal wrapper
```

top simulation additionally tests:

```text
clock pad path
reset pad path
output pad path
```

ถ้า top fails แต่ core passes:

```text
debug pad wrapper
```

ไม่ใช่ CPU

---

# 32. SDC

baseline:

```tcl
create_clock \
    -name core_clk \
    -period 20.000 \
    [get_ports clk_PAD]
```

50 MHz

---

# 33. Clock Uncertainty

```tcl
set_clock_uncertainty 0.250 [get_clocks core_clk]
```

---

# 34. Output Delay

```tcl
set_output_delay 4.000 \
    -clock core_clk \
    [get_ports {output_PAD[*]}]
```

---

# 35. Reset Constraint

```tcl
set_false_path -from [get_ports rst_n_PAD]
```

เป็น baseline สำหรับ asynchronous reset input

final design ควร review recovery/removal

---

# 36. Full-Chip Clock Configuration

LibreLane:

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
CLOCK_PERIOD: 20.0
```

แยก:

```text
physical clock port
```

กับ:

```text
internal clock net after pad
```

---

# 37. Slang Frontend

CPU ใช้ SystemVerilog package/type constructs

config จึงเปิด:

```yaml
USE_SLANG: true
```

official IHP template แนะนำ Slang สำหรับ SystemVerilog support ที่ครอบคลุมกว่า

---

# 38. Step 8 — Setup Bondpad

```bash
make setup-bondpad
```

script copy:

```text
bondpad_70x70_novias.lef
bondpad_70x70_novias.gds
```

จาก official IHP template

---

# 39. Why No Fake GDS

GDS เป็น physical layout

fake GDS ทำให้:

```text
DRC
LVS
streamout
geometry checks
```

ให้ผล misleading

ดังนั้น GDS จริงเป็น mandatory สำหรับ physical run

---

# 40. Step 9 — Check Bondpad

```bash
make check-bondpad
```

ต้อง:

```text
LEF macro correct
GDS exists
GDS size non-trivial
SHA-256 recorded
```

---

# 41. Pad Plan

South:

```text
clk
reset
VDD
VSS
```

East:

```text
OUT0
OUT1
OUT2
OUT3
IOVDD
```

North:

```text
OUT7
OUT6
OUT5
OUT4
IOVSS
```

West:

```text
remaining power pads
```

---

# 42. Why `PAD_*` Uses Instance Names

ถูก:

```text
outputs[0].output_pad
```

ผิด:

```text
output_PAD[0]
```

เพราะ PadRing places:

```text
pad cell instances
```

ไม่ใช่ ports

---

# 43. Generate Hierarchy Escaping

LibreLane config ต้อง encode:

```text
outputs\[0\].output_pad
```

generator ทำให้เอง

---

# 44. Step 10 — Generate LibreLane Config

```bash
make REPO_ROOT=../.. gen-config
```

สร้าง:

```text
build/config.yaml
```

---

# 45. Generated Config Core

```yaml
meta:
  version: 3
  flow: Chip

DESIGN_NAME: chip_top

USE_SLANG: true

CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
CLOCK_PERIOD: 20.0
```

---

# 46. Die Baseline

```yaml
DIE_AREA:
  - 0
  - 0
  - 1600
  - 1600
```

หรือ:

```text
1.6 mm × 1.6 mm
```

---

# 47. Core Baseline

```yaml
CORE_AREA:
  - 365
  - 365
  - 1235
  - 1235
```

dimension:

```text
870 µm × 870 µm
```

---

# 48. Placement Density

```yaml
PL_TARGET_DENSITY_PCT: 20
```

conservative สำหรับ first full-chip bring-up

---

# 49. Power Nets

```yaml
VDD_NETS:
  - VDD

GND_NETS:
  - VSS
```

---

# 50. Core Ring

```yaml
PDN_CORE_RING: true
PDN_CORE_RING_CONNECT_TO_PADS: true
```

เพื่อให้ flow พร้อมต่อไป PDN stage

---

# 51. Core Ring Geometry

```text
width = 15 µm
spacing = 5 µm
```

ตาม baseline IHP full-chip template

---

# 52. Step 11 — Config Check

```bash
make REPO_ROOT=../.. check-config
```

ตรวจ:

```text
meta.version
Chip flow
Slang
clock
die/core
pad sides
bondpad
```

---

# 53. Step 12 — Preflight

```bash
make REPO_ROOT=../.. preflight
```

ต้องได้:

```text
MINIMAL NOP FULL-CHIP PREFLIGHT PASS
```

---

# 54. Step 13 — Synthesis Checkpoint

```bash
make REPO_ROOT=../.. synth
```

หยุด:

```text
Yosys.Synthesis
```

---

# 55. Synthesis Pass Criteria

```text
CPU elaborates
IHP I/O cells resolve
no unmapped logic
chip_top exists
mapped standard cells exist
```

---

# 56. Step 14 — PadRing Checkpoint

```bash
make REPO_ROOT=../.. padring
```

หยุด:

```text
OpenROAD.PadRing
```

---

# 57. Why PadRing Is a Good Minimal Checkpoint

ถ้าถึง PadRing:

เราได้พิสูจน์ร่วมกัน:

```text
RTL
SystemVerilog frontend
synthesis
SDC
floorplan
I/O cells
power connection setup
pad instance naming
physical pad placement
```

---

# 58. Inspect PadRing

เปิด ODB/DEF ใน OpenROAD

ตรวจ:

```text
18 pad cells
clock/reset
8 outputs
power pads
core boundary
no overlap
```

---

# 59. Step 15 — Full RTL-to-GDSII

เมื่อ checkpoints stable:

```bash
make REPO_ROOT=../.. full-flow
```

run complete:

```text
synthesis
floorplan
pad ring
PDN
placement
CTS
routing
RCX
STA
GDS
DRC/LVS
```

ตาม enabled Chip-flow steps

---

# 60. Why Full Flow Is Optional in First Bring-Up

สำหรับ debugging:

```text
core sim
top sim
synthesis
PadRing
```

ให้ failure locality ดีกว่า run signoff ทุกครั้ง

---

# 61. Report

```bash
make REPO_ROOT=../.. report
```

output:

```text
reports/MINIMAL_NOP_FULLCHIP_REPORT.md
```

---

# 62. One-Command Baseline

```bash
make REPO_ROOT=../.. all
```

นี่พาไปถึง PadRing

---

# 63. Full One-Command Implementation

```bash
make REPO_ROOT=../.. full-flow
```

หลัง preflight/bondpad พร้อม

---

# 64. Expected RTL Reports

```text
00_environment.log
01_repo_check.txt
04_lint_core.log
05_sim_core.log
06_lint_top.log
07_sim_top.log
```

---

# 65. Expected Physical Reports

```text
02_bondpad_check.txt
03_config_check.txt
08_librelane_synth.log
09_librelane_padring.log
10_librelane_full_flow.log
```

---

# 66. Common Failure — CPU Source Missing

ถ้า:

```text
src/osoc1_cpu_core.sv missing
```

ตรวจ `REPO_ROOT`

เช่น:

```bash
make REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu check-repo
```

---

# 67. Common Failure — Package Parse

ถ้า SystemVerilog package fail:

ตรวจ:

```yaml
USE_SLANG: true
```

และ source order

package ต้องมาก่อน modules ที่ import

---

# 68. Common Failure — Duplicate `rf_wb_mux`

อย่า compile พร้อมกัน:

```text
rf_wb_mux.sv
rf_wb_mux.flat.v
```

ใช้ canonical source set ของ Lab

---

# 69. Common Failure — Wrong CPU Top

CPU top คือ:

```text
osoc1_cpu_core
```

ไม่ใช่:

```text
osoc1_cpu
```

---

# 70. Common Failure — NOP Output Not Incrementing

ตรวจ:

```text
reset
clock
pc_reg
next_pc_logic
instruction encoding
```

NOP encoding ต้อง:

```text
0x00000013
```

---

# 71. Common Failure — Data Memory Write Appears

NOP ไม่ควร store

ถ้า:

```text
dmem_we_o != 0
```

ตรวจ:

```text
decoder
control
LSU
instruction path
```

---

# 72. Common Failure — Pad Module Missing in RTL Simulation

ต้อง include:

```text
sim/ihp_io_stubs.v
```

เฉพาะ simulation

---

# 73. Common Failure — Pad Module Missing in LibreLane

อย่าใส่ stub

ตรวจ IHP PDK:

```text
sg13g2_io
```

library models/views ต้อง resolve

---

# 74. Common Failure — Bondpad Missing

```bash
make setup-bondpad
make check-bondpad
```

---

# 75. Common Failure — Pad Instance Not Found

ตรวจ generate hierarchy:

```text
outputs[0].output_pad
vdd_pads[0].vdd_pad
...
```

และ escaped names ใน generated config

---

# 76. Common Failure — Clock Net Not Found

expected:

```text
clk_pad/p2c
```

แต่หาก hierarchy/front-end version เปลี่ยน ให้ inspect synthesized ODB/netlist

ไม่ควรเดาชื่อใหม่

---

# 77. Common Failure — Output SDC Port Pattern

ถ้า STA frontend ไม่รับ:

```tcl
[get_ports {output_PAD[*]}]
```

ตรวจ tool-resolved port names

อาจใช้:

```text
output_PAD[0]
...
output_PAD[7]
```

explicit list เป็น fallback

---

# 78. Why This Chip Is Not Yet a SoC

minimal NOP full-chip ไม่มี:

```text
firmware memory
data SRAM
bus
GPIO registers
interrupts
SPI
debug
```

มันคือ:

```text
CPU physical bring-up vehicle
```

---

# 79. Why It Is Still Valuable

มันพิสูจน์:

```text
CPU RTL
full-chip wrapper
IHP I/O
clock/reset
pad ring
physical flow
```

โดยไม่มี SoC complexity

---

# 80. Recommended Development Ladder

```text
CPU core
   |
minimal NOP chip
   |
System Bus
   |
ROM/SRAM
   |
GPIO
   |
Timer/Interrupt
   |
SPI Flash
   |
Debug
   |
O'SoC 1.0
```

---

# 81. Pass Criteria — RTL

```text
[ ] CPU source set correct
[ ] chip_core lint PASS
[ ] chip_core simulation PASS
[ ] reset output = 00
[ ] cycles 1..32 = 01..20
[ ] dmem_we = 0000 during NOP
[ ] chip_top lint PASS
[ ] chip_top simulation PASS
```

---

# 82. Pass Criteria — Physical Integration

```text
[ ] real bondpad views ready
[ ] generated Chip config valid
[ ] USE_SLANG enabled
[ ] synthesis completes
[ ] no unmapped logic
[ ] floorplan completes
[ ] PadRing completes
[ ] 18 pads physically accounted for
[ ] clock/reset pads identified
[ ] output pads identified
[ ] power pads identified
```

---

# 83. Full-Flow Pass Criteria

ถ้ารัน `full-flow`:

```text
[ ] PDN generated
[ ] placement legal
[ ] CTS completed
[ ] routing completed
[ ] antenna reviewed
[ ] route DRC reviewed
[ ] post-route STA reviewed
[ ] GDS produced
[ ] DRC/LVS status reviewed
```

---

# 84. Minimal Silicon Bring-Up

fabricated chip test:

```text
1. Apply VDD/VSS
2. Apply IOVDD/IOVSS
3. Assert rst_n_PAD low
4. Apply 50 MHz or slower external clock
5. Release reset
6. Probe output_PAD[7:0]
```

expected:

```text
binary incrementing output
```

---

# 85. Start Slow on Silicon

first bring-up ไม่จำเป็นต้องเริ่ม 50 MHz

ใช้:

```text
100 kHz
1 MHz
10 MHz
```

ก่อน

functional NOP progression independent of clock speed ภายใน supported range

---

# 86. What Output Pattern Proves on Silicon

incrementing outputs prove simultaneously:

```text
package clock path
reset path
I/O supply
core supply
input pad
CPU sequential state
PC datapath
output pad
bond/package observation
```

นี่ทำให้ minimal NOP chip เป็น excellent bring-up structure

---

# 87. What It Does Not Prove

ยังไม่พิสูจน์:

```text
load/store
SRAM
bus
interrupt
SPI
debug
firmware execution
```

จึงต้องมี Labs ต่อไป

---

# 88. Deliverables

```text
rtl/chip_core.sv
rtl/chip_top.sv

sim/ihp_io_stubs.v

tb/tb_chip_core.sv
tb/tb_chip_top.sv

config/cpu_source_manifest.txt
config/pad_plan.yaml

constraints/chip_top.sdc

scripts/setup_bondpad.sh
scripts/check_env.sh
scripts/check_repo.py
scripts/check_bondpad.py
scripts/gen_config.py
scripts/check_generated_config.py
scripts/build_report.py

Makefile
QUICKSTART.sh
README.md
```

---

# 89. Design Review Questions

1. ทำไม NOP เหมาะกับ first full-chip?
2. ทำไม expose `PC[9:2]` แทน `PC[7:0]`?
3. `p2c` และ `c2p` ต่างกันอย่างไร?
4. ทำไม simulation stub ห้ามเข้าสู่ physical flow?
5. ทำไมต้องมีทั้ง VDD/VSS และ IOVDD/IOVSS?
6. ทำไม `CLOCK_PORT` กับ `CLOCK_NET` ต่างกัน?
7. ทำไมใช้ Slang?
8. ทำไม PadRing ต้องใช้ instance names?
9. ทำไมไม่ expose memory bus ทั้งหมด?
10. ถ้า core simulationผ่านแต่ pad-level simulation failควร debug ที่ใดก่อน?

ข้อ 10:

```text
chip_top / I/O wrapper
```

---

# 90. Freeze จาก Minimal Reference

เมื่อผ่านให้ freeze:

```text
CPU top/interface
NOP instruction
reset polarity
clock path
observable output mapping
I/O cell types
power pad strategy
pad hierarchy naming
full-chip top naming
```

---

# 91. Transition สู่ O'SoC

Minimal NOP full-chip เป็น reference implementation

จากนั้น O'SoC integration ควร replace:

```text
instr = constant NOP
```

ด้วย:

```text
instruction memory
```

และ replace:

```text
dmem_rdata = 0
```

ด้วย:

```text
System Bus + SRAM/peripherals
```

---

# 92. Connection to Lab 11

Lab 11 System Bus จึงเป็น natural next layer:

```text
minimal NOP full-chip
       |
       v
CPU data interface
       |
       v
CPU bus adapter
       |
       v
O'SoC System Bus
```

---

# 93. Engineering Rule

> ก่อน integrate SoC ที่มี peripheral หลายตัว ต้องมี full-chip reference ที่ง่ายพอจะ debug ได้ในเวลาไม่นาน

minimal NOP full-chip ทำหน้าที่นั้น

มันเป็น:

```text
known-good physical integration baseline
```

ที่ใช้เปรียบเทียบทุก full-SoC iteration หลังจากนี้
