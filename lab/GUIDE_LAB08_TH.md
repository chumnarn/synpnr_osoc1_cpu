# Lab 8 — Global Routing and Detailed Routing
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Top:** `chip_top`  
**PDK:** IHP SG13G2  
**Flow:** LibreLane `Chip`  
**Clock:** 50 MHz / 20 ns  
**Global-routing congestion policy:** clean baseline, congestion not allowed  
**Antenna repair:** enabled  
**Detailed routing:** enabled  
**Final Lab endpoint:** `OpenROAD.STAPostPNR`

---

# 1. เป้าหมายของ Lab

Lab 7 จบที่:

```text
legal placement
+
clock tree
+
post-CTS timing repair
```

แต่ nets ส่วนใหญ่ยังไม่มี physical metal wire ที่ final

Lab 8 เปลี่ยน:

```text
logical connectivity
```

เป็น:

```text
routing guides
+
physical wires
+
vias
+
post-route RC
```

จึงเป็นจุดที่ design เริ่มมี interconnect delay ที่ใกล้ physical reality มากขึ้น

---

# 2. Routing Flow ปัจจุบัน

LibreLane `Chip` flow หลัง post-CTS มีลำดับสำคัญ:

```text
OpenROAD.GlobalRouting
OpenROAD.CheckAntennas
OpenROAD.RepairDesignPostGRT
Odb.DiodesOnPorts
Odb.HeuristicDiodeInsertion
OpenROAD.RepairAntennas
OpenROAD.ResizerTimingPostGRT
OpenROAD.STAMidPNR-3
OpenROAD.DetailedRouting
Odb.RemoveRoutingObstructions
OpenROAD.CheckAntennas-1
Checker.TrDRC
Odb.ReportDisconnectedPins
Checker.DisconnectedPins
Odb.ReportWireLength
Checker.WireLength
OpenROAD.FillInsertion
Odb.CellFrequencyTables
OpenROAD.RCX
OpenROAD.STAPostPNR
```

Lab ใช้ checkpoints สำคัญจาก flow นี้

---

# 3. Global Routing คืออะไร

Global Routing ไม่วาด final wires

มันแบ่ง die/core เป็น coarse routing regions หรือ GCells แล้วกำหนด:

```text
net ควรเดินผ่าน region ไหน
ควรใช้ layer ไหนโดยประมาณ
routing demand/capacity เป็นอย่างไร
```

output หลัก:

```text
routing guides
ODB
DEF
```

---

# 4. Detailed Routing คืออะไร

Detailed Routing เปลี่ยน routing guides ให้เป็น:

```text
exact metal segments
exact vias
exact tracks
```

และต้อง:

```text
respect design rules
avoid shorts
connect all routed pins
```

LibreLane ระบุว่า Detailed Routing เป็นหนึ่งในขั้นที่ใช้เวลามากที่สุดของ flow

---

# 5. Global vs Detailed Routing

```text
Global Routing
= planning

Detailed Routing
= physical realization
```

เปรียบเทียบ:

```text
Global:
net A -> corridor X -> layer region Y

Detailed:
Metal2 x1,y1 to x2,y2
via M2/M3
Metal3 ...
```

---

# 6. ทำไม Congestion สำคัญ

routing resource มีจำกัด

ในแต่ละ GCell/layer มี:

```text
capacity
```

และ nets สร้าง:

```text
demand
```

เมื่อ:

```text
demand > capacity
```

เกิด:

```text
overflow / congestion
```

---

# 7. Clean Baseline Policy

Lab ตั้ง:

```yaml
GRT_ALLOW_CONGESTION: false
```

เพราะนี่เป็น small CPU + large core

ถ้า design นี้ยัง global-route ไม่ clean เราควรหาสาเหตุ

ไม่ควรอนุญาต congestion เพื่อเพียงให้ flow เดินต่อ

---

# 8. `GRT_ADJUSTMENT`

baseline:

```yaml
GRT_ADJUSTMENT: 0.3
```

LibreLane นิยามเป็นการลด routing capacity ของ global-routing graph

range:

```text
0 = ลดน้อย
1 = ลดมาก
```

default ปัจจุบัน:

```text
0.3
```

Lab จึง freeze default เพื่อ reproducibility

---

# 9. ทำไมต้อง Reduce Capacity

ถ้า global router ใช้ theoretical capacity เต็ม:

```text
detailed router อาจไม่มี margin
```

capacity adjustment ช่วยเผื่อ:

```text
design rules
via blockage
local complexity
```

---

# 10. Routing Layers

Lab ไม่ hard-code:

```text
RT_MIN_LAYER
RT_MAX_LAYER
RT_CLOCK_MIN_LAYER
RT_CLOCK_MAX_LAYER
```

เพราะ layer availability เป็น PDK-specific

IHP SG13G2 PDK ต้องเป็น source of truth

นี่ช่วยหลีกเลี่ยงปัญหาแบบ:

```text
invalid routing layer
met5 not found
```

จากการนำ config ของ PDK อื่นมาใช้

---

# 11. Antenna Effect

ระหว่าง fabrication long metal สามารถสะสม charge

ถ้า charge path ต่อกับ MOS gate oxide:

```text
gate oxide อาจเสียหาย
```

นี่เรียกว่า process antenna effect

ไม่เกี่ยวกับ RF antenna

---

# 12. Antenna Check

LibreLane step:

```text
OpenROAD.CheckAntennas
```

อัปเดต metric:

```text
route__antenna_violation__count
```

จำนวน violating nets ควรถูกบันทึกก่อนและหลัง repair

---

# 13. Antenna Repair

Lab เปิด:

```yaml
RUN_ANTENNA_REPAIR: true
```

LibreLane จะเรียก:

```text
OpenROAD.RepairAntennas
```

repair อาจใช้:

```text
jumpers
antenna diodes
```

ตาม PDK/library/flow capability

---

# 14. Antenna Repair Iterations

```yaml
GRT_ANTENNA_REPAIR_ITERS: 3
```

ปัจจุบัน default = 3

จึงใช้เป็น baseline

---

# 15. Antenna Repair Margin

```yaml
GRT_ANTENNA_REPAIR_MARGIN: 10
```

ใช้ margin เพื่อ over-fix antenna ratio บางส่วน

baseline เท่ากับ default ปัจจุบัน

---

# 16. Jumper-only / Diode-only

Lab ใช้:

```yaml
GRT_ANTENNA_REPAIR_JUMPER_ONLY: false
GRT_ANTENNA_REPAIR_DIODE_ONLY: false
```

จึงไม่บังคับ repair mechanism เพียงแบบเดียว

ให้ OpenROAD/PDK เลือกตาม capability

---

# 17. Post-GRT Timing Resizer

LibreLane มี:

```yaml
RUN_POST_GRT_RESIZER_TIMING
```

แต่ปัจจุบันยังระบุว่า experimental และอาจ hang/run นาน

Lab baseline จึงใช้:

```yaml
RUN_POST_GRT_RESIZER_TIMING: false
```

เพื่อให้ routing experiment stable ก่อน

---

# 18. Detailed Routing Enable

```yaml
RUN_DRT: true
```

ทำให้ Chip flow เรียก:

```text
OpenROAD.DetailedRouting
```

---

# 19. Directory Structure

```text
lab08_routing/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB08_TH.md
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
│   └── routing_plan.yaml
│
├── scripts/
│   ├── setup_bondpad.sh
│   ├── check_env.sh
│   ├── check_bondpad.py
│   ├── check_pad_plan.py
│   ├── check_pdn_plan.py
│   ├── check_placement_cts_plan.py
│   ├── check_routing_plan.py
│   ├── gen_config.py
│   ├── check_config.py
│   ├── check_run_log.py
│   ├── extract_routing_metrics.py
│   ├── routing_review_template.py
│   └── build_report.py
│
├── openroad/
├── build/
├── reports/
└── results/
```

---

# 20. Step 1 — Enter Environment

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

จากนั้น:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab08_routing
```

---

# 21. Step 2 — Setup Bondpad

```bash
make setup-bondpad
```

ใช้ real GDS/LEF

---

# 22. Step 3 — Check Environment

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

ควรมี:

```text
openroad
klayout
```

สำหรับ inspection

---

# 23. Step 4 — Validate Upstream Frozen State

รัน:

```bash
make check-pad-plan
make check-pdn-plan
make check-place-plan
```

เหตุผล:

Lab 8 ควรเปลี่ยน routing variables เท่านั้น

ถ้า pad/PDN/CTS config เปลี่ยนพร้อมกัน การเปรียบเทียบผล routing จะไม่ clean

---

# 24. Step 5 — Check Routing Plan

```bash
make check-route-plan
```

expected:

```text
GRT_ADJUSTMENT = 0.3
GRT_ALLOW_CONGESTION = false
RUN_ANTENNA_REPAIR = true
RUN_POST_GRT_RESIZER_TIMING = false
RUN_DRT = true
```

---

# 25. Step 6 — Generate Config

```bash
make gen-config
```

สร้าง:

```text
build/config.yaml
```

ซึ่งรวม frozen state จาก Labs 5–7 และ routing policy ใหม่

---

# 26. Step 7 — Check Config

```bash
make check-config
```

ตรวจ:

```text
clock
CTS
PDN
routing capacity
antenna repair
DRT
bondpad
```

---

# 27. Step 8 — Create Review Checklist

```bash
make review-template
```

สร้าง:

```text
results/ROUTING_REVIEW.md
```

ผู้เรียนต้องกรอกจากผลจริง

---

# 28. Step 9 — Full Preflight

```bash
make preflight
```

ต้องได้:

```text
LAB 8 PREFLIGHT PASS
```

---

# 29. Step 10 — Global Routing

```bash
make global-routing
```

command:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow Chip \
  --run-tag lab08_global_routing \
  --to OpenROAD.GlobalRouting \
  build/config.yaml
```

---

# 30. สิ่งที่ต้องดูจาก Global Routing

อย่างน้อย:

```text
overflow
congestion hotspots
routing guide coverage
clock route guide
pad-to-core corridors
PDN blockage interaction
```

---

# 31. Overflow

ideal baseline:

```text
overflow = 0
```

เพราะ:

```yaml
GRT_ALLOW_CONGESTION: false
```

ถ้า overflow ไม่ clean flow อาจหยุด

นี่เป็น intentional gate

---

# 32. Congestion Heatmap

ใน OpenROAD GUI ให้เปิด congestion/routing view ถ้ามี

ดู:

```text
red/high-demand regions
pad exits
core-ring crossings
clock tree neighborhoods
dense logic clusters
```

---

# 33. Pad-to-Core Routing

full chip แตกต่างจาก core-only block เพราะ output nets ต้องเดิน:

```text
core
 ->
I/O pad
```

ระยะอาจยาวและผ่าน ring/PDN region

ตรวจว่า routing corridor ไม่ถูกปิดด้วย obstruction

---

# 34. Clock Routing

CTS สร้าง clock topology แล้ว

Global Routing ต้องหา guides ให้ clock nets

ถ้า clock NDR ใช้ `half` จาก Lab 7:

```text
clock routing capacity usage อาจสูงกว่าสัญญาณธรรมดา
```

---

# 35. Step 11 — Check Global Routing Log

```bash
make check-global-routing
```

และ inspect GUI

log pass อย่างเดียวไม่พอ

---

# 36. Step 12 — Initial Antenna Check/Repair

รัน:

```bash
make antenna
```

endpoint:

```text
OpenROAD.RepairAntennas
```

flow จะผ่าน:

```text
GlobalRouting
CheckAntennas
RepairDesignPostGRT
...
RepairAntennas
```

---

# 37. Record Antenna Count

ก่อน repair:

```text
route__antenna_violation__count
```

ควรถูกบันทึก

หลัง Detailed Routing จะมี CheckAntennas อีกรอบ

จึงสามารถ compare:

```text
pre-repair
post-repair/post-route
```

---

# 38. Antenna Repair ไม่ใช่ Free

การเพิ่ม diode/jumper อาจ:

```text
เพิ่ม cell area
เพิ่ม capacitance
เพิ่ม routing
กระทบ timing
```

ดังนั้นต้องบันทึกผล ไม่ใช่แค่จำนวน violation

---

# 39. Step 13 — Check Antenna Repair

```bash
make check-antenna
```

แล้ว inspect:

```text
diode cells
jumpers
changed routing
```

ถ้ามี

---

# 40. RepairDesignPostGRT

ก่อน antenna repair flow มี:

```text
OpenROAD.RepairDesignPostGRT
```

ใช้ global-route information เพื่อ repair physical design issues

จึงอาจทำให้:

```text
netlist
placement
buffers
```

เปลี่ยนจาก post-CTS state

---

# 41. Step 14 — Detailed Routing

```bash
make detailed-routing
```

endpoint:

```text
OpenROAD.DetailedRouting
```

นี่คือ main physical-routing realization

---

# 42. Detailed Router Output

ต้องมี:

```text
exact wires
exact vias
layer assignments
connected nets
```

หลังขั้นนี้ cell movement ปกติไม่ควรเกิดอีกโดยไม่มี custom rip-up/re-route strategy

---

# 43. Inspect Detailed Route

ตรวจ:

```text
all output nets
clock
reset
local datapath nets
vias
layer transitions
pad connections
```

---

# 44. Open vs Short

routing correctness ขั้นพื้นฐาน:

```text
open = net ที่ควรต่อแต่ไม่ต่อ

short = nets ที่ไม่ควรต่อแต่ถูกเชื่อม
```

ทั้งสอง critical

---

# 45. Step 15 — Post-route Antenna Check

Chip flow จะเรียก:

```text
OpenROAD.CheckAntennas-1
```

หลัง Detailed Routing

นี่สำคัญกว่า global-route estimate เพราะมี final route geometry มากขึ้น

---

# 46. Step 16 — TrDRC

รัน:

```bash
make trdrc
```

endpoint:

```text
Checker.TrDRC
```

นี่ตรวจ detailed-router DRC result

ไม่ใช่ final signoff KLayout/Magic DRC

---

# 47. Route DRC vs Signoff DRC

`Checker.TrDRC`:

```text
routing-stage rule/violation checker
```

Signoff DRC:

```text
full layout GDS
foundry/signoff rule deck
```

ดังนั้น TrDRC=0 ยังไม่เท่ากับ final DRC clean

---

# 48. Step 17 — Check TrDRC

```bash
make check-trdrc
```

ถ้ามี violations ต้อง locate markers

อย่าเพียงเพิ่ม detailed-routing iterations โดยไม่ดู violation class

---

# 49. Disconnected Pins

หลัง TrDRC flow มี:

```text
Odb.ReportDisconnectedPins
Checker.DisconnectedPins
```

ต้อง review ว่า:

```text
signal pins connected
clock sinks connected
expected power structures intact
```

---

# 50. Wire-Length Check

flow มี:

```text
Odb.ReportWireLength
Checker.WireLength
```

long net อาจบอก:

```text
poor placement
far I/O connection
clock topology issue
```

---

# 51. Fill Insertion

ก่อน RC extraction flow มี:

```text
OpenROAD.FillInsertion
```

filler cells fill gaps ใน standard-cell rows

ช่วย:

```text
well continuity
power rail continuity
physical row completion
```

ตาม library behavior

---

# 52. RC Extraction

step:

```text
OpenROAD.RCX
```

สร้าง parasitic estimate/extraction จาก routed geometry

หลังนี้ timing มี interconnect R/C ที่ realistic กว่า pre-route stages

---

# 53. Step 18 — Post-Route STA

รัน:

```bash
make postroute
```

endpoint:

```text
OpenROAD.STAPostPNR
```

flow จะผ่าน:

```text
Detailed Routing
route checks
fill
RCX
STAPostPNR
```

---

# 54. Post-Route STA สำคัญอย่างไร

ก่อน routing:

```text
wire parasitics estimated
```

หลัง RCX:

```text
actual routed length/layer/via structure
```

ถูกใช้คำนวณ timing

จึงควรคาดว่า WNS/TNS เปลี่ยน

---

# 55. Compare Timing Stages

ตาราง:

| Stage | WNS | TNS | Hold | RC realism |
|---|---:|---:|---|---|
| Pre-PnR | measured | measured | measured | low |
| Post-GPL | measured | measured | measured | medium-low |
| Post-CTS | measured | measured | measured | medium |
| Post-Route | measured | measured | measured | high |

---

# 56. Step 19 — Extract Metrics

```bash
make metrics
```

สร้าง:

```text
reports/12_routing_metrics.txt
```

พยายามดึง:

```text
overflow
antenna count
DRC count
wire length
WNS
TNS
```

จาก logs

---

# 57. Metrics Parser Qualification

ต้อง cross-check:

```text
LibreLane metrics JSON
OpenROAD reports
antenna report
TrDRC report
STA report
```

ก่อนใส่ publication

---

# 58. Step 20 — Open Detailed Route in OpenROAD

LibreLane รองรับการเปิด earlier state ด้วย:

```bash
librelane \
  --with-initial-state \
  <RUN>/*-openroad-detailedrouting/state_out.json \
  --flow OpenInOpenROAD \
  <RUN>/resolved.json
```

ใช้ exact run path จริง

---

# 59. Open Detailed Route in KLayout

สำหรับ DEF preview:

```bash
librelane \
  --with-initial-state \
  <RUN>/*-openroad-detailedrouting/state_out.json \
  --flow OpenInKLayout \
  <RUN>/resolved.json
```

นี่ไม่จำเป็นต้องรอ final GDS

---

# 60. Troubleshooting — Global Routing Congestion

ถ้า congestion:

ตรวจตามลำดับ:

```text
placement hotspot
PDN blockage
pad exit
clock NDR
routing layer availability
GRT_ADJUSTMENT
```

อย่าเริ่มด้วย:

```yaml
GRT_ALLOW_CONGESTION: true
```

เพียงเพื่อ bypass gate

---

# 61. Troubleshooting — GRT Adjustment

`GRT_ADJUSTMENT` สูงขึ้น:

```text
usable capacity ลด
router conservative ขึ้น
```

ต่ำลง:

```text
usable capacity เพิ่ม
แต่ detailed router อาจรับภาระมากขึ้น
```

ทดลองเป็น controlled experiment

---

# 62. Troubleshooting — Invalid Routing Layer

ถ้าเห็น:

```text
invalid routing layer
met5 not found
```

แสดงว่า config ไป hard-code layer ที่ PDK ไม่รองรับหรือ naming ผิด

Lab นี้จึงไม่ set route layers เอง

ตรวจ PDK config ก่อน

---

# 63. Troubleshooting — Antenna Remains

ตรวจ:

```text
repair iterations
diode availability
jumper strategy
routing topology
```

อย่าปิด antenna checker

---

# 64. Troubleshooting — Too Many Diodes

ถ้า diode repair เพิ่มมาก:

```text
timing capacitance เพิ่ม
placement/routing เพิ่ม
```

ดู antenna margin และ routing structure

---

# 65. Troubleshooting — Detailed Routing Fails

สาเหตุ:

```text
global-route congestion
DRC complexity
insufficient tracks
via conflicts
pad/PDN obstruction
clock NDR pressure
```

ย้อนกลับไปดู GRT ก่อน

---

# 66. Troubleshooting — DRC Count > 0

classify violation:

```text
spacing
short
min-area
via enclosure
off-grid
```

วิธีแก้ต่างกัน

ไม่ควรใช้ global “ignore DRC”

---

# 67. Troubleshooting — Disconnected Pin

หา:

```text
pin name
net name
instance
```

แล้ว inspect route

signal disconnected ไม่ควรผ่านไป signoff

---

# 68. Troubleshooting — Post-Route Setup Fail

ตรวจ:

```text
wire delay
critical path
clock latency/skew
long net
cell drive
load
```

routing อาจเพิ่ม interconnect delay อย่างมาก

---

# 69. Troubleshooting — Post-Route Hold Fail

ดู:

```text
minimum data paths
clock skew
route detour
post-CTS hold repair effectiveness
```

hold ไม่แก้ด้วยลด frequency

---

# 70. Visual Review — Signal Routes

zoom net:

```text
output_core -> output pad
```

ดู:

```text
metal layers
vias
route length
PDN crossings
```

---

# 71. Visual Review — Clock Route

clock ควร:

```text
connect CTS tree
use intended NDR behavior
avoid pathological detour
reach all sinks
```

---

# 72. Visual Review — Reset

reset เป็น high-fanout asynchronous control

ดู route ว่า:

```text
ไม่มี disconnected branch
ไม่มี extreme detour
```

---

# 73. Routing Quality ไม่ใช่แค่ DRC

routing ที่ DRC clean อาจยัง:

```text
timing bad
antenna bad
wirelength excessive
congested
```

ต้องดู multi-dimensional metrics

---

# 74. Recommended Run Sequence

ครั้งแรก:

```bash
make clean
make setup-bondpad
make preflight

make global-routing
make check-global-routing

make antenna
make check-antenna

make detailed-routing
make check-detailed-routing

make trdrc
make check-trdrc

make postroute
make check-postroute

make metrics
make report
```

---

# 75. Fast Run

เมื่อ upstream stable:

```bash
make all
```

---

# 76. Pass Criteria — Global Routing

```text
[ ] GlobalRouting completes
[ ] no disallowed congestion
[ ] overflow clean
[ ] routing guides plausible
[ ] no severe hotspot
[ ] clock guide plausible
```

---

# 77. Pass Criteria — Antenna

```text
[ ] initial antenna count recorded
[ ] RepairAntennas runs
[ ] repair strategy reviewed
[ ] post-route antenna count recorded
[ ] remaining violations analyzed
```

เป้าหมาย final:

```text
0 antenna violations
```

---

# 78. Pass Criteria — Detailed Routing

```text
[ ] DetailedRouting completes
[ ] physical wires exist
[ ] vias exist
[ ] no obvious open
[ ] no obvious short
[ ] clock routed
[ ] pad routes connected
```

---

# 79. Pass Criteria — Route DRC

```text
[ ] Checker.TrDRC runs
[ ] DRC count recorded
[ ] disconnected pins reviewed
[ ] wire length reviewed
```

clean target:

```text
TrDRC violations = 0
```

---

# 80. Pass Criteria — Post Route

```text
[ ] FillInsertion completes
[ ] RCX completes
[ ] STAPostPNR completes
[ ] WNS/TNS recorded
[ ] setup violations recorded
[ ] hold violations recorded
[ ] max slew/cap reviewed
```

---

# 81. Important Qualification

Lab 8 PASS หมายถึง:

```text
routing database is suitable to proceed to signoff
```

ไม่ใช่:

```text
tapeout ready
```

ยังต้องมี:

```text
GDS streamout
KLayout/Magic DRC
LVS
signoff STA
antenna final
manufacturability
IR drop
```

---

# 82. Deliverables

```text
config/routing_plan.yaml
build/config.yaml

results/ROUTING_REVIEW.md

reports/
├── 00_environment.log
├── 01_pad_plan_check.txt
├── 02_bondpad_check.txt
├── 03_pdn_plan_check.txt
├── 04_placement_cts_plan_check.txt
├── 05_routing_plan_check.txt
├── 06_config_check.txt
├── 07_global_routing_check.txt
├── 08_antenna_check.txt
├── 09_detailed_routing_check.txt
├── 10_trdrc_check.txt
├── 11_postroute_check.txt
├── 12_routing_metrics.txt
└── LAB08_REPORT.md
```

และ ODB/DEF/report ของ:

```text
GlobalRouting
RepairAntennas
DetailedRouting
TrDRC
RCX
STAPostPNR
```

---

# 83. Design Review Questions

1. Global Routing กับ Detailed Routing ต่างกันอย่างไร?
2. routing overflow หมายถึงอะไร?
3. ทำไม baseline ไม่อนุญาต congestion?
4. `GRT_ADJUSTMENT` ทำอะไร?
5. antenna effect เกิดจากอะไร?
6. jumper กับ antenna diode ต่างกันอย่างไร?
7. ทำไม TrDRC ไม่ใช่ final signoff DRC?
8. ทำไม post-route STA realistic กว่า post-CTS STA?
9. ทำไม Lab ไม่ hard-code routing layer names?
10. ถ้า DRC=0 แต่มี disconnected pin ถือว่าผ่านหรือไม่?

ข้อ 10:

```text
ไม่ผ่าน
```

---

# 84. Freeze หลัง Lab 8

เมื่อ routing clean ให้ freeze:

```text
routing configuration
GRT adjustment
routing layer policy
antenna repair policy
detailed routed database
route DRC status
antenna count
wire length baseline
post-route WNS/TNS
```

---

# 85. Transition ไป Lab 9

Lab ต่อไปควรเป็น:

```text
Lab 9 — Signoff, DRC, LVS and GDSII
```

ประกอบด้วย:

```text
Fill
RC extraction
final STA
GDS streamout
KLayout DRC
Magic DRC
XOR
SPICE extraction
Netgen LVS
setup/hold checkers
manufacturability report
```

---

# 86. Engineering Rule

> Global-routing success ไม่ได้แปลว่า detailed routing จะสำเร็จ

และ:

> Detailed-routing success ไม่ได้แปลว่า signoff clean

Routing ต้องผ่านอย่างน้อย:

```text
capacity
connectivity
DRC
antenna
timing
```

จึงเหมาะที่จะเข้าสู่ signoff
