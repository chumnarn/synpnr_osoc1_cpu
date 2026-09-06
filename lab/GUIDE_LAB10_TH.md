# Lab 10 — GDS and Gate-Level Verification
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Top:** `chip_top`  
**PDK:** IHP SG13G2  
**Clock:** 50 MHz / 20 ns  
**GDS source:** final signoff views  
**GL netlist:** `final/nl/chip_top.nl.v`  
**GL simulator:** Icarus Verilog + cocotb  
**Mandatory:** Functional gate-level verification  
**Optional:** SDF-annotated timing GLS when a compatible SDF is available

---

# 1. จุดประสงค์ของ Lab 10

Lab 9 ตอบว่า:

```text
DRC/LVS/STA/signoff status เป็นอย่างไร?
```

Lab 10 ตอบคำถามอีกชุดหนึ่ง:

```text
ไฟล์ GDS ที่เราจะเก็บ/ส่งสามารถเปิดอ่านได้จริงหรือไม่?
top cell และ geometry สำคัญอยู่ครบหรือไม่?

และ

final gate-level netlist
ยังแสดง functional behavior เดียวกับ RTL architecture หรือไม่?
```

นี่คือ independent verification gate หลัง physical implementation

---

# 2. ทำไมต้องมี Gate-Level Simulation หลัง Signoff

Synthesis/PnR เปลี่ยน representation จาก:

```text
RTL
```

เป็น:

```text
technology-mapped gates
clock buffers
timing-repair buffers
filler/physical implementation state
```

แม้ LVS และ STA จะสำคัญมาก Gate-Level Simulation ยังมีประโยชน์สำหรับ:

```text
reset behavior
top-level pad connectivity
gross functional errors
incorrect final-netlist selection
wrong top-level ports
X/Z propagation
testbench-to-final-view integration
```

---

# 3. แต่ GLS ไม่ได้แทน Formal/LVS/STA

ต้องแยกหน้าที่:

```text
GLS
  -> sample dynamic functional behavior

LVS
  -> prove extracted layout connectivity vs schematic/netlist

STA
  -> exhaustively analyze constrained timing paths

DRC
  -> manufacturing geometry rules
```

ดังนั้น:

> GLS PASS ไม่ได้ทำให้ DRC/LVS/STA failures หายไป

---

# 4. Official IHP Template Workflow

official IHP SG13G2 LibreLane template ปัจจุบันมี flow:

```text
make librelane
      |
      v
--save-views-to final/
      |
      v
make sim-gl
```

GLS ใช้ final implementation views

ไม่ใช่ synthesized intermediate netlist

---

# 5. Final View Directory

Lab ใช้:

```text
build/final/
```

default

หรือระบุ external:

```bash
FINAL_DIR=/path/to/final
```

---

# 6. Mandatory Final Views

Lab ต้องมีอย่างน้อย:

```text
final/
├── nl/
│   └── chip_top.nl.v
└── gds/
    └── chip_top.gds
```

หรือ:

```text
chip_top.gds.gz
```

---

# 7. ทำไมใช้ `nl/chip_top.nl.v`

official IHP template gate-level testbench ปัจจุบันระบุว่า:

```text
We use the unpowered netlist
```

และโหลด:

```text
final/nl/chip_top.nl.v
```

พร้อม:

```text
USE_POWER_PINS = false
```

Lab ใช้ strategy เดียวกัน

---

# 8. Powered vs Unpowered Netlist

unpowered final netlist:

```text
logic connectivity
technology cells
no explicit simulation driving of VDD/VSS top-level supplies
```

เหมาะกับ functional GLS

ส่วน powered netlist อาจเหมาะกับ:

```text
power-aware verification
UPF-style flows
power connectivity debugging
```

แต่ complexity สูงกว่า

---

# 9. GLS Library Models

official source-set:

```text
sg13g2_stdcell.v
sg13g2_udp.v
chip_top.nl.v
sg13g2_io.v
```

Lab ใช้ exact categories นี้

---

# 10. ห้ามใช้ Simulation I/O Stubs จาก Lab 4

Lab 4 มี:

```text
sim/ihp_io_stubs.v
```

เพื่อให้ RTL pad simulation ง่าย

แต่ Gate-Level Simulation ต้องใช้:

```text
PDK-provided sg13g2_io.v
```

เพราะ final netlist instantiate I/O cells จริง

กฎ:

> RTL behavioral stub ไม่ใช่ signoff/GLS cell model

---

# 11. CPU Architectural Reference

Lab 4 freeze behavior:

```systemverilog
assign instr = 32'h0000_0013;
```

คือ RISC-V:

```assembly
addi x0, x0, 0
```

NOP

---

# 12. Expected PC

ทุก instruction cycle:

```text
PC <- PC + 4
```

จึง:

```text
0x00000000
0x00000004
0x00000008
0x0000000c
...
```

---

# 13. Expected Observable Output

wrapper:

```systemverilog
assign output_out = pc[9:2];
```

ดังนั้น:

```text
PC       PC[9:2]
0x0000      00
0x0004      01
0x0008      02
0x000c      03
0x0010      04
```

นี่เป็น golden architectural property ของ Lab 10

---

# 14. Verification Strategy

```text
Final GDS
  |
  +--> file integrity
  +--> SHA-256
  +--> KLayout parser
  +--> top-cell existence
  +--> visual inspection

Final gate netlist
  |
  +--> compile with real IHP Verilog cell models
  +--> reset
  +--> apply 50 MHz clock
  +--> observe output_PAD
  +--> compare 32 cycles with expected PC[9:2]
```

---

# 15. Directory Structure

```text
lab10_gds_gate_level_verification/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB10_TH.md
│
├── rtl/
├── constraints/
├── ip/
│
├── config/
│   ├── cpu_source_manifest.txt
│   ├── pad_plan.yaml
│   ├── pdn_plan.yaml
│   ├── placement_cts_plan.yaml
│   ├── routing_plan.yaml
│   ├── signoff_plan.yaml
│   └── gls_plan.yaml
│
├── cocotb/
│   └── chip_top_gl_tb.py
│
├── scripts/
│   ├── setup_bondpad.sh
│   ├── check_env.sh
│   ├── check_gls_plan.py
│   ├── check_pdk_gl_models.py
│   ├── check_final_views.py
│   ├── find_final_view.py
│   ├── gds_file_check.py
│   ├── gds_inspect.py
│   ├── gls_source_check.py
│   ├── check_gls_log.py
│   ├── compare_rtl_gl.py
│   ├── sdf_discovery.py
│   ├── release_verify_manifest.py
│   └── build_report.py
│
├── build/
├── reports/
└── results/
    └── GDS_GLS_CHECKLIST.md
```

---

# 16. Step 1 — Enter Environment

ตัวอย่าง:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

แล้ว:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab10_gds_gate_level_verification
```

---

# 17. Step 2 — Environment Check

```bash
make check-env
```

required:

```text
python3
librelane
```

recommended:

```text
iverilog
vvp
klayout
gtkwave
```

---

# 18. Cocotb Requirement

GLS runner ใช้:

```python
from cocotb_tools.runner import get_runner
```

ดังนั้น Python environment ต้องมี cocotb version ที่มากับ template/Nix environment

ตรวจ:

```bash
python3 -c "import cocotb; print(cocotb.__version__)"
```

---

# 19. Step 3 — Check GLS Plan

```bash
make check-gls-plan
```

baseline:

```yaml
TOP: chip_top
CLOCK_FREQ_MHZ: 50
RESET_TIME_NS: 100
OBSERVE_CYCLES: 32
GL_NETLIST_RELATIVE: nl/chip_top.nl.v
SIM: icarus
ENABLE_SDF: false
```

---

# 20. Step 4 — Check IHP Models

```bash
make check-pdk-models
```

must find:

```text
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog/sg13g2_udp.v
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_io/verilog/sg13g2_io.v
```

---

# 21. PDK Root

default:

```bash
PDK_ROOT=$HOME/.ciel
```

ถ้า environment อื่น:

```bash
make \
  PDK_ROOT=/path/to/pdk-root \
  check-pdk-models
```

---

# 22. Step 5 — Preflight

```bash
make preflight
```

รวม:

```text
environment
GLS plan
PDK models
bondpad
full implementation config
```

---

# 23. Method A — Build New Final Views

ถ้าต้องการ reproduce design ทั้งหมด:

```bash
make build-final
```

command concept:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --save-views-to build/final \
  build/config.yaml
```

นี่เป็น method ที่ reproducible สูงสุด

---

# 24. Why `--save-views-to`

official template ใช้:

```text
--save-views-to final/
```

เพื่อสร้าง stable final-view directory แยกจาก timestamp run directory

Lab ใช้ concept เดียวกัน

---

# 25. Method B — Verify Existing Final Views

ถ้ามี final directory อยู่แล้ว:

```bash
make \
  FINAL_DIR=/absolute/path/to/final \
  verify-existing
```

ไม่ต้อง rerun PnR

---

# 26. Step 6 — Check Final Views

```bash
make check-final
```

mandatory:

```text
gate netlist
GDS
```

optional/warn if layout differs by version:

```text
DEF
LEF
SDC
SPEF
```

---

# 27. Do Not Guess Final Netlist

Lab ไม่ search random `.v` แล้วใช้ไฟล์แรก

canonical GLS input:

```text
final/nl/chip_top.nl.v
```

ถ้าไม่มี:

```text
FAIL
```

เพราะ artifact export ไม่ครบ

---

# 28. Step 7 — GDS File Integrity

```bash
make gds-file-check
```

ตรวจ:

```text
exists
non-trivial size
SHA-256
gzip readability if .gz
```

---

# 29. Why Hash GDS

GDS เป็น release artifact

hash ช่วย verify:

```text
file ที่ simulate/report/reference
สัมพันธ์กับ release revision เดียวกันหรือไม่
```

---

# 30. Step 8 — Parse GDS with KLayout

```bash
make gds-inspect
```

KLayout batch command:

```text
klayout -b -r scripts/gds_inspect.py
```

script อ่าน GDS จริง

---

# 31. KLayout GDS Check

ตรวจ:

```text
GDS parse succeeds
top cells
chip_top exists
bounding box
layer count
instance count
```

---

# 32. Why Parser Check Is Stronger than File Size

ไฟล์ขนาดใหญ่ยังอาจ:

```text
corrupt
truncated
wrong top
wrong design
```

KLayout parse เป็น stronger sanity check

---

# 33. Step 9 — Visual GDS Inspection

automation ไม่แทน visual signoff

เปิด final GDS:

```bash
klayout <final-gds>
```

---

# 34. Visual Checklist — Die

ตรวจ:

```text
die outline
expected 1.6 mm × 1.6 mm baseline
```

ระวัง database units/streamout scaling

---

# 35. Visual Checklist — Pad Ring

ต้องเห็น:

```text
clock pad
reset pad
8 output pads
VDD/VSS pads
IOVDD/IOVSS pads
bondpads
```

---

# 36. Visual Checklist — Core

ต้องเห็น:

```text
standard-cell core
PDN
routing
clock-tree cells
filler
```

---

# 37. Visual Checklist — Bondpads

bondpad physical macro ต้อง:

```text
มีจริง
วางถูกด้าน
ไม่หายจาก streamout
```

---

# 38. Visual Checklist — Routing

zoom:

```text
clock
reset
one output net
power approach
```

เพื่อ confirm gross geometry

---

# 39. Step 10 — GLS Source Check

```bash
make gls-source-check
```

ต้องมี:

```text
sg13g2_stdcell.v
sg13g2_udp.v
chip_top.nl.v
sg13g2_io.v
```

---

# 40. Why UDP Model

standard-cell Verilog models อาจใช้:

```text
UDP
User Defined Primitive
```

จึงต้อง compile:

```text
sg13g2_udp.v
```

ด้วย

---

# 41. Step 11 — Run Gate-Level Simulation

```bash
make gls
```

runner ใช้:

```text
Icarus Verilog
+
cocotb
```

---

# 42. GLS Compile Definition

runner ใช้:

```python
defines={"USE_POWER_PINS": False}
```

เพื่อ match unpowered final netlist strategy

---

# 43. Test Sequence

```text
1. drive rst_n_PAD low
2. confirm output_PAD = 0
3. start 50 MHz clock
4. hold reset 100 ns
5. release reset
6. sample after each rising edge
7. verify 32 cycles
```

---

# 44. Why Sample 1 ns After Edge

GL netlist simulation มี:

```text
delta-cycle/event scheduling
primitive propagation
```

sampling เล็กน้อยหลัง edge ลด race ambiguity ของ testbench

ไม่ได้จำลอง real analog propagation delay

---

# 45. Expected GLS Output

conceptually:

```text
GLS cycle=1 output_PAD=0x01 PASS
GLS cycle=2 output_PAD=0x02 PASS
GLS cycle=3 output_PAD=0x03 PASS
...
GLS cycle=32 output_PAD=0x20 PASS
```

final:

```text
PASS: gate-level chip_top preserves NOP PC[9:2] behavior.
```

---

# 46. What This Proves

ถ้า GLS PASS:

```text
final gate netlist compiles
IHP cell models resolve
chip top resolves
clock/reset pad connectivity works functionally
CPU state evolves
output pads expose expected PC behavior
```

---

# 47. What This Does Not Prove

GLS functional pass ไม่ได้พิสูจน์:

```text
timing at all corners
DRC
LVS
IR drop
EM
analog I/O quality
ESD behavior
```

เหล่านี้ต้องอาศัย Lab 9/signoff tools

---

# 48. Step 12 — Check GLS Result

```bash
make check-gls
```

script ต้องพบ exact PASS signature

และไม่มี fatal/assertion patterns

---

# 49. Step 13 — Compare RTL Intent to GL Samples

```bash
make compare
```

script parse:

```text
GLS cycle=N output_PAD=...
```

แล้วตรวจ:

```text
output == N mod 256
```

สำหรับทุก sample

---

# 50. Why Compare Script

testbench มี assertion อยู่แล้ว

แต่ independent report parser ช่วย:

```text
course report
CI artifact
traceability
```

---

# 51. Waveform

official IHP template GLS สร้าง waveform ผ่าน cocotb runner

Lab runner เปิด:

```python
waves=True
```

ตำแหน่ง simulator-dependent อยู่ใต้:

```text
cocotb/sim_build/
```

---

# 52. View Waveform

ถ้าได้ FST/VCD:

```bash
gtkwave cocotb/sim_build/<waveform>
```

หรือใช้ Surfer ถ้ามี

---

# 53. Signals to Inspect

อย่างน้อย:

```text
clk_PAD
rst_n_PAD
output_PAD[7:0]
```

internal gate names อาจ optimize/rename

อย่าพึ่ง internal RTL hierarchy ใน final GL netlist

---

# 54. X/Z Detection

หลัง reset release:

```text
output_PAD
```

ไม่ควรเป็น:

```text
X
Z
```

ถ้ามี:

ตรวจ:

```text
I/O model
reset
cell model
uninitialized sequential state
netlist port direction
```

---

# 55. Troubleshooting — Missing `chip_top.nl.v`

อาการ:

```text
final/nl/chip_top.nl.v not found
```

แก้:

```bash
make build-final
```

หรือใช้ final views จาก successful implementation ที่ export ด้วย:

```text
--save-views-to
```

---

# 56. Troubleshooting — Missing Stdcell Model

ตรวจ:

```bash
ls \
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_stdcell/verilog
```

ต้องพบ:

```text
sg13g2_stdcell.v
sg13g2_udp.v
```

---

# 57. Troubleshooting — Missing IO Model

ตรวจ:

```bash
ls \
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_io/verilog
```

ต้องมี:

```text
sg13g2_io.v
```

---

# 58. Troubleshooting — Unknown Standard Cell

ถ้า Icarus บอก:

```text
Unknown module sg13g2_...
```

ตรวจว่า:

```text
final netlist target library
ตรงกับ loaded PDK model
```

อย่าเพิ่ม random blackboxes เพื่อ force simulation pass

---

# 59. Troubleshooting — Unknown IO Cell

ถ้า:

```text
sg13g2_IOPadIn not found
```

ต้องใช้:

```text
sg13g2_io.v
```

ไม่ใช่ Lab-4 stub

---

# 60. Troubleshooting — Power Pins

baseline ใช้ unpowered netlist

ถ้า final netlist มี explicit:

```text
VDD
VSS
IOVDD
IOVSS
```

ใน top signature อย่างไม่ตรง runner:

ตรวจว่าคุณเลือก:

```text
nl
```

หรือ:

```text
pnl
```

ผิด view

สำหรับ baseline official-template strategy ใช้:

```text
nl/chip_top.nl.v
```

---

# 61. Troubleshooting — Output Stuck at 0

check:

```text
clock toggles
reset deasserts
input pad model propagates
clock path exists
```

เปิด waveform

---

# 62. Troubleshooting — Output Increments by 4

ถ้าได้:

```text
04 08 0c...
```

อาจกำลัง observe raw:

```text
PC[7:0]
```

ไม่ใช่ wrapper output:

```text
PC[9:2]
```

ตรวจ final netlist provenance

---

# 63. Troubleshooting — First Sample Off by One

ตรวจ reset/clock ordering

GLS testbench sampling phaseสำคัญ

baseline:

```text
release reset
then count rising edges
sample 1ns after edge
```

---

# 64. Troubleshooting — Test Runs but No Waveform

ตรวจ cocotb runner/simulator version

functional PASS ยัง valid

แต่ workshop deliverable ควรบันทึก simulator/log ก่อน

---

# 65. Gate-Level Simulation Types

มีอย่างน้อย:

```text
zero-delay / unit functional GLS
timing-annotated GLS
```

Lab baseline คือ functional GLS

---

# 66. Functional GLS

cell models ให้ logical function

interconnect/cell timing ไม่จำเป็นต้อง represent signoff delay

เหมาะกับ:

```text
functional connectivity
reset
pad integration
gross netlist behavior
```

---

# 67. Timing GLS

ใช้:

```text
SDF
+
timing-aware cell models
```

สามารถจับ:

```text
timing checks
delayed events
reset races
some timing-dependent behavior
```

แต่ setup ยุ่งยากกว่า

---

# 68. SDF Discovery

รัน:

```bash
make sdf-discovery
```

ค้น:

```text
*.sdf
*.sdf.gz
```

ใน:

```text
FINAL_DIR
Lab
repository
```

---

# 69. No SDF Is Not Baseline Failure

LibreLane signoff timing authority ของ Lab นี้คือ:

```text
OpenROAD RCX
+
multi-corner STA
```

ดังนั้นไม่มี SDF:

```text
ไม่ได้ทำให้ functional GLS fail
```

---

# 70. Why STA Remains Primary Timing Signoff

STA:

```text
วิเคราะห์ timing paths ทั้งหมดตาม constraints
```

Timing GLS:

```text
วิเคราะห์เฉพาะ paths/events ที่ testbench exercise
```

ดังนั้น timing GLS เสริม STA ไม่แทน STA

---

# 71. If SDF Is Available

ก่อนใช้ต้องยืนยัน:

```text
hierarchy
instance names
cell models
timescale
corner
simulator SDF support
```

---

# 72. Do Not Annotate Wrong Corner

SDF อาจ represent:

```text
min
typ
max
```

ต้องระบุชัดว่า simulation ใช้ corner ใด

---

# 73. KLayout GDS Inspection vs DRC

`make gds-inspect` ตรวจ:

```text
readability
top
bbox
hierarchy
```

ไม่ใช่ DRC

DRC ยังอาศัย Lab 9 signoff

---

# 74. GDS Top-Cell Error

ถ้า KLayout parse ได้ แต่:

```text
chip_top missing
```

ถือว่า fail

อาจใช้ wrong GDS หรือ wrong export

---

# 75. GDS BBox

bbox สามารถใช้ sanity-check scaling

die baseline:

```text
1600 µm × 1600 µm
```

ต้องแปลงจาก database units ก่อนสรุป exact dimension

---

# 76. GDS Layer Count

layer count เป็น sanity metric

จำนวนไม่ควรถูก hard-code เพราะ:

```text
PDK revision
fill
labels
streamout
```

อาจเปลี่ยน

---

# 77. Final View Manifest

รัน:

```bash
make manifest
```

สร้าง:

```text
results/VERIFIED_VIEW_MANIFEST.md
```

ประกอบด้วย:

```text
path
size
SHA-256
```

ของ final views

---

# 78. Why Manifest after Verification

ต้อง hash:

```text
artifact ที่ verify แล้ว
```

ไม่ใช่ hash intermediate ก่อนแก้ flow แล้ว reuse

---

# 79. Report Generation

```bash
make report
```

สร้าง:

```text
reports/LAB10_REPORT.md
```

---

# 80. Recommended New-Build Sequence

```bash
make clean
make preflight
make build-final

make check-final

make gds-file-check
make gds-inspect

make gls
make check-gls
make compare

make sdf-discovery
make manifest
make report
```

---

# 81. One Command

```bash
make all
```

ใช้เมื่อ flow stable แล้ว

---

# 82. Existing-Final Sequence

ถ้า Lab 9 หรือ official IHP-style build มี final views:

```bash
make \
  FINAL_DIR=/absolute/path/to/final \
  verify-existing
```

---

# 83. GDS Pass Criteria

```text
[ ] GDS exists
[ ] non-trivial size
[ ] SHA-256 recorded
[ ] gzip valid if compressed
[ ] KLayout reads successfully
[ ] chip_top exists
[ ] visual die check passes
[ ] pad ring visible
[ ] bondpads visible
[ ] routing/core/PDN visible
```

---

# 84. GLS Pass Criteria

```text
[ ] final/nl/chip_top.nl.v exists
[ ] standard-cell model exists
[ ] UDP model exists
[ ] I/O model exists
[ ] Icarus build succeeds
[ ] cocotb test starts
[ ] reset output = 0
[ ] output sequence 01..20 observed
[ ] 32 cycles pass
[ ] no X/Z after reset
[ ] PASS signature recorded
```

---

# 85. Combined Lab Pass

Lab 10 ผ่านเมื่อ:

```text
GDS integrity PASS
+
GDS visual review PASS
+
functional GLS PASS
+
Lab-9 timing/LVS/DRC status reviewed
```

---

# 86. Important: GL Netlist Is Not GDS

GLS ใช้:

```text
netlist
```

ไม่ใช่ simulation จาก polygon GDS โดยตรง

ความสัมพันธ์:

```text
GDS
 <- proved against netlist by LVS

netlist
 <- dynamically tested by GLS
```

นี่คือ verification triangle ที่สำคัญ

---

# 87. Verification Triangle

```text
             RTL intent
              /     \
             /       \
          GLS         synthesis/equivalence
           |                 |
           v                 v
      final netlist ------ implementation
           |
          LVS
           |
           v
          GDS
```

---

# 88. Why LVS Is Essential to Connect GLS to GDS

GLS พิสูจน์ final netlist behavior

แต่ถ้าไม่มี LVS:

```text
ยังไม่พิสูจน์ว่า GDS connectivity = final netlist
```

ดังนั้น Lab 9 LVS เป็น bridge ระหว่าง Lab 10 GLS กับ GDS

---

# 89. Why DRC Is Still Essential

GDS อาจ electrically match netlist แต่ geometry manufacture ไม่ได้

LVS pass แต่ DRC fail:

```text
ยังไม่พร้อม tapeout
```

---

# 90. Suggested Workshop Exercise — Corrupt Netlist

สำเนา netlist แล้วเปลี่ยน connection หนึ่งจุด

ดู GLS fail

ห้ามแก้ final artifact จริง

ใช้ sandbox copy เท่านั้น

objective:

```text
เข้าใจ sensitivity ของ dynamic verification
```

---

# 91. Suggested Exercise — Wrong IO Model

ลอง remove:

```text
sg13g2_io.v
```

ดู compile failure

เรียนรู้ว่า pad models เป็น part of GLS environment

---

# 92. Suggested Exercise — Wrong Final View

ชี้ FINAL_DIR ไป run เก่า

ใช้ hash/Git report เพื่อ detect provenance mismatch

---

# 93. Suggested Exercise — 100 MHz Functional GLS

functional zero-delay GLS ที่ 100 MHz อาจยังผ่าน

ห้ามสรุปว่า physical design timing ผ่าน 100 MHz

เพราะ timing qualification ต้องมาจาก STA

นี่เป็น teaching point ที่สำคัญมาก

---

# 94. Functional Frequency Trap

ถ้า zero-delay GLS ผ่าน:

```text
500 MHz
```

ไม่ได้แปลว่า silicon ทำได้ 500 MHz

เพราะ propagation delays ไม่ได้ถูก model อย่าง signoff-realistic

---

# 95. GDS Verification Checklist

Lab มี:

```text
results/GDS_GLS_CHECKLIST.md
```

ให้ผู้เรียนเติมจริง

---

# 96. Evidence Package

หลัง Lab ควร archive:

```text
final GDS
final NL netlist
GDS hash
GLS log
waveform
KLayout inspection report
Lab 9 DRC/LVS/STA reports
verified-view manifest
LAB10_REPORT.md
```

---

# 97. Report Status Vocabulary

ใช้เพียง:

```text
PASS
FAIL
WAIVED
NOT RUN
```

อย่าใช้:

```text
probably okay
looks fine
```

ใน release report

---

# 98. Advanced Extension — SDF GLS

เมื่อมี compatible SDF:

```text
final gate netlist
+
cell timing models
+
SDF annotation
+
same NOP test
```

จากนั้น compare:

```text
functional result
event timing
warnings
timing checks
```

---

# 99. Advanced Extension — GLS Regression

เพิ่ม test:

```text
reset repeatedly
run 255+ cycles
check output wrap
assert no memory writes
test asynchronous reset during execution
```

---

# 100. Advanced Extension — Silicon Bring-Up Mapping

GLS expected pattern:

```text
output_PAD = incrementing binary counter
```

สามารถนำไปเป็น silicon bring-up plan:

```text
clock source
reset button/generator
logic analyzer on 8 outputs
```

จึงเชื่อม verification กับ lab characterization จริงได้

---

# 101. Final Engineering Rule

> GDS คือ physical artifact, gate netlist คือ logical artifact และ GLS คือ dynamic experiment

ต้องใช้:

```text
LVS
```

เชื่อม physical กับ logical

และใช้:

```text
STA
```

พิสูจน์ timing อย่าง exhaustive ตาม constraints

ดังนั้น Lab 10 ไม่ได้แทน Lab 9

แต่ทำให้ release package มี independent functional evidence เพิ่มขึ้น

---

# 102. Transition หลัง Lab 10

หลัง Lab 10 เหมาะเข้าสู่:

```text
Lab 11 — Package, Bond Plan and Silicon Bring-Up
```

ซึ่งจะ map:

```text
clk_PAD
rst_n_PAD
output_PAD[7:0]
VDD/VSS
IOVDD/IOVSS
```

ไปยัง package pins/bond wires/test board และกำหนด bring-up sequence สำหรับ fabricated chip
