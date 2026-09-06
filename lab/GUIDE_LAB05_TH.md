# Lab 5 — IHP SG13G2 Pad Ring
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane `Chip` Flow

**Top:** `chip_top`  
**Core:** `chip_core`  
**CPU:** `osoc1_cpu_core`  
**PDK:** IHP SG13G2  
**Flow:** LibreLane `Chip`  
**Lab endpoint:** `OpenROAD.PadRing`  
**Die baseline:** 1600 µm × 1600 µm  
**Core baseline:** 870 µm × 870 µm

---

# 1. Lab 5 ทำอะไร

Lab 4 พิสูจน์ว่า digital connectivity ต่อไปนี้ทำงาน:

```text
package clock
   |
input-pad model
   |
chip_core
   |
CPU
   |
PC[9:2]
   |
output-pad model
   |
package outputs
```

แต่ simulation ยังไม่มี physical location

Lab 5 เปลี่ยนจาก:

```text
logical I/O hierarchy
```

เป็น:

```text
physical I/O ring
```

ด้วย LibreLane `Chip` flow

---

# 2. จุดสิ้นสุดของ Lab

Lab นี้ตั้งใจหยุดที่:

```text
OpenROAD.PadRing
```

ยังไม่ทำ:

```text
placement
CTS
routing
signoff
```

เหตุผลคือ pad-ring failure ต้องถูก isolate ก่อนเพิ่ม PDN/placement complexity

---

# 3. Chip Flow ลำดับที่เกี่ยวข้อง

LibreLane `Chip` flow ปัจจุบันมีลำดับสำคัญ:

```text
Verilator.Lint
Yosys.Synthesis
Checker.YosysUnmappedCells
OpenROAD.CheckSDCFiles
OpenROAD.STAPrePNR
OpenROAD.Floorplan
Odb.SetPowerConnections
OpenROAD.PadRing
...
```

ดังนั้นคำสั่ง:

```bash
--to OpenROAD.PadRing
```

เป็น checkpoint ที่เหมาะสมสำหรับ Lab นี้

---

# 4. Pad Ring ไม่ใช่ I/O Pin Placement

ต้องแยก:

```text
I/O pin placement
```

กับ:

```text
pad-cell placement
```

ใน full-chip ASIC เรามี physical pad cells เช่น:

```text
sg13g2_IOPadIn
sg13g2_IOPadOut30mA
sg13g2_IOPadVdd
```

LibreLane `OpenROAD.PadRing` จัดวาง **instances เหล่านี้**

ไม่ใช่แค่สร้าง abstract core-edge pins

---

# 5. Pad Instances ของ Lab 4

signal pads:

```text
clk_pad
rst_n_pad

outputs[0].output_pad
...
outputs[7].output_pad
```

core power:

```text
vdd_pads[0].vdd_pad
vdd_pads[1].vdd_pad

vss_pads[0].vss_pad
vss_pads[1].vss_pad
```

I/O power:

```text
iovdd_pads[0].iovdd_pad
iovdd_pads[1].iovdd_pad

iovss_pads[0].iovss_pad
iovss_pads[1].iovss_pad
```

รวม:

```text
10 signal pads
8 power pads
--------------
18 pad cells
```

---

# 6. ทำไม `PAD_*` ใช้ Instance Names

ผิด:

```yaml
PAD_NORTH:
  - output_PAD[0]
```

เพราะ:

```text
output_PAD[0]
```

เป็น top-level net/port

ถูก:

```yaml
PAD_NORTH:
  - "outputs\\[0\\].output_pad"
```

เพราะนี่เป็น pad-cell instance หลัง elaboration

---

# 7. Generate-Block Escaping

SystemVerilog hierarchy:

```text
outputs[0].output_pad
```

แต่ใน LibreLane config official template escape brackets เป็น:

```text
outputs\[0\].output_pad
```

เมื่อเขียน YAML string จะเห็น:

```yaml
"outputs\\[0\\].output_pad"
```

generator ของ Lab ทำ escaping ให้อัตโนมัติ

ผู้เรียนจึงแก้ logical plan ที่:

```text
config/pad_plan.yaml
```

โดยใช้ชื่อธรรมดา:

```text
outputs[0].output_pad
```

---

# 8. Pad Plan ของ Lab

```yaml
PAD_SOUTH:
  - clk_pad
  - rst_n_pad
  - vdd_pads[0].vdd_pad
  - vss_pads[0].vss_pad

PAD_EAST:
  - outputs[0].output_pad
  - outputs[1].output_pad
  - outputs[2].output_pad
  - outputs[3].output_pad
  - iovdd_pads[0].iovdd_pad

PAD_NORTH:
  - outputs[7].output_pad
  - outputs[6].output_pad
  - outputs[5].output_pad
  - outputs[4].output_pad
  - iovss_pads[0].iovss_pad

PAD_WEST:
  - vdd_pads[1].vdd_pad
  - vss_pads[1].vss_pad
  - iovdd_pads[1].iovdd_pad
  - iovss_pads[1].iovss_pad
```

---

# 9. เหตุผลของการจัดด้าน

South:

```text
clock
reset
core VDD/VSS
```

ทำให้ clock/reset อยู่ใกล้กันและ debug ง่าย

East + North:

```text
8-bit observable bus
```

แบ่งเป็น nibble ละ 4 bits

West และ pad ที่เหลือ:

```text
power-domain support
```

นี่เป็น teaching baseline ไม่ใช่ package-optimized final arrangement

---

# 10. Pad Placement ต้องคิดร่วมกับ Package

ใน final chip ต้องพิจารณา:

```text
bond-wire crossing
package pin numbering
board connector
power return
SSO
clock isolation
ESD current path
```

Lab 5 ยังไม่ optimize package

เป้าหมายคือสร้าง legal/reproducible physical pad ring ก่อน

---

# 11. Die Area

ใช้ baseline จาก official IHP template:

```yaml
DIE_AREA:
  - 0
  - 0
  - 1600
  - 1600
```

ขนาด:

```text
1600 µm × 1600 µm
```

หรือ:

```text
1.6 mm × 1.6 mm
```

---

# 12. Core Area

```yaml
CORE_AREA:
  - 365
  - 365
  - 1235
  - 1235
```

dimension:

```text
1235 - 365 = 870 µm
```

จึงได้:

```text
870 µm × 870 µm
```

---

# 13. ทำไม Core Margin ใหญ่

ระหว่าง die edge กับ core:

```text
365 µm
```

baseline นี้ต้องมีพื้นที่สำหรับ:

```text
I/O pad cells
bondpads
power routing
core ring
routing transition
```

full-chip floorplan ไม่สามารถใช้ core margin แบบ core-only design ได้

---

# 14. Step 1 — ติดตั้ง Lab

แนะนำ:

```text
synpnr_osoc1_cpu/
└── labs/
    └── lab05_ihp_sg13g2_pad_ring/
```

เข้า:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab05_ihp_sg13g2_pad_ring
```

---

# 15. Step 2 — เข้า LibreLane/IHP Environment

Lab ต้องมี:

```text
librelane
yosys
OpenROAD
IHP SG13G2 PDK
```

ถ้าใช้ official IHP template:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

กลับ Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab05_ihp_sg13g2_pad_ring
```

---

# 16. Step 3 — ตรวจ Environment

```bash
make check-env
```

ต้องได้:

```text
PASS required python3
PASS required verilator
PASS required yosys
PASS required librelane
```

ถ้า OpenROAD พบด้วยยิ่งดี:

```text
PASS optional openroad
```

---

# 17. Bondpad Physical IP

official IHP template ใช้:

```text
bondpad_70x70_novias
```

ขนาด:

```text
70 µm × 70 µm
```

โดยระบุเป็น:

```yaml
PAD_BONDPAD_NAME: bondpad_70x70_novias
```

และเพิ่ม physical views ผ่าน:

```yaml
EXTRA_GDS:
EXTRA_LEFS:
```

---

# 18. ทำไม Lab ไม่สร้าง Fake Bondpad GDS

GDS เป็น physical mask-layout database

การสร้าง placeholder GDS แล้วใช้ต่อใน flow อาจทำให้:

```text
geometry ผิด
layer ผิด
pin shape ผิด
DRC/LVS misleading
```

Lab จึงบังคับใช้ official asset จริง

---

# 19. Step 4 — Setup Bondpad

รัน:

```bash
make setup-bondpad
```

script จะค้น:

```text
$IHPP_TEMPLATE_ROOT
~/workshop/ihp-sg13g2-librelane-template
~/ihp-sg13g2-librelane-template
~/psu/ihp-sg13g2-librelane-template
```

หากไม่พบจะลอง:

```bash
git clone --depth 1 \
  https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template.git
```

แล้ว copy:

```text
ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds
ip/bondpad_70x70_novias/lef/bondpad_70x70_novias.lef
```

---

# 20. Offline Setup

ถ้าเครื่อง Lab ไม่มี Internet แต่มี official template ที่อื่น:

```bash
IHP_TEMPLATE_ROOT=/path/to/ihp-sg13g2-librelane-template \
make setup-bondpad
```

หรือ copy files ด้วยตนเอง

---

# 21. Step 5 — Verify Bondpad

```bash
make check-bondpad
```

ตรวจ:

```text
LEF exists
macro name correct
70x70 size
GDS exists
GDS > 1 KB
SHA256 recorded
```

expected:

```text
PASS: real bondpad LEF/GDS assets are present.
```

---

# 22. Step 6 — Enumerate Expected Pad Instances

```bash
make expected-pads
```

สร้าง:

```text
reports/01_expected_pad_instances.txt
```

ต้องได้ 18 instances

นี่เป็น source-of-truth list ที่ pad plan ต้อง cover ครบ

---

# 23. Step 7 — Validate Pad Plan

```bash
make check-pad-plan
```

script ตรวจ:

```text
exactly four sides
every expected pad appears
no pad duplicated
no unknown pad
```

expected:

```text
Expected pads: 18
Listed pads  : 18

PASS: every Lab-4 pad instance appears exactly once in pad plan.
```

---

# 24. ทำไมต้อง Validate ก่อน LibreLane

ถ้า pad instance สะกดผิดเพียงตัวเดียว เช่น:

```text
output[0].output_pad
```

แทน:

```text
outputs[0].output_pad
```

PadRing จะ fail หลังผ่าน synthesis/floorplan หลายขั้น

preflight script จับ error นี้ในไม่กี่วินาที

---

# 25. Step 8 — Generate LibreLane Chip Config

```bash
make gen-config
```

สร้าง:

```text
build/config.yaml
```

generator ใช้ absolute paths สำหรับ:

```text
CPU RTL
chip_core.sv
chip_top.sv
SDC
bondpad LEF
bondpad GDS
```

จึงย้าย Lab ได้โดยไม่แก้ YAML path ด้วยมือ

---

# 26. Core of Generated Config

```yaml
meta:
  version: 3
  flow: Chip

DESIGN_NAME: chip_top
```

RTL:

```yaml
VERILOG_FILES:
  - .../cpu_sv_package.sv
  ...
  - .../osoc1_cpu_core.sv
  - .../rtl/chip_core.sv
  - .../rtl/chip_top.sv
```

frontend:

```yaml
USE_SLANG: true
```

---

# 27. Full-Chip Clock

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
CLOCK_PERIOD: 20.0
```

ความแตกต่างจาก core-only:

```text
Lab 3:
CLOCK_PORT = clk_i

Lab 5:
CLOCK_PORT = clk_PAD
```

เพราะ clock ต้องเริ่มที่ chip boundary

---

# 28. Pad Lists ใน Generated Config

ตัวอย่าง:

```yaml
PAD_NORTH:
  - "outputs\\[7\\].output_pad"
  - "outputs\\[6\\].output_pad"
  ...
```

LibreLane จะใช้รายการนี้กับ OpenROAD PadRing

---

# 29. Power Nets

```yaml
VDD_NETS:
  - VDD

GND_NETS:
  - VSS
```

นี่กำหนด core supply domain หลัก

I/O power nets:

```text
IOVDD
IOVSS
```

ยังปรากฏผ่าน I/O pad cell connectivity

---

# 30. PDN Baseline ที่ Prepare ไว้

แม้ Lab 5 หยุดที่ PadRing config มี baseline:

```yaml
PDN_CORE_RING: true
PDN_CORE_RING_CONNECT_TO_PADS: true
PDN_ENABLE_PINS: false

PDN_CORE_RING_VWIDTH: 15
PDN_CORE_RING_HWIDTH: 15

PDN_CORE_RING_VSPACING: 5
PDN_CORE_RING_HSPACING: 5
```

เพื่อให้ Lab 6 ต่อ PDN ได้โดยไม่ออกแบบ config ใหม่ทั้งหมด

---

# 31. Placement Density

```yaml
PL_TARGET_DENSITY_PCT: 20
```

CPU core เล็กเมื่อเทียบกับ 870×870 µm core region

Lab จึงใช้ conservative density เพื่อหลีกเลี่ยง congestion ใน first full-chip iteration

---

# 32. Step 9 — Check Generated Config

```bash
make check-config
```

ตรวจ:

```text
meta.version = 3
flow = Chip
DESIGN_NAME = chip_top
USE_SLANG = true
CLOCK_PORT = clk_PAD
CLOCK_NET = clk_pad/p2c
DIE_AREA
CORE_AREA
PAD_*
bondpad
EXTRA_GDS
EXTRA_LEFS
```

---

# 33. Step 10 — Full Preflight

```bash
make preflight
```

รวม:

```text
environment
expected pad instances
pad plan validation
bondpad validation
config generation
config validation
```

ต้องได้:

```text
LAB 5 PREFLIGHT PASS
```

ก่อนเรียก LibreLane

---

# 34. Step 11 — Synthesis Checkpoint

ก่อน PadRing แนะนำ:

```bash
make synth
```

หยุดที่:

```text
Yosys.Synthesis
```

นี่ตรวจว่า:

```text
CPU RTL
wrapper
IHP pad-cell references
Slang frontend
```

ผ่าน synthesis/elaboration

---

# 35. Step 12 — Floorplan Checkpoint

```bash
make floorplan
```

LibreLane:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag lab05_floorplan \
  --to OpenROAD.Floorplan \
  build/config.yaml
```

Lab ยังไม่ place pad ring ณ checkpoint นี้

แต่สร้าง:

```text
die boundary
core boundary
rows/tracks
initial ODB/DEF
```

---

# 36. Inspect Floorplan

ตรวจ log:

```bash
make check-floorplan
```

แล้วหา run directory

LibreLane run จะมี step directory ลักษณะ:

```text
...-openroad-floorplan/
```

ภายในมักมี:

```text
ODB
DEF
SDC
netlist views
logs/reports
```

---

# 37. สิ่งที่ต้องตรวจใน Floorplan

### Die

```text
1600 × 1600 µm
```

### Core

```text
870 × 870 µm
```

### Margin

ต้องมีพื้นที่ ring รอบ core เพียงพอ

### Rows

standard-cell rows ต้องอยู่ใน core

### Pad cells

ยังไม่ควรตีความ location จน PadRing step จบ

---

# 38. Step 13 — Generate Pad Ring

main target:

```bash
make padring
```

command:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag lab05_padring \
  --to OpenROAD.PadRing \
  build/config.yaml
```

flow จะผ่าน:

```text
Synthesis
Checkers
SDC
pre-PnR STA
Floorplan
SetPowerConnections
PadRing
```

---

# 39. Step 14 — Check PadRing Log

```bash
make check-padring
```

และ:

```bash
grep -RniE \
  'ERROR|pad.*not.*found|invalid.*pad|unmapped' \
  reports/lab05_padring.log
```

ต้องไม่มี fatal error

---

# 40. Physical Visual Inspection

PadRing เป็น geometry problem

log pass อย่างเดียวไม่พอ

ต้องเปิด ODB/DEF จาก PadRing step ใน OpenROAD GUI หรือ visualization mechanism ของ LibreLane environment

ตรวจ:

```text
south pad order
east pad order
north pad order
west pad order
pad rotations
corner clearance
pad overlap
core clearance
```

---

# 41. Expected Conceptual Layout

```text
                    NORTH

       OUT7 OUT6 OUT5 OUT4 IOVSS
    +--------------------------------+
    |                                |
    |                                |
W   |                                |   E
E   |             CORE               |   A
S   |                                |   S
T   |                                |   T
    |                                |
    +--------------------------------+
 IOVSS IOVDD VSS VDD       OUT0 OUT1 OUT2 OUT3 IOVDD

        VSS VDD RST CLK
                    SOUTH
```

diagram นี้เป็น conceptual order

actual orientation/rotations ต้องดู OpenROAD result

---

# 42. Pad Order Direction Caveat

คำว่า:

```text
PAD_NORTH list order
```

ไม่ได้หมายความโดยอัตโนมัติว่า schematic drawing จากซ้ายไปขวาจะตรงกับ list ทุกด้าน

orientation conventions ของ pad placer ต้องตรวจจาก generated DEF/GUI

ดังนั้นไม่ควรออก package pin table จาก YAML อย่างเดียว

---

# 43. Bondpad vs I/O Cell

ต้องแยกสององค์ประกอบ:

```text
bondpad
```

คือโลหะบริเวณที่ wire bond/package connection แตะ

กับ:

```text
I/O cell
```

ซึ่งมี:

```text
ESD
input/output buffer
power structures
pad interface
```

LibreLane Chip flow เชื่อม physical bondpad เข้ากับ pad-cell structure

---

# 44. Why `IGNORE_DISCONNECTED_MODULES`

bondpad ถูกเพิ่มเป็น extra physical macro:

```yaml
IGNORE_DISCONNECTED_MODULES:
  - bondpad_70x70_novias
```

เพราะตัว physical bondpad view อาจไม่ได้เป็น logical design module แบบ standard RTL hierarchy

config pattern นี้ตาม official IHP full-chip template

---

# 45. Why `MAGIC_EXT_UNIQUE: notopports`

เมื่อมี power pads หลายตัวต่อ domain เดียวกัน extraction อาจมี top-port uniqueness issues

official template ใช้:

```yaml
MAGIC_EXT_UNIQUE: notopports
```

Lab จึงรักษาค่านี้ไว้สำหรับ downstream LVS/extraction stages

---

# 46. Troubleshooting — Unknown `PAD_*`

ถ้า LibreLane บอก:

```text
Unknown key PAD_...
```

ตรวจ:

```bash
librelane --version
```

และยืนยันว่าใช้:

```bash
--flow Chip
```

เพราะ PAD variables เป็น Chip-flow configuration

---

# 47. Troubleshooting — Pad Instance Not Found

ตัวอย่าง:

```text
outputs[0].output_pad not found
```

ตรวจ:

```bash
make expected-pads
make check-pad-plan
```

จากนั้นดู synthesized hierarchy

สาเหตุที่เป็นไปได้:

```text
generate hierarchy name changed
instance optimized away
source wrapper ไม่ตรง Lab 4
escaping ผิด
```

---

# 48. Troubleshooting — Power Pad Optimized Away

power pads มี:

```systemverilog
(* keep *)
```

ใน wrapper

ถ้า instance หายให้ตรวจ:

```text
wrapper source version
PDK I/O blackbox definitions
USE_POWER_PINS / FUNCTIONAL defines
synthesis log
```

---

# 49. Troubleshooting — Bondpad GDS Missing

อาการ:

```text
invalid path
file not found
```

รัน:

```bash
make setup-bondpad
make check-bondpad
```

ตรวจ:

```bash
ls -lh \
  ip/bondpad_70x70_novias/gds/bondpad_70x70_novias.gds
```

ห้ามสร้าง empty placeholder เพื่อให้ config validation ผ่าน

---

# 50. Troubleshooting — Bondpad LEF/GDS Mismatch

LEF macro ต้องเป็น:

```text
bondpad_70x70_novias
```

config:

```yaml
PAD_BONDPAD_NAME: bondpad_70x70_novias
```

ถ้าชื่อไม่ตรง PadRing/streamout อาจ fail

---

# 51. Troubleshooting — Die Too Small

อาการ:

```text
pad overlap
cannot place pad
insufficient edge space
```

แก้โดย:

```text
เพิ่ม DIE_AREA
ลด pad count
ใช้ pad-cell dimensions/package strategy อื่น
```

อย่าลด spacing อย่างสุ่มโดยไม่ดู physical rules

---

# 52. Troubleshooting — Core Too Large

ถ้า pad cells/ring ชน core:

เพิ่ม margin เช่น:

```yaml
CORE_AREA:
  - 400
  - 400
  - 1200
  - 1200
```

แต่ต้องตรวจ core utilization ใหม่

---

# 53. Troubleshooting — Clock Net Not Found

config:

```yaml
CLOCK_NET: clk_pad/p2c
```

ถ้า net path ไม่ resolve ให้ตรวจ synthesized hierarchy

ชื่อที่แท้จริงอาจเปลี่ยนตาม frontend/hierarchy preservation

ห้ามเปลี่ยนเป็นชื่อคาดเดาโดยไม่ดู netlist

---

# 54. Troubleshooting — Synthesis Fails ก่อน PadRing

กลับไป Lab 3/4 concepts

ตรวจ:

```text
unmapped cell
package parsing
IHP I/O cell models
wrapper interface
duplicate source
```

PadRing ไม่ใช่ที่แก้ synthesis problems

---

# 55. Generate Lab Report

```bash
make report
```

ได้:

```text
reports/LAB05_REPORT.md
```

รวบรวม:

```text
environment
expected pads
pad plan
bondpad validation
config validation
floorplan check
PadRing check
Git revision
```

---

# 56. Recommended Run Sequence

ครั้งแรก:

```bash
make clean
make setup-bondpad
make preflight
```

จากนั้น:

```bash
make synth
```

ถ้าผ่าน:

```bash
make floorplan
make check-floorplan
```

จากนั้น main step:

```bash
make padring
make check-padring
make report
```

---

# 57. One-Command Flow

เมื่อ environment และ bondpad พร้อม:

```bash
make all
```

แต่สำหรับ workshop รอบแรกแนะนำ run ทีละ checkpoint เพื่อให้เห็น failure locality

---

# 58. Pass Criteria

Lab 5 ผ่านเมื่อ:

```text
[ ] LibreLane/IHP environment available
[ ] 18 expected pad instances enumerated
[ ] every pad appears once in pad plan
[ ] no unknown pad instance
[ ] real bondpad LEF exists
[ ] real bondpad GDS exists
[ ] bondpad macro = bondpad_70x70_novias
[ ] generated config uses meta.version 3
[ ] flow = Chip
[ ] DESIGN_NAME = chip_top
[ ] CLOCK_PORT = clk_PAD
[ ] CLOCK_NET = clk_pad/p2c
[ ] DIE_AREA = 1600 × 1600 µm
[ ] CORE_AREA = 870 × 870 µm
[ ] synthesis reaches mapped netlist
[ ] Floorplan completes
[ ] PadRing completes
[ ] no pad-not-found error
[ ] no pad overlap visible in physical inspection
[ ] pad sides/order reviewed in GUI
[ ] LAB05_REPORT.md generated
```

---

# 59. Deliverables

```text
config/pad_plan.yaml
build/config.yaml

rtl/chip_core.sv
rtl/chip_top.sv

constraints/chip_top.sdc

ip/bondpad_70x70_novias/
├── lef/bondpad_70x70_novias.lef
└── gds/bondpad_70x70_novias.gds

reports/
├── 00_environment.log
├── 01_expected_pad_instances.txt
├── 02_pad_plan_check.txt
├── 03_bondpad_check.txt
├── 04_config_check.txt
├── 05_floorplan_check.txt
├── 06_padring_check.txt
└── LAB05_REPORT.md
```

และ LibreLane PadRing:

```text
ODB
DEF
SDC/netlist views
step logs
```

---

# 60. Design Review Questions

1. `PAD_NORTH` ต้องใช้ port name หรือ instance name?
2. ทำไม generate-array brackets ต้อง escape?
3. PadRing ต่างจาก IO pin placement อย่างไร?
4. ทำไม full-chip die margin ต้องใหญ่กว่า core-only?
5. Bondpad ต่างจาก I/O cell อย่างไร?
6. ทำไม Lab ไม่สร้าง fake bondpad GDS?
7. `CLOCK_PORT` กับ `CLOCK_NET` ต่างกันอย่างไร?
8. ทำไมต้องมีทั้ง VDD/VSS และ IOVDD/IOVSS?
9. ทำไม visual inspection ยังจำเป็นแม้ flow return success?
10. ถ้า PadRing fail แต่ Floorplan ผ่าน ควร debug subsystem ใดก่อน?

---

# 61. สิ่งที่ Freeze หลัง Lab 5

เมื่อ PadRing clean ให้ freeze:

```text
die dimensions
core dimensions
pad count
pad cell types
pad instance names
pad side allocation
clock pad location
reset pad location
power pad allocation
bondpad macro
bondpad physical views
```

เพราะสิ่งเหล่านี้มีผลต่อ:

```text
PDN
placement
clock routing
package planning
routing congestion
```

---

# 62. Transition ไป Lab 6

Lab ต่อไปควรเป็น:

```text
Lab 6 — Floorplan and Power Distribution Network
```

ใช้ pad ring ที่ freeze แล้วเพื่อสร้าง:

```text
VDD/VSS core ring
pad-to-ring connectivity
standard-cell rails
power straps
power-grid validation
```

architecture:

```text
power pads
    |
    v
pad-ring power
    |
    v
core ring
    |
    v
PDN straps
    |
    v
standard-cell rails
```

อย่าเริ่ม placement/CTS จนกว่า power architecture จะถูกตรวจให้ชัดเจน
