# Lab 7 — Placement and Clock Tree Synthesis
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Top:** `chip_top`  
**PDK:** `ihp-sg13g2`  
**Flow:** LibreLane `Chip`  
**Clock target:** 50 MHz / 20 ns  
**Placement density baseline:** 20%  
**Main CTS endpoint:** `OpenROAD.CTS`  
**Post-CTS endpoint:** `OpenROAD.STAMidPNR-2`

---

# 1. เป้าหมายของ Lab

Lab 6 ทำให้ได้:

```text
floorplan
pad ring
PDN
```

แต่ standard cells ยังไม่ได้มี physical location ที่ final

และ clock ยังเป็นเพียง logical net

Lab 7 เปลี่ยน:

```text
logical standard-cell network
```

ให้เป็น:

```text
physically placed cells
+
real clock tree structure
```

---

# 2. Flow ของ Lab

LibreLane `Chip` flow ปัจจุบันเรียง stage สำคัญดังนี้:

```text
OpenROAD.GeneratePDN
        |
OpenROAD.GlobalPlacement
        |
Checker.PowerGridViolations
        |
OpenROAD.STAMidPNR
        |
OpenROAD.RepairDesignPostGPL
        |
OpenROAD.DetailedPlacement
        |
OpenROAD.CTS
        |
OpenROAD.STAMidPNR-1
        |
OpenROAD.ResizerTimingPostCTS
        |
OpenROAD.STAMidPNR-2
        |
OpenROAD.GlobalRouting
```

Lab 7 หยุดก่อน Global Routing

---

# 3. ทำไมแยก Placement กับ CTS

Placement ตอบ:

```text
logic cells อยู่ที่ไหน?
```

CTS ตอบ:

```text
clock ไปถึง sequential cells อย่างไร?
```

ถ้า placement ไม่ดี:

```text
clock tree ยาวขึ้น
skew control ยาก
signal wirelength สูง
congestion สูง
```

ดังนั้น CTS quality ขึ้นกับ placement quality

---

# 4. Global Placement คืออะไร

Global placement กระจาย standard cells ลงใน core แบบ continuous/approximate

ยังไม่ legal ทุก site

เป้าหมาย:

```text
ลด wirelength
ลด congestion
เคารพ density
เตรียม timing/routability
```

LibreLane/OpenROAD สามารถใช้ timing-driven และ routability-driven modes

---

# 5. Detailed Placement คืออะไร

Detailed placement ทำ legalization

เปลี่ยนจาก approximate positions เป็น:

```text
legal row
legal site
legal orientation
no overlap
```

หลัง step นี้ standard cells ควรมี physical locations ที่ concrete

---

# 6. CTS คืออะไร

Clock Tree Synthesis สร้าง tree ระหว่าง:

```text
clock source
```

กับ:

```text
clock sinks
```

โดยใช้ clock buffers/inverters ที่ PDK อนุญาต

เป้าหมายหลัก:

```text
control skew
control insertion delay
control transition
control fanout
```

---

# 7. Clock Source ของ Full Chip

core-only Lab ใช้:

```text
clk_i
```

แต่ full chip ใช้:

```text
clk_PAD
   |
sg13g2_IOPadIn
   |
clk_pad/p2c
   |
chip_core
   |
CPU clock sinks
```

LibreLane config:

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
```

ดังนั้น CTS ต้องเริ่มจาก internal clock net หลัง input pad

---

# 8. Baseline Frequency

```text
CLOCK_PERIOD = 20 ns
```

หรือ:

```text
50 MHz
```

เหตุผล:

```text
first full-chip physical closure
```

ควรเริ่มจาก conservative target ก่อนทำ frequency push

---

# 9. Placement Density

Lab ใช้:

```yaml
PL_TARGET_DENSITY_PCT: 20
```

หมายถึง global placer target ประมาณ 20% occupied density

ไม่ใช่:

```text
synthesis area / die area ต้องเท่ากับ 20%
```

---

# 10. ทำไม Density ต่ำ

CPU นี้มีขนาดเล็กเมื่อเทียบกับ:

```text
870 µm × 870 µm core
```

density ต่ำช่วย:

```text
legalization
routing headroom
CTS buffer insertion
timing repair buffer insertion
```

---

# 11. Placement Budget

รัน:

```bash
make placement-budget
```

core area:

```text
870 × 870 = 756900 µm²
```

20% geometry budget:

```text
151380 µm²
```

นี่เป็น teaching budget

ไม่ใช่ measured cell area

---

# 12. Routability-Driven Placement

baseline:

```yaml
PL_ROUTABILITY_DRIVEN: true
```

LibreLane ปัจจุบันใช้ routability-driven placement เพื่อช่วยลด congestion

เหมาะกับ full-chip design ที่มี:

```text
pad ring
PDN obstruction
core ring
```

---

# 13. Timing-Driven Placement Baseline

Lab ตั้ง:

```yaml
PL_TIMING_DRIVEN: false
```

เพื่อ baseline ที่อ่าน behavior ง่าย

เหตุผล:

```text
50 MHz target conservative
design small
ต้องการแยก placement effect จาก timing optimization
```

หลัง baseline สามารถทดลอง:

```yaml
PL_TIMING_DRIVEN: true
```

เป็น Lab extension

---

# 14. Detailed Placement Displacement

Lab ตั้ง:

```yaml
PL_MAX_DISPLACEMENT_X: 100
PL_MAX_DISPLACEMENT_Y: 100
```

อนุญาต legalization ให้ขยับ cell ได้พอสมควร

แต่ค่า exact behavior ขึ้นกับ OpenROAD/PDK

---

# 15. CTS Enable

```yaml
RUN_CTS: true
```

LibreLane `Chip` flow ปัจจุบันเปิด CTS เป็น default

Lab ใส่ explicit เพื่อ reproducibility

---

# 16. Post-CTS Timing Repair

```yaml
RUN_POST_CTS_RESIZER_TIMING: true
```

หลัง CTS clock arrival ไม่ ideal อีกต่อไป

resizer สามารถ:

```text
resize standard cells
insert buffers
repair hold/setup
```

จาก physical timing information หลัง clock tree

---

# 17. CTS Buffer Selection

Lab **ไม่ hard-code**:

```text
CTS_ROOT_BUFFER
CTS_CLK_BUFFERS
```

เพราะ variables เหล่านี้เป็น PDK-specific

IHP SG13G2 PDK ควรเป็น source of truth

ข้อดี:

```text
ไม่เดาชื่อ cells
ไม่ผูก Lab กับ library revision
```

---

# 18. CTS NDR

Lab ใช้:

```yaml
CTS_APPLY_NDR: half
```

LibreLane default ปัจจุบันคือ `half`

NDR หมายถึง non-default routing rule เช่นเพิ่ม spacing บน clock nets บางส่วน

เป้าหมาย:

```text
ลด coupling
เพิ่ม clock robustness
```

แต่ใช้ routing resource มากขึ้น

---

# 19. `CTS_APPLY_NDR` Options

ปัจจุบัน LibreLane รองรับ:

```text
none
root_only
half
full
```

Lab ใช้:

```text
half
```

เป็น baseline

---

# 20. CTS Wire-Length Controls

Lab ใช้:

```yaml
CTS_CLK_MAX_WIRE_LENGTH: 0
CTS_DISTANCE_BETWEEN_BUFFERS: 0
```

ค่า 0 หมายถึงปล่อย CTS/OpenROAD ใช้ characterization/default behavior

ไม่บังคับค่าที่เดาเอง

---

# 21. Directory Structure

```text
lab07_placement_cts/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB07_TH.md
│
├── rtl/
├── constraints/
├── ip/
│
├── config/
│   ├── cpu_source_manifest.txt
│   ├── pad_plan.yaml
│   ├── pdn_plan.yaml
│   └── placement_cts_plan.yaml
│
├── scripts/
│   ├── check_env.sh
│   ├── setup_bondpad.sh
│   ├── check_bondpad.py
│   ├── check_pad_plan.py
│   ├── check_pdn_plan.py
│   ├── check_placement_cts_plan.py
│   ├── placement_budget.py
│   ├── gen_config.py
│   ├── check_config.py
│   ├── check_run_log.py
│   ├── extract_stage_metrics.py
│   └── build_report.py
│
├── openroad/
├── build/
└── reports/
```

---

# 22. Step 1 — เข้า Environment

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

จากนั้น:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab07_placement_cts
```

---

# 23. Step 2 — Setup Bondpad

```bash
make setup-bondpad
```

เหมือน Lab 5–6

ใช้ GDS/LEF จริง

---

# 24. Step 3 — Environment Check

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

และควรมี:

```text
openroad
```

สำหรับ GUI

---

# 25. Step 4 — Validate Frozen Pad Ring

```bash
make check-pad-plan
```

ยังต้อง:

```text
18 pads
no duplicates
no unknown instances
```

---

# 26. Step 5 — Validate Frozen PDN

```bash
make check-pdn-plan
```

ต้องยังมี:

```text
core ring enabled
ring-to-pads enabled
15 µm widths
5 µm spacing
```

Lab 7 ไม่ควรเปลี่ยน PDN ระหว่างศึกษาผล placement/CTS

---

# 27. Step 6 — Check Placement/CTS Plan

```bash
make check-place-plan
```

expected:

```text
PASS PL_TARGET_DENSITY_PCT = 20
PASS PL_ROUTABILITY_DRIVEN = true
PASS PL_TIMING_DRIVEN = false
PASS RUN_CTS = true
PASS RUN_POST_CTS_RESIZER_TIMING = true
PASS CTS_APPLY_NDR = half
```

---

# 28. Step 7 — Placement Budget

```bash
make placement-budget
```

ใช้เป็น sanity check ว่า floorplan มี headroom มาก

---

# 29. Step 8 — Generate Config

```bash
make gen-config
```

output:

```text
build/config.yaml
```

config นี้รวม:

```text
RTL
pad ring
PDN
clock
placement
CTS
bondpad
```

---

# 30. Step 9 — Config Check

```bash
make check-config
```

ตรวจ:

```text
clock
density
routability
CTS
post-CTS repair
NDR
PDN
```

---

# 31. Step 10 — Full Preflight

```bash
make preflight
```

ต้องได้:

```text
LAB 7 PREFLIGHT PASS
```

ก่อน run OpenROAD placement

---

# 32. Step 11 — Global Placement

```bash
make global-placement
```

หยุด:

```text
OpenROAD.GlobalPlacement
```

---

# 33. สิ่งที่ Global Placement ใช้

placer ต้องพิจารณา:

```text
cell netlist
core rows
PDN/pad obstructions
density
wirelength
routability
```

ยังไม่มี final detailed routing

---

# 34. Inspect Global Placement

เปิด ODB/DEF

ตรวจ:

```text
cells อยู่ใน core
ไม่กองมุมเดียว
ไม่มี cluster ผิดธรรมชาติ
เว้น obstructions
distribution สมเหตุผล
```

---

# 35. Global Placement ไม่ต้อง Legal ทุก Cell

อย่า fail Lab เพราะ cell ยังไม่ได้ snap final site

legalization เป็นงานของ:

```text
OpenROAD.DetailedPlacement
```

---

# 36. Step 12 — Check Global Placement Log

```bash
make check-global-placement
```

log checker จับ:

```text
ERROR
placement failed
legalization failed
unmapped
```

แต่ visual inspection ยังจำเป็น

---

# 37. Step 13 — Mid-PnR STA หลัง Global Placement

Chip flow จะทำ:

```text
OpenROAD.STAMidPNR
```

หลัง GPL

timing เริ่มมี physical distance estimate มากกว่า pre-PnR

แต่ยังไม่มี CTS

clock ยังมี ideal/estimated behavior ตาม stage

---

# 38. Repair Design Post GPL

flow มี:

```text
OpenROAD.RepairDesignPostGPL
```

ใช้ repair:

```text
fanout
slew
capacitance
physical timing issues
```

อาจเพิ่ม buffer/resize cells ก่อน detailed placement

---

# 39. Step 14 — Detailed Placement

```bash
make detailed-placement
```

หยุด:

```text
OpenROAD.DetailedPlacement
```

---

# 40. Detailed Placement Pass Criteria

ต้อง:

```text
all standard cells legal
inside rows
no overlap
valid orientation
```

ถ้ามี cell overlap:

```text
CTS ยังไม่ควรเริ่ม
```

---

# 41. Inspect Detailed Placement

zoom เข้า:

```text
row boundaries
PDN rails
cell rows
cell orientations
```

ควรเห็น standard cells snap เป็น rows

---

# 42. Step 15 — Check Detailed Placement

```bash
make check-detailed-placement
```

และ inspect GUI

---

# 43. Step 16 — Run CTS

```bash
make cts
```

หยุด:

```text
OpenROAD.CTS
```

LibreLane CTS จะสร้าง clock tree บน detailed-placed ODB และทำ detailed placement อีกครั้งเพื่อรองรับ inserted clock cells

---

# 44. Clock Sinks คืออะไร

clock sinks คือ sequential endpoints ที่ต้องรับ clock

เช่น:

```text
PC register flops
register-file flops
other state registers
```

จำนวน sink ไม่เท่ากับจำนวน RTL registers เสมอ

เพราะ synthesis mapping อาจ pack/map ต่างกัน

---

# 45. Clock Tree Structure

conceptually:

```text
clk_pad/p2c
     |
  root buffer
     |
  +--+--------+
  |           |
 buffer     buffer
  |           |
 sinks       sinks
```

tree จริงขึ้นกับ placement

---

# 46. Insertion Delay / Latency

เวลาเดินทาง:

```text
clock source
   ->
sink
```

เรียกว่า clock insertion delay/latency

CTS เพิ่ม delay โดยตั้งใจเพื่อให้ distribution controllable

---

# 47. Clock Skew

สำหรับ sinks A/B:

```text
skew = arrival(A) - arrival(B)
```

เป้าหมายทั่วไป:

```text
|skew| เล็ก
```

แต่ skew ต่ำที่สุดไม่ใช่ objective เดียว

ต้อง balance:

```text
power
buffer count
slew
latency
routing
```

---

# 48. Why CTS Changes Timing

ก่อน CTS:

```text
clock tree ยัง ideal/estimated
```

หลัง CTS:

```text
real clock cells
real insertion delay
non-zero skew
```

ดังนั้น setup/hold slack เปลี่ยนได้

---

# 49. Setup Timing หลัง CTS

setup constraint conceptual:

```text
data arrival <= capture clock edge - setup
```

clock skew สามารถช่วยหรือทำร้าย setup ได้ขึ้นกับ direction

---

# 50. Hold Timing หลัง CTS

hold checks สนใจ minimum data delay หลัง launch edge

หลัง CTS hold violations มักเห็นชัดขึ้นเพราะ real clock arrival differences

---

# 51. Step 17 — Check CTS

```bash
make check-cts
```

แล้ว inspect:

```text
clock tree exists
buffer instances
sink connectivity
physical distribution
```

---

# 52. CTS Buffer Count

buffer count มากเกินอาจหมายถึง:

```text
sink distribution poor
aggressive constraints
long clock paths
large core
```

แต่ไม่มี magic universal number

ต้องเทียบกับ:

```text
sink count
core geometry
PDK buffer choices
clock target
```

---

# 53. Step 18 — Post-CTS STA + Timing Repair

รัน:

```bash
make postcts
```

Lab stop:

```text
OpenROAD.STAMidPNR-2
```

ดังนั้น flow ผ่าน:

```text
CTS
STAMidPNR-1
ResizerTimingPostCTS
STAMidPNR-2
```

---

# 54. ทำไมมี STA สองครั้งหลัง CTS

ครั้งแรก:

```text
วัด timing หลัง clock tree
```

จากนั้น:

```text
post-CTS resizer repair
```

แล้ว STA อีกครั้ง:

```text
วัดผลหลัง repair
```

นี่ช่วยตอบ:

```text
repair ดีขึ้นหรือแย่ลง?
```

---

# 55. Post-CTS Resizer ทำอะไร

LibreLane อธิบายว่า post-CTS timing optimization สามารถ:

```text
resize standard cells
insert buffers
repair hold
repair setup
```

ด้วย timing information หลัง CTS

---

# 56. Step 19 — Extract Convenience Metrics

```bash
make metrics
```

สร้าง:

```text
reports/12_stage_metrics.txt
```

พยายามดึง:

```text
WNS
TNS
skew
clock-buffer count
```

จาก console logs

---

# 57. Metrics Parser Caveat

parser นี้เป็น convenience

อย่าใช้ค่าที่ parse ได้เพื่อ publication โดยไม่ cross-check:

```text
OpenROAD timing reports
CTS reports
metrics JSON
ODB
```

---

# 58. Recommended Timing Table

บันทึก:

| Stage | WNS | TNS | Hold status | Clock skew | Clock buffers |
|---|---:|---:|---|---:|---:|
| Post GPL | measured | measured | measured | N/A | 0 |
| Post CTS | measured | measured | measured | measured | measured |
| Post CTS Repair | measured | measured | measured | measured | measured |

---

# 59. ถ้า 50 MHz Setup Fail หลัง CTS

อย่าเพิ่ม clock periodทันที

ตรวจ:

```text
critical path
cell placement
clock skew
clock latency
fanout
buffer insertion
constraint assumptions
```

เพราะ target 50 MHz ค่อนข้าง conservative สำหรับ CPU เล็ก

failure อาจบอก configuration problem

---

# 60. ถ้า Hold Fail หลัง CTS

hold repair มักต้อง:

```text
add delay buffers
resize cells
change path delay
```

`ResizerTimingPostCTS` มีหน้าที่ช่วยเรื่องนี้

อย่าแก้ hold โดยลด clock frequency

เพราะ hold โดยหลักไม่ถูกแก้ด้วย period ที่ยาวขึ้น

---

# 61. Setup vs Hold

จำ:

```text
setup = maximum-delay problem
hold  = minimum-delay problem
```

แก้ไม่เหมือนกัน

---

# 62. Troubleshooting — Global Placement Diverges

ตรวจ:

```text
density
PDN obstruction
core area
PL_ROUTABILITY_DRIVEN
phi coefficients only if necessary
```

อย่าปรับ advanced coefficients ก่อนดู geometry

---

# 63. Troubleshooting — Placement Congested

CPU มีพื้นที่ core มาก

ถ้ายัง congest:

```text
inspect PDN
pad/ring blockages
cell clustering
routing layer availability
```

ก่อนเพิ่ม die

---

# 64. Troubleshooting — Detailed Placement Fail

สาเหตุทั่วไป:

```text
not enough legal sites
cell padding too high
obstructions
bad row geometry
over-density
```

---

# 65. Troubleshooting — Clock Not Found

ตรวจ:

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
```

และ synthesized hierarchy

ถ้า Slang/hierarchy เปลี่ยนชื่อ net ต้องใช้ชื่อจริงจาก database

---

# 66. Troubleshooting — CTS Root Buffer Missing

Lab ไม่ hard-code root buffer

ถ้า CTS บอก PDK ไม่มี:

```text
CTS_ROOT_BUFFER
```

หรือ buffer list:

ตรวจ IHP PDK configuration และ LibreLane installation

อย่าเดาชื่อ standard cell

---

# 67. Troubleshooting — Too Many CTS Buffers

ตรวจ:

```text
clock sink distribution
core area
target period
max slew/cap
CTS characterization
CTS distance settings
```

baseline ใช้ 0 สำหรับ wire-length/distance overrides เพื่อไม่บังคับผิด

---

# 68. Troubleshooting — Post-CTS Resizer Adds Many Buffers

ดูว่าเป็น:

```text
hold buffers
setup buffers
slew/fanout repair
```

ต่างกัน

ถ้า hold buffers จำนวนมาก:

```text
inspect clock skew
short data paths
clock topology
```

---

# 69. Troubleshooting — CTS Placement Overlap

LibreLane CTS re-runs detailed placementหลังเพิ่ม clock cells

ถ้ายัง overlap:

```text
legalization failure
core density
obstruction
padding
```

---

# 70. Visual Inspection — Global Placement

ต้องตอบได้:

```text
logic กระจายตัวหรือไม่?
มี hotspot หรือไม่?
PDN ถูกเคารพหรือไม่?
```

---

# 71. Visual Inspection — Detailed Placement

ต้องตอบ:

```text
cells legal ทุกตัวหรือไม่?
rows ถูกต้องหรือไม่?
มี overlap หรือไม่?
```

---

# 72. Visual Inspection — CTS

ต้องตอบ:

```text
clock tree มีจริงหรือไม่?
root จาก internal clock net ถูกต้องหรือไม่?
branches ไปถึง sinks หรือไม่?
buffer distribution สมเหตุผลหรือไม่?
```

---

# 73. Clock Tree ไม่ควรรันผ่าน Pad Boundary ผิด

clock pad เป็น physical boundary

tree ควรเริ่มจาก:

```text
internal p2c side
```

ไม่ใช่ package-side pad metal

---

# 74. NDR Tradeoff

NDR spacing มากขึ้น:

```text
coupling ลด
robustness เพิ่ม
routing resource ลด
```

จึงไม่ควรใช้ `full` โดยไม่วัด

---

# 75. Extension Experiment — Timing Driven Placement

หลัง baseline:

```yaml
PL_TIMING_DRIVEN: true
```

rerun:

```text
GPL
DPL
CTS
post-CTS
```

compare:

```text
WNS
TNS
wirelength
congestion
buffer count
```

---

# 76. Extension Experiment — CTS NDR

ทดลอง:

```text
none
root_only
half
full
```

วัด:

```text
clock skew
clock routing resource
buffer count
later routing congestion
```

---

# 77. Extension Experiment — Density

ทดลอง:

```text
10%
20%
30%
40%
```

แต่ใช้:

```text
same RTL
same PDK
same clock
```

เพื่อ isolation

---

# 78. Recommended Run Sequence

```bash
make clean
make setup-bondpad
make preflight

make global-placement
make check-global-placement

make detailed-placement
make check-detailed-placement

make cts
make check-cts

make postcts
make check-postcts

make metrics
make report
```

---

# 79. Fast Run

เมื่อ upstream stable:

```bash
make all
```

---

# 80. Pass Criteria — Placement

```text
[ ] GlobalPlacement completes
[ ] no cells outside core
[ ] no pathological clustering
[ ] DetailedPlacement completes
[ ] cells legalized
[ ] no visible overlaps
[ ] PDN/pad obstructions respected
```

---

# 81. Pass Criteria — CTS

```text
[ ] clock source resolved
[ ] OpenROAD.CTS completes
[ ] clock buffers inserted
[ ] sinks are clocked
[ ] no fatal CTS errors
[ ] clock tree physically plausible
[ ] skew reported/inspected
[ ] post-CTS STA completes
```

---

# 82. Pass Criteria — Timing Repair

```text
[ ] ResizerTimingPostCTS runs
[ ] post-repair STA runs
[ ] setup status recorded
[ ] hold status recorded
[ ] WNS/TNS recorded
[ ] buffer growth reviewed
```

Lab workflow ผ่านได้แม้ timing target miss ถ้าผลถูกบันทึกและตีความ

แต่ไม่ควรเข้าสู่ signoff โดยไม่แก้ violations

---

# 83. Deliverables

```text
config/placement_cts_plan.yaml
build/config.yaml

reports/
├── 00_environment.log
├── 01_expected_pad_instances.txt
├── 02_pad_plan_check.txt
├── 03_bondpad_check.txt
├── 04_pdn_plan_check.txt
├── 05_placement_cts_plan_check.txt
├── 06_placement_budget.txt
├── 07_config_check.txt
├── 08_global_placement_check.txt
├── 09_detailed_placement_check.txt
├── 10_cts_check.txt
├── 11_postcts_check.txt
├── 12_stage_metrics.txt
└── LAB07_REPORT.md
```

และ ODB/DEF จาก:

```text
GlobalPlacement
DetailedPlacement
CTS
STAMidPNR-2
```

---

# 84. Design Review Questions

1. Global placement กับ detailed placement ต่างกันอย่างไร?
2. ทำไม CTS ต้องทำหลัง detailed placement?
3. clock latency กับ skew ต่างกันอย่างไร?
4. ทำไม hold violation ไม่แก้ด้วยการลด frequency?
5. ทำไม Lab ไม่ hard-code CTS buffer cell names?
6. `CTS_APPLY_NDR: half` มี tradeoff อะไร?
7. Post-CTS timing ต่างจาก pre-PnR timing อย่างไร?
8. ทำไม CTS อาจทำให้ setup timing แย่ลง?
9. ทำไม post-CTS repair อาจเพิ่ม cell count?
10. ถ้า flow success แต่ clock tree ไม่ถึง sink บางตัว Lab ผ่านหรือไม่?

ข้อ 10:

```text
ไม่ผ่าน
```

---

# 85. Freeze หลัง Lab 7

เมื่อ Lab ผ่านให้ freeze:

```text
placement density
placement strategy
legalized placement
clock source/net
CTS PDK buffer policy
CTS NDR strategy
clock tree topology
clock buffer count
post-CTS setup/hold baseline
```

---

# 86. Transition ไป Lab 8

Lab ต่อไปควรเป็น:

```text
Lab 8 — Global Routing and Detailed Routing
```

โดยเริ่มจาก:

```text
placed cells
+
real clock tree
+
post-CTS timing repaired design
```

แล้วสร้าง:

```text
global routing guides
antenna checks
detailed routing
DRC
post-route timing
```

---

# 87. Engineering Rule

> Placement ที่ legal ไม่ได้แปลว่า placement ที่ดี

และ:

> Clock tree ที่สร้างสำเร็จไม่ได้แปลว่า clock tree ที่มีคุณภาพ

ต้องดูร่วมกัน:

```text
geometry
congestion
timing
skew
buffer count
setup
hold
```

ก่อนเดินเข้าสู่ routing
