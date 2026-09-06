# Lab 6 — Floorplan and Power Distribution Network
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Top:** `chip_top`  
**Flow:** LibreLane `Chip`  
**PDK:** IHP SG13G2  
**Main endpoint:** `OpenROAD.GeneratePDN`  
**Clock:** 50 MHz / 20 ns  
**Die:** 1600 µm × 1600 µm  
**Core:** 870 µm × 870 µm  
**Core-ring width:** 15 µm  
**Core-ring spacing:** 5 µm

---

# 1. เป้าหมายของ Lab

Lab 5 ทำให้เราได้ pad ring

Lab 6 ต้องตอบคำถามที่สำคัญกว่าการมี pad อยู่รอบ die:

> ไฟเลี้ยงจาก package จะเดินทางเข้าไปเลี้ยง logic ภายใน core ได้อย่างไร?

conceptual path:

```text
package
   |
power bondpads / I/O power structures
   |
VDD / VSS pad network
   |
core power ring
   |
PDN straps / rails
   |
standard-cell power pins
```

Lab นี้จึงรวมสองเรื่อง:

```text
Floorplan
+
Power Distribution Network
```

เพราะ PDN geometry ถูกกำหนดอย่างมากโดย floorplan

---

# 2. ทำไม Floorplan มาก่อน PDN

ก่อนสร้าง power grid ต้องรู้:

```text
die boundary
core boundary
pad positions
macro positions
routing layers
power domains
```

ถ้า core boundary เปลี่ยน:

```text
core ring geometry เปลี่ยน
strap reach เปลี่ยน
routing corridor เปลี่ยน
```

ดังนั้น floorplan และ pad ring ต้อง stable ก่อน PDN

---

# 3. LibreLane PDN Step

LibreLane มี built-in step:

```text
OpenROAD.GeneratePDN
```

หน้าที่คือสร้าง PDN บน floorplanned OpenDB database

ผลลัพธ์สำคัญ:

```text
ODB
DEF
SDC
netlist
powered netlist
```

Lab 6 จึงหยุดที่ step นี้

---

# 4. PDN ประกอบด้วยอะไร

PDN ทั่วไปมี:

```text
rings
straps
rails
vias
```

## Ring

วงโลหะรอบ core

หน้าที่:

```text
รับ power จาก pad side
กระจายกระแสรอบ core
```

## Straps

metal เส้นกว้างที่ลากเข้าไปใน core

## Rails

เส้น power/ground ที่สัมพันธ์กับ standard-cell rows

## Vias

เชื่อม power grid ระหว่าง metal layers

---

# 5. Power Domains ใน Chip นี้

Lab ใช้:

```text
Core supply:
VDD
VSS

I/O supply:
IOVDD
IOVSS
```

LibreLane main PDN domain:

```yaml
VDD_NETS:
  - VDD

GND_NETS:
  - VSS
```

ดังนั้น Lab นี้เน้น core-domain PDN ก่อน

---

# 6. I/O Power ไม่เท่ากับ Core Power

I/O pad circuitry อาจใช้:

```text
IOVDD / IOVSS
```

ขณะที่ digital logic ใช้:

```text
VDD / VSS
```

ห้ามรวมชื่อ supply สอง domain เข้าด้วยกันโดยไม่เข้าใจ PDK/I/O architecture

---

# 7. Frozen Pad Ring

Lab 6 ไม่ redesign pad plan

ใช้ของ Lab 5:

```text
18 pad cells
```

ประกอบด้วย:

```text
clk
reset
8 outputs
2 VDD
2 VSS
2 IOVDD
2 IOVSS
```

หลักการคือ:

> เปลี่ยนตัวแปรทีละ subsystem

Lab 5 freeze pads

Lab 6 เปลี่ยนเฉพาะ power-grid stage

---

# 8. Frozen Floorplan

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

Die:

```text
1.6 mm × 1.6 mm
```

Core:

```text
870 µm × 870 µm
```

---

# 9. Core Margin

margin ทุกด้านประมาณ:

```text
365 µm
```

นี่เป็น large teaching margin

ต้องรองรับ:

```text
pad cell
bondpad
pad-to-ring power approach
ring
routing transition
```

---

# 10. Geometry Budget ไม่ใช่ Ring Coordinate

รัน:

```bash
make geometry
```

ได้:

```text
reports/05_geometry_budget.txt
```

script คำนวณ:

```text
die size
core size
core-to-edge margins
ring width
ring spacing
```

แต่ไม่คาดเดา exact ring coordinates

exact coordinates ต้องดูจาก OpenROAD ODB/DEF

---

# 11. Baseline Core Ring

official IHP full-chip template ใช้:

```yaml
PDN_CORE_RING: true

PDN_CORE_RING_VWIDTH: 15
PDN_CORE_RING_HWIDTH: 15

PDN_CORE_RING_VSPACING: 5
PDN_CORE_RING_HSPACING: 5
```

Lab ใช้ค่าเดียวกันเป็น teaching baseline

---

# 12. Ring Width

```text
15 µm
```

width ที่มากขึ้น:

```text
resistance ลด
current capacity เพิ่ม
area/routing blockage เพิ่ม
```

ดังนั้น width ไม่ควรถูกเลือกเพียงเพราะ “ยิ่งใหญ่ยิ่งดี”

---

# 13. Ring Spacing

```text
5 µm
```

spacing ต้องสัมพันธ์กับ:

```text
technology design rules
long-metal spacing
routing resources
```

Lab ยึดค่า template เพื่อเริ่มจาก known-good pattern

---

# 14. Ring-to-Pad Connectivity

ค่าหลัก:

```yaml
PDN_CORE_RING_CONNECT_TO_PADS: true
```

ความหมายเชิงเจตนา:

```text
core ring
   |
   +--> connect toward pad power structures
```

นี่สำคัญมากใน full-chip design

ถ้ามี ring แต่ไม่เชื่อมกับ package power:

```text
ring เป็นเพียงโลหะลอย
```

ซึ่งไม่มีประโยชน์

---

# 15. `PDN_ENABLE_PINS: false`

core-only block มักต้อง expose top-level power pins

แต่ full chip นี้มี power เข้าผ่าน physical pads

baseline จึงใช้:

```yaml
PDN_ENABLE_PINS: false
```

ตาม official IHP template

---

# 16. Standard-Cell Rails

standard cells ต้องได้รับ:

```text
VDD
VSS
```

ผ่าน row-level rails/followpins

PDN flow ของ LibreLane/OpenROAD จะสร้าง/เชื่อม rails ตาม PDK/default PDN configuration

Lab 6 ไม่ override rail layers เองเพื่อไม่ผูกกับ assumption ที่ไม่จำเป็น

---

# 17. ทำไมยังไม่ Custom `PDN_CFG`

official IHP template มี custom `pdn_cfg.tcl` เพื่อรองรับ SRAM macro grids

แต่ Lab 6 ยังไม่มี SRAM macro

ดังนั้น baseline ที่ปลอดภัยคือ:

```text
ใช้ default/PDK PDN behavior
+
core-ring variables
```

แทนการ copy macro-specific PDN Tcl มาใช้โดยไม่จำเป็น

---

# 18. เมื่อไรต้องใช้ Custom PDN_CFG

เมื่อเพิ่ม:

```text
SRAM
analog macro
multiple voltage island
hard macro with special pins
```

จึงควรพิจารณา:

```yaml
PDN_CFG: ...
PDN_MACRO_CONNECTIONS: ...
```

---

# 19. Directory Structure

```text
lab06_floorplan_pdn/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB06_TH.md
│
├── rtl/
│   ├── chip_core.sv
│   └── chip_top.sv
│
├── config/
│   ├── cpu_source_manifest.txt
│   ├── pad_plan.yaml
│   └── pdn_plan.yaml
│
├── constraints/
│   └── chip_top.sdc
│
├── ip/
│   └── bondpad_70x70_novias/
│
├── scripts/
│   ├── setup_bondpad.sh
│   ├── check_env.sh
│   ├── check_bondpad.py
│   ├── elaborate_pad_instances.py
│   ├── check_pad_plan.py
│   ├── check_pdn_plan.py
│   ├── pdn_geometry_budget.py
│   ├── gen_config.py
│   ├── check_config.py
│   ├── check_run_log.py
│   └── build_report.py
│
├── openroad/
│   └── README.md
├── build/
└── reports/
```

---

# 20. Step 1 — เข้า Environment

เข้า LibreLane/IHP environment

ตัวอย่าง:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

กลับ Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab06_floorplan_pdn
```

---

# 21. Step 2 — Check Environment

```bash
make check-env
```

ต้องมี:

```text
python3
verilator
yosys
librelane
```

OpenROAD ควรมี:

```text
openroad
```

สำหรับ GUI inspection

---

# 22. Step 3 — Setup Bondpad

```bash
make setup-bondpad
```

เหมือน Lab 5

Lab ไม่สร้าง fake GDS

---

# 23. Step 4 — Validate Bondpad

```bash
make check-bondpad
```

ต้องผ่าน:

```text
LEF
GDS
macro name
physical file size
```

---

# 24. Step 5 — Validate Frozen Pad Plan

```bash
make check-pad-plan
```

ต้องยังได้:

```text
18 expected pads
18 listed pads
no duplicates
no unknown instance
```

ถ้า fail:

> อย่าแก้ PDN ก่อนแก้ pad-ring consistency

---

# 25. Step 6 — Inspect PDN Plan

ไฟล์:

```text
config/pdn_plan.yaml
```

มี:

```yaml
PDN_CORE_RING: true
PDN_CORE_RING_CONNECT_TO_PADS: true
PDN_ENABLE_PINS: false

PDN_CORE_RING_VWIDTH: 15
PDN_CORE_RING_HWIDTH: 15

PDN_CORE_RING_VSPACING: 5
PDN_CORE_RING_HSPACING: 5
```

---

# 26. Step 7 — Validate PDN Plan

```bash
make check-pdn-plan
```

expected:

```text
PASS  PDN_CORE_RING = true
PASS  PDN_CORE_RING_CONNECT_TO_PADS = true
PASS  PDN_ENABLE_PINS = false
PASS  PDN_CORE_RING_VWIDTH = 15
PASS  PDN_CORE_RING_HWIDTH = 15
PASS  PDN_CORE_RING_VSPACING = 5
PASS  PDN_CORE_RING_HSPACING = 5
```

---

# 27. Step 8 — Geometry Budget

```bash
make geometry
```

expected:

```text
Die            : 1600.0 x 1600.0 um
Core           : 870.0 x 870.0 um
Margin left    : 365.0 um
Margin right   : 365.0 um
Margin bottom  : 365.0 um
Margin top     : 365.0 um
Ring width     : 15.0 um
Ring spacing   : 5.0 um
```

---

# 28. Step 9 — Generate Config

```bash
make gen-config
```

สร้าง:

```text
build/config.yaml
```

generator รวม:

```text
RTL
pad plan
floorplan
clock
power nets
PDN plan
bondpad
```

---

# 29. Generated Power Section

```yaml
VDD_NETS:
  - VDD

GND_NETS:
  - VSS
```

และ:

```yaml
PDN_CORE_RING: true
PDN_CORE_RING_CONNECT_TO_PADS: true
PDN_ENABLE_PINS: false

PDN_CORE_RING_VWIDTH: 15
PDN_CORE_RING_HWIDTH: 15
PDN_CORE_RING_VSPACING: 5
PDN_CORE_RING_HSPACING: 5
```

---

# 30. Step 10 — Check Config

```bash
make check-config
```

ตรวจ:

```text
Chip flow
top
clock
die/core geometry
VDD/VSS
ring enable
ring-to-pads
width/spacing
bondpad
```

---

# 31. Step 11 — Full Preflight

```bash
make preflight
```

ลำดับ:

```text
environment
pad plan
bondpad
PDN plan
geometry budget
generated config
```

expected:

```text
LAB 6 PREFLIGHT PASS
```

---

# 32. Step 12 — Re-run Floorplan Checkpoint

แม้ Lab 5 เคยผ่าน ควรรัน:

```bash
make floorplan
```

เพื่อยืนยันว่า frozen inputs ยัง reproduce

จากนั้น:

```bash
make check-floorplan
```

---

# 33. ทำไมต้อง Reproduce ไม่ใช่ Reuse Run เก่าอย่างเดียว

เพราะ Lab 6 package มี:

```text
config generator
PDN plan
tool version
repo revision
```

ใหม่

engineering discipline ที่ดีคือ:

```text
reproduce upstream checkpoint
before trusting downstream result
```

---

# 34. Step 13 — Re-run PadRing

```bash
make padring
make check-padring
```

ต้องไม่มี pad regression

ถ้า PadRing fail:

```text
หยุด
```

อย่า run GeneratePDN

---

# 35. Step 14 — Generate PDN

main target:

```bash
make pdn
```

command:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag lab06_pdn \
  --to OpenROAD.GeneratePDN \
  build/config.yaml
```

flow จะผ่าน:

```text
Synthesis
SDC
Floorplan
Power connections
PadRing
...
GeneratePDN
```

---

# 36. Step 15 — Check PDN Log

```bash
make check-pdn
```

script scan fatal signatures เช่น:

```text
ERROR
PDN fail
power not found
ground not found
cannot connect
```

แต่:

> log pass ไม่ใช่ proof ว่า power grid ดี

---

# 37. Locate GeneratePDN Artifacts

ค้น:

```bash
find . "$REPO_ROOT" \
  -type d \
  -iname '*generatepdn*'
```

หรือดู run log

step directory ควรมี ODB/DEF views

---

# 38. OpenROAD GUI Inspection

เปิด ODB/DEF ของ GeneratePDN step

ตรวจ layers ทีละชั้น

แนะนำ hide signal routing ถ้ายังไม่มี

focus:

```text
pad cells
VDD/VSS shapes
core ring
rails
vias
```

---

# 39. Visual Check 1 — Core Ring Exists

ต้องเห็น ring รอบ core

โดยมี:

```text
VDD
VSS
```

เป็น alternating/specified power-ground conductors ตาม PDN setup

ถ้าไม่มี ring:

ตรวจ:

```yaml
PDN_CORE_RING: true
```

---

# 40. Visual Check 2 — Ring Does Not Cross Core Logic Region Incorrectly

ring ควรอยู่ใน geometry ที่ flow กำหนด

ต้องไม่:

```text
ทับ pad cell
ออกนอก die
ตัดผ่าน illegal obstruction
```

---

# 41. Visual Check 3 — Connection Toward Power Pads

ตรวจ physical path จาก:

```text
VDD/VSS pad structures
```

ไป:

```text
core ring
```

นี่คือจุดสำคัญของ:

```yaml
PDN_CORE_RING_CONNECT_TO_PADS: true
```

---

# 42. Visual Check 4 — Standard-Cell Rails

ดูใน core rows ว่ามี power rails/followpins ตาม flow

rail ต้องสอดคล้องกับ standard-cell architecture

---

# 43. Visual Check 5 — Vias

ring/strap/rail ที่อยู่คนละ layer ต้องมี via connections

ถ้า geometry ดูเหมือนเส้นตัดกันแต่ไม่มี via:

```text
electrically disconnected
```

---

# 44. Connectivity vs Geometry

เส้นโลหะ “แตะกันบนจอ” ไม่ได้หมายความว่า connected เสมอ

ต้องพิจารณา:

```text
same layer overlap
or
via connection
```

OpenDB/net connectivity/report เป็นหลักฐานที่แข็งแรงกว่า screenshot

---

# 45. Powered Netlist

GeneratePDN step สามารถผลิต powered netlist view

ใช้ตรวจว่า:

```text
standard-cell power pins
```

ถูก associate กับ:

```text
VDD/VSS
```

ตาม flow

---

# 46. ทำไมยังไม่ทำ IR Drop ใน Lab 6

IR-drop analysis ต้องการข้อมูลที่มีความหมาย เช่น:

```text
placed cells
activity/power assumptions
routing/resistance
current demand
```

หลังแค่ floorplan+PDN:

```text
load distribution ยังไม่ final
```

ดังนั้น Lab 6 เน้น:

```text
topology
connectivity
geometry
```

ไม่ใช่ final IR-drop signoff

---

# 47. Resistance Intuition

โดยประมาณ:

```text
R = ρL/A
```

metal ที่:

```text
กว้างขึ้น
หนาขึ้น
สั้นลง
```

มี resistance ต่ำลง

นี่เป็นเหตุผลที่ power straps/rings ใช้ width ใหญ่กว่า signal routes

---

# 48. Current Density

power grid ต้องรับ current จำนวนมาก

ถ้าโลหะแคบเกิน:

```text
IR drop สูง
current density สูง
EM risk สูง
```

ดังนั้น PDN sizing เป็นทั้ง:

```text
voltage integrity problem
+
reliability problem
```

---

# 49. VDD/VSS Symmetry

ควรตรวจว่าการกระจาย:

```text
VDD
VSS
```

ไม่ bias ไปด้านใดด้านหนึ่งโดยไม่ตั้งใจ

power return path สำคัญพอ ๆ กับ supply path

---

# 50. Why Multiple Power Pads

Lab มี:

```text
2 × VDD
2 × VSS
```

ช่วย:

```text
ลด package/pad current bottleneck
กระจาย current injection
ลด effective path resistance
```

แต่จำนวนจริงใน tapeout ต้องอิง power budget/package/ESD requirements

---

# 51. IOVDD/IOVSS ใน Lab 6

อย่าตีความว่า core PDN ring เชื่อม IOVDD/IOVSS

baseline core ring เน้น:

```text
VDD/VSS
```

I/O supply architecture เป็น separate domain

ต้องรักษา net separation

---

# 52. Troubleshooting — VDD Net Not Found

ตรวจ RTL/pad power pins และ config:

```yaml
VDD_NETS:
  - VDD
```

ตรวจ `USE_POWER_PINS`/functional models และ PDK cell definitions

---

# 53. Troubleshooting — VSS Net Not Found

เหมือน VDD

ตรวจ:

```yaml
GND_NETS:
  - VSS
```

และ physical power pad connectivity

---

# 54. Troubleshooting — Ring Not Generated

ตรวจ:

```bash
grep -n PDN_CORE_RING build/config.yaml
```

ต้องได้:

```text
PDN_CORE_RING: true
```

ตรวจ GeneratePDN log

---

# 55. Troubleshooting — Ring Does Not Reach Pads

ตรวจ:

```text
PDN_CORE_RING_CONNECT_TO_PADS
power pad instances
VDD/VSS naming
pad cell physical pins
```

อย่าแก้ด้วยการวาด metal manual ก่อนเข้าใจ connectivity issue

---

# 56. Troubleshooting — Ring/Pad Overlap

สาเหตุ:

```text
die/core margin ไม่พอ
ring width/spacing มากเกิน
pad geometry ใหญ่
```

แนวแก้:

```text
ปรับ core area
เพิ่ม die area
review ring dimensions
```

ต้องดู GUI ก่อน

---

# 57. Troubleshooting — Illegal Geometry

ถ้า OpenROAD PDN fail ด้วย spacing/enclosure issue:

```text
อย่าลด rule แบบสุ่ม
```

ใช้ known-good template values และตรวจ PDK layer/rule assumptions

---

# 58. Troubleshooting — Standard-Cell Rails Missing

ตรวจ:

```text
PDN flow/default configuration
row generation
rail layer
PDN_ENABLE_RAILS/defaults
```

Lab deliberately ไม่ override rail variables

ถ้าต้อง override ต้องตรวจ current LibreLane/PDK values ก่อน

---

# 59. Troubleshooting — Custom PDN_CFG Temptation

อย่า copy official template `pdn_cfg.tcl` ทั้งหมดมาใช้เพียงเพราะ “official”

ไฟล์นั้นรองรับ:

```text
macro grids
SRAM connection examples
```

ซึ่ง Lab นี้ไม่มี

minimum configuration ลด failure surface

---

# 60. Generate Report

```bash
make report
```

ได้:

```text
reports/LAB06_REPORT.md
```

---

# 61. Recommended Run Sequence

```bash
make clean
make setup-bondpad
make preflight

make floorplan
make check-floorplan

make padring
make check-padring

make pdn
make check-pdn

make report
```

---

# 62. Fast Re-run

เมื่อ upstream stable แล้ว:

```bash
make all
```

---

# 63. Pass Criteria — Floorplan

```text
[ ] Die = 1600 × 1600 µm
[ ] Core = 870 × 870 µm
[ ] Core margin reviewed
[ ] Pad ring reproduced
[ ] No pad overlap
[ ] No core/pad collision
```

---

# 64. Pass Criteria — PDN

```text
[ ] VDD net exists
[ ] VSS net exists
[ ] Core ring generated
[ ] Ring width = 15 µm intent
[ ] Ring spacing = 5 µm intent
[ ] Ring-to-pad connection requested
[ ] Power-pad-to-ring geometry reviewed
[ ] Standard-cell rails/grid visible
[ ] Required vias visible/present
[ ] No obvious floating special-power geometry
[ ] GeneratePDN completes
[ ] No fatal PDN error in log
```

---

# 65. Important Qualification

Lab 6 PASS means:

```text
PDN topology and geometry are suitable to proceed
```

ไม่ได้หมายถึง:

```text
IR-drop signoff passed
EM signoff passed
power integrity guaranteed
```

---

# 66. Deliverables

```text
config/pad_plan.yaml
config/pdn_plan.yaml

build/config.yaml

reports/
├── 00_environment.log
├── 01_expected_pad_instances.txt
├── 02_pad_plan_check.txt
├── 03_bondpad_check.txt
├── 04_pdn_plan_check.txt
├── 05_geometry_budget.txt
├── 06_config_check.txt
├── 07_floorplan_check.txt
├── 08_padring_check.txt
├── 09_pdn_check.txt
└── LAB06_REPORT.md
```

และ GeneratePDN artifacts:

```text
ODB
DEF
powered netlist
logs/reports
```

---

# 67. Design Review Questions

1. ทำไม floorplan ต้อง stable ก่อน PDN?
2. Ring, strap และ rail ต่างกันอย่างไร?
3. ทำไม `PDN_CORE_RING_CONNECT_TO_PADS` สำคัญ?
4. ทำไม full-chip baseline ใช้ `PDN_ENABLE_PINS: false`?
5. VDD/VSS ต่างจาก IOVDD/IOVSS อย่างไร?
6. ทำไม geometry touching ไม่ได้แปลว่า electrical connection?
7. ทำไมต้องตรวจ vias?
8. ทำไม Lab นี้ยังไม่สรุป IR drop?
9. ทำไมไม่ custom `PDN_CFG` ตั้งแต่แรก?
10. ถ้า GeneratePDN ผ่านแต่ ring ไม่เชื่อม power pads ใน GUI ถือว่า Lab ผ่านหรือไม่?

คำตอบข้อ 10:

```text
ไม่ผ่าน
```

เพราะ flow completion ไม่เท่ากับ correct physical intent

---

# 68. สิ่งที่ Freeze หลัง Lab 6

เมื่อ PDN ผ่าน ให้ freeze:

```text
die/core dimensions
pad ring
VDD/VSS naming
power pad allocation
core-ring enable
ring-to-pad connectivity
ring width
ring spacing
PDN topology
```

---

# 69. Transition ไป Lab 7

Lab ต่อไปเหมาะกับ:

```text
Lab 7 — Placement and Clock Tree Synthesis
```

ลำดับ:

```text
Floorplan
   |
Pad Ring
   |
PDN
   |
Placement
   |
CTS
```

เพราะเมื่อ standard cells เริ่มมีตำแหน่งจริง เราจึงสามารถวิเคราะห์:

```text
density
wirelength
congestion
clock sinks
clock skew
setup/hold
```

ได้อย่างมีความหมาย

---

# 70. Engineering Rule ของ Lab 6

จำไว้ว่า:

> Power intent ต้องถูกพิสูจน์ทั้งจาก net connectivity และ physical geometry

และ:

> PDN ที่สวยในภาพแต่ไม่ connected ไม่มีคุณค่าทางไฟฟ้า

ดังนั้น Lab 6 ไม่จบที่คำว่า:

```text
OpenROAD.GeneratePDN SUCCESS
```

แต่จบเมื่อ:

```text
configuration
+
log
+
ODB/DEF geometry
+
connectivity intent
```

สอดคล้องกัน
