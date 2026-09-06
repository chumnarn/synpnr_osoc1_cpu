# Lab 9 — Signoff, DRC, LVS and GDSII
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Top:** `chip_top`  
**PDK:** `ihp-sg13g2`  
**Flow:** LibreLane `Chip`  
**Clock:** 50 MHz / 20 ns  
**Primary GDS streamout:** KLayout  
**Secondary GDS streamout:** Magic  
**LVS:** Netgen  
**Lab goal:** Signoff-quality evidence package, not an automatic claim of production tapeout approval

---

# 1. Lab 9 คือ Gate สุดท้ายของ RTL-to-GDSII Training Flow

Labs 1–8 พา design ผ่าน:

```text
RTL exploration
lint
core synthesis
wrapper
pad ring
floorplan
PDN
placement
CTS
routing
```

Lab 9 เปลี่ยนคำถามจาก:

```text
"flow วิ่งจบหรือไม่?"
```

เป็น:

```text
"layout ที่สร้างขึ้นมีหลักฐานเพียงพอหรือไม่ว่า
logical, physical และ timing intent ตรงกัน?"
```

---

# 2. Signoff ไม่ใช่ Step เดียว

signoff ประกอบด้วยหลาย independent checks:

```text
Timing
Physical DRC
LVS
Antenna
XOR
Power integrity
Connectivity
Manufacturability
Release integrity
```

design ต้องผ่านหลายมิติพร้อมกัน

---

# 3. LibreLane Signoff Tail

LibreLane `Chip` flow ปัจจุบันหลัง Detailed Routing มี chain สำคัญ:

```text
FillInsertion
CellFrequencyTables
RCX
STAPostPNR
IRDropReport
Magic.StreamOut
KLayout.StreamOut
KLayout.Render
Magic.WriteLEF
CheckDesignAntennaProperties
KLayout.XOR
Checker.XOR
Magic.DRC
KLayout.DRC
Checker.MagicDRC
Checker.KLayoutDRC
Magic.SpiceExtraction
Checker.IllegalOverlap
Netgen.LVS
Checker.LVS
Yosys.EQY              [optional/default off]
Checker.SetupViolations
Checker.HoldViolations
Checker.MaxSlewViolations
Checker.MaxCapViolations
Misc.ReportManufacturability
```

Lab 9 ใช้ complete `Chip` flow เพื่อถึง manufacturability report

---

# 4. Signoff Baseline Variables

ไฟล์:

```text
config/signoff_plan.yaml
```

มี:

```yaml
RUN_SPEF_EXTRACTION: true
RUN_MCSTA: true
RUN_IRDROP_REPORT: true

PRIMARY_GDSII_STREAMOUT_TOOL: klayout

RUN_MAGIC_STREAMOUT: true
RUN_KLAYOUT_STREAMOUT: true
RUN_MAGIC_WRITE_LEF: true

RUN_KLAYOUT_XOR: true

RUN_MAGIC_DRC: true
RUN_KLAYOUT_DRC: true
RUN_LVS: true

RUN_EQY: false
```

---

# 5. ทำไมใช้ KLayout เป็น Primary GDS Streamout

official IHP full-chip template ปัจจุบันกำหนด:

```yaml
PRIMARY_GDSII_STREAMOUT_TOOL: klayout
```

เหตุผลใน template คือ file sizes เล็กกว่าเล็กน้อย

Lab จึงใช้ค่าเดียวกัน

---

# 6. ทำไมยังสร้าง Magic GDS

แม้ primary = KLayout เราเปิด:

```yaml
RUN_MAGIC_STREAMOUT: true
```

เพราะต้องการ independent streamout เพื่อทำ:

```text
KLayout.XOR
```

หากสอง streamout representations ต่างกันอย่างไม่คาดคิด นั่นเป็น signoff concern

---

# 7. XOR คืออะไร

XOR ของ layout A/B แสดง geometry ที่แตกต่าง

conceptually:

```text
XOR(A,B) = shapes ที่อยู่ใน A หรือ B แต่ไม่อยู่ทั้งคู่
```

ถ้า streamouts logically/physically equivalent:

```text
XOR differences = 0
```

หรือมีเพียง intentional/tool-specific differences ที่อธิบายได้

---

# 8. XOR ไม่ใช่ LVS

XOR ถาม:

```text
geometry ของสอง streamout เหมือนกันไหม?
```

LVS ถาม:

```text
electrical connectivity ของ layout
ตรงกับ schematic/netlist ไหม?
```

ดังนั้นต้องมีทั้งสอง

---

# 9. KLayout DRC และ Magic DRC

Lab เปิดทั้ง:

```yaml
RUN_KLAYOUT_DRC: true
RUN_MAGIC_DRC: true
```

เพราะสอง engine/tool decks อาจมี implementation/details ต่างกัน

clean target:

```text
KLayout DRC = 0
Magic DRC = 0
```

ถ้ามี known-tool limitation ต้อง document waiver ชัดเจน

---

# 10. Official IHP Template Caveat

official IHP template มี comments ที่อนุญาต disable:

```text
KLayout DRC
Magic DRC
KLayout antenna
KLayout density
IR drop
XOR
LVS
```

เพื่อ iteration speed/debugging

แต่ Lab 9 เป็น signoff Lab

ดังนั้น baseline นี้ **ไม่ disable** mandatory signoff checks

---

# 11. DRC คืออะไร

Design Rule Check ตรวจ geometry ต่อ manufacturing rules เช่น:

```text
minimum width
minimum spacing
enclosure
extension
via rules
density
off-grid / geometry rules
```

DRC clean ไม่ได้แปลว่า logic ถูก

---

# 12. LVS คืออะไร

Layout Versus Schematic เปรียบเทียบ:

```text
extracted layout netlist
```

กับ:

```text
intended logical/schematic netlist
```

ตรวจ:

```text
devices/cells
nets
pins
connectivity
hierarchy/global nets
```

---

# 13. LibreLane LVS Chain

signoff tail:

```text
Magic.SpiceExtraction
        |
        v
extracted SPICE
        |
        v
Netgen.LVS
        |
        v
Checker.LVS
```

---

# 14. Multiple Power Pads and LVS

full-chip design มีหลาย power pads ที่แชร์:

```text
VDD
VSS
```

official IHP template ใช้:

```yaml
MAGIC_EXT_UNIQUE: notopports
```

เพราะมีหลาย power pads ต่อ power domain เดียวกัน

Lab รักษาค่านี้ไว้

---

# 15. Bondpad Physical Macro

bondpad:

```text
bondpad_70x70_novias
```

เป็น physical macro ที่เพิ่มผ่าน:

```yaml
EXTRA_GDS
EXTRA_LEFS
```

และ:

```yaml
IGNORE_DISCONNECTED_MODULES:
  - bondpad_70x70_novias
```

ต้องไม่ตีความ intentional physical-only structure เป็น logic missing โดยอัตโนมัติ

---

# 16. RC Extraction

Lab เปิด:

```yaml
RUN_SPEF_EXTRACTION: true
```

ซึ่งทำให้ LibreLane ใช้:

```text
OpenROAD.RCX
```

เพื่อสร้าง post-route parasitics

---

# 17. SPEF

SPEF คือ:

```text
Standard Parasitic Exchange Format
```

บรรจุประมาณ:

```text
resistance
capacitance
net parasitics
```

ใช้สำหรับ post-route timing

---

# 18. Multi-Corner STA

Lab เปิด:

```yaml
RUN_MCSTA: true
```

LibreLane ปัจจุบันใช้ `OpenROAD.STAPostPNR`

เพื่อวิเคราะห์ timing ด้วย routed parasitics across configured corners

---

# 19. Timing Corners

design ไม่ควรพิสูจน์ timing ที่ corner เดียวเท่านั้น

ตัวอย่าง conceptual:

```text
slow process / low V / high T
fast process / high V / low T
typical
```

setup และ hold worst-case อาจเกิดคนละ corner

---

# 20. Setup Signoff

clean target:

```text
setup violations = 0
```

และ ideally:

```text
WNS >= 0
TNS = 0
```

ทุก required corner/mode

---

# 21. Hold Signoff

clean target:

```text
hold violations = 0
```

hold ไม่แก้ด้วยลด clock frequency

เพราะเป็น minimum-delay problem

---

# 22. Slew and Capacitance

signoff tail มี:

```text
Checker.MaxSlewViolations
Checker.MaxCapViolations
```

ต้อง review เพราะ timing slack ผ่านแต่ electrical constraints fail ยังไม่ถือว่า clean

---

# 23. IR Drop Report

Lab เปิด:

```yaml
RUN_IRDROP_REPORT: true
```

flow ใช้:

```text
OpenROAD.IRDropReport
```

---

# 24. IR Drop Interpretation

IR drop:

```text
Vdrop = I × R
```

power-grid resistance และ current distribution ทำให้ supply ที่ cells ต่ำกว่า source voltage

---

# 25. IR Drop Caveat

IR-drop report มีความหมายเท่ากับ quality ของ:

```text
activity/current model
power assumptions
placement
PDN
```

Lab จึงไม่ใช้คำว่า “IR-drop signoff” เพียงเพราะ report ถูก generate

ต้อง review assumptions

---

# 26. EM vs IR Drop

IR drop:

```text
voltage-integrity problem
```

Electromigration:

```text
current-density / reliability problem
```

Lab นี้ไม่ได้อ้างว่า EM signoff เสร็จ หากไม่มี EM-qualified flow

---

# 27. Directory Structure

```text
lab09_signoff/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB09_TH.md
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
│   └── signoff_plan.yaml
│
├── signoff/
│   └── TAPEOUT_CHECKLIST.md
│
├── scripts/
│   ├── setup_bondpad.sh
│   ├── check_env.sh
│   ├── check_bondpad.py
│   ├── check_pad_plan.py
│   ├── check_pdn_plan.py
│   ├── check_placement_cts_plan.py
│   ├── check_routing_plan.py
│   ├── check_signoff_plan.py
│   ├── gen_config.py
│   ├── check_config.py
│   ├── check_run_log.py
│   ├── extract_signoff_metrics.py
│   ├── find_final_artifacts.py
│   ├── release_manifest.py
│   └── build_report.py
│
├── build/
├── reports/
└── results/
```

---

# 28. Step 1 — Enter Signoff Environment

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

กลับ Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab09_signoff
```

---

# 29. Step 2 — Setup Bondpad

```bash
make setup-bondpad
```

ใช้ real GDS/LEF

ห้าม fake GDS

---

# 30. Step 3 — Environment Check

```bash
make check-env
```

required:

```text
python3
verilator
yosys
librelane
```

ควรพบ standalone:

```text
openroad
klayout
magic
netgen
```

ขึ้นกับ Nix packaging

---

# 31. Step 4 — Revalidate Upstream Frozen Intent

```bash
make check-pad-plan
make check-pdn-plan
make check-place-plan
make check-route-plan
```

signoff result ไม่มีความหมายหาก upstream configuration เปลี่ยนโดยไม่ได้บันทึก

---

# 32. Step 5 — Check Signoff Plan

```bash
make check-signoff-plan
```

expected:

```text
RUN_SPEF_EXTRACTION = true
RUN_MCSTA = true
RUN_IRDROP_REPORT = true

Magic streamout = true
KLayout streamout = true
XOR = true

Magic DRC = true
KLayout DRC = true
LVS = true
```

---

# 33. Step 6 — Generate Final Config

```bash
make gen-config
```

output:

```text
build/config.yaml
```

นี่คือ complete training full-chip config

รวม Labs 5–9 intent

---

# 34. Step 7 — Check Generated Config

```bash
make check-config
```

ตรวจ:

```text
flow
top
PDN
CTS
routing
streamout
XOR
DRC
LVS
timing
IR drop
```

---

# 35. Step 8 — Full Preflight

```bash
make preflight
```

ต้องได้:

```text
LAB 9 PREFLIGHT PASS
```

---

# 36. Step 9 — Reconfirm Post-Route STA

ก่อน signoff geometry:

```bash
make postroute
make check-postroute
```

endpoint:

```text
OpenROAD.STAPostPNR
```

---

# 37. Why Re-run Postroute in Lab 9

signoff package ต้อง prove:

```text
same config
same RTL
same PDK
same route
same STA
```

ไม่ควร cite Lab 8 result ที่มาจาก configuration khácกันโดยไม่ reproduce

---

# 38. Step 10 — Streamout

```bash
make streamout
make check-streamout
```

endpoint:

```text
KLayout.StreamOut
```

flow จะสร้าง Magic streamout ก่อน และ KLayout streamout ตามลำดับ Chip flow

---

# 39. GDSII

GDSII เป็น mask-layout exchange database

ต้องมี:

```text
top cell
standard-cell geometry
I/O pads
bondpads
metal/vias
fill structures
```

---

# 40. Check Top Cell

primary GDS ต้อง contain:

```text
chip_top
```

ไม่ใช่เพียง:

```text
chip_core
```

เพราะนี่ full-chip tapeout artifact

---

# 41. Visual GDS Inspection

เปิด KLayout

ตรวจ:

```text
die
pad ring
bondpads
core
routing
power ring
fill
top cell
```

ก่อนเชื่อ automated reports อย่างเดียว

---

# 42. Step 11 — XOR

```bash
make xor
make check-xor
```

endpoint:

```text
Checker.XOR
```

LibreLane ระบุว่า XOR ใช้ GDS ที่สร้างจาก Magic และ KLayout และต้องให้ทั้งสอง streamout รันก่อน

---

# 43. XOR Pass

ideal:

```text
XOR differences = 0
```

ถ้า non-zero:

ต้อง classify:

```text
intentional fill/render difference?
tool-specific unsupported geometry?
real streamout mismatch?
```

---

# 44. Never Waive XOR Blindly

ถ้า XOR fail:

ห้ามเพียง:

```yaml
RUN_KLAYOUT_XOR: false
```

แล้วเรียก design signoff clean

การ disable ใช้ได้เฉพาะ iteration/debug โดยต้องบอกชัดว่า check ถูก skip

---

# 45. Step 12 — DRC

```bash
make drc
make check-drc
```

endpoint:

```text
Checker.KLayoutDRC
```

flow ก่อนถึงจุดนี้ยังรัน:

```text
Magic.DRC
KLayout.DRC
Checker.MagicDRC
Checker.KLayoutDRC
```

---

# 46. DRC Result Table

ควรบันทึก:

| Tool | Violations | Status |
|---|---:|---|
| Magic | measured | PASS/FAIL |
| KLayout | measured | PASS/FAIL |

target:

```text
0 / 0
```

---

# 47. IHP DRC Caveat

official IHP template ปัจจุบันมี comments ว่า Magic อาจ report overlaps บางกรณีและมีตัวเลือก disable DRC steps สำหรับ debug/iteration

แต่ signoff decision ต้อง distinguish:

```text
known benign tool artifact
```

จาก:

```text
real DRC violation
```

และต้อง document waiver

---

# 48. Step 13 — LVS

```bash
make lvs
make check-lvs
```

endpoint:

```text
Checker.LVS
```

flow ผ่าน:

```text
Magic.SpiceExtraction
Checker.IllegalOverlap
Netgen.LVS
Checker.LVS
```

---

# 49. LVS Clean Target

ต้องได้ equivalent result

conceptually:

```text
circuits match uniquely
```

หรือ equivalent status ของ Netgen/LibreLane

---

# 50. Common LVS Failure — Power Nets

full-chip design มัก fail เพราะ:

```text
VDD/VSS names
global nets
multiple pads
IOVDD/IOVSS
power-pin extraction
```

ตรวจ power domain ก่อน blame logic

---

# 51. Common LVS Failure — I/O Pads

I/O cells มี complex internal structures

PDK extraction/LVS rules ต้อง identify cells/models ได้ถูก

อย่า substitute simulation stub เข้า signoff

---

# 52. Common LVS Failure — Bondpad

bondpad เป็น physical structure

ตรวจ:

```text
IGNORE_DISCONNECTED_MODULES
LEF/GDS macro name
extraction behavior
```

---

# 53. Common LVS Failure — Hierarchy

ถ้า schematic side กับ layout side flatten ต่างกัน:

ตรวจ:

```text
blackbox handling
macro models
top-level pin names
power nets
```

---

# 54. Step 14 — Full Signoff Run

เมื่อ checkpoints เข้าใจแล้ว:

```bash
make signoff
```

นี่รัน complete `Chip` flow โดยไม่มี `--to`

จึงต้องไปถึง:

```text
Misc.ReportManufacturability
```

ถ้าไม่มี earlier failure

---

# 55. Step 15 — Check Full Signoff Log

```bash
make check-signoff
```

log scan เป็น first-pass เท่านั้น

ต้องอ่าน native reports

---

# 56. Step 16 — Metrics Summary

```bash
make metrics
```

สร้าง:

```text
reports/14_signoff_metrics.txt
```

พยายามดึง:

```text
WNS
TNS
DRC
XOR
LVS
antenna
disconnected pins
setup
hold
slew
cap
```

---

# 57. Metrics Parser Is Not Signoff Authority

ห้ามใช้ parser นี้แทน:

```text
OpenROAD STA reports
Magic DRC report
KLayout DRC report
KLayout XOR report
Netgen LVS report
IR-drop report
```

parser มีไว้ช่วย workshop

---

# 58. Setup Checker

ท้าย flow มี:

```text
Checker.SetupViolations
```

signoff target:

```text
0
```

---

# 59. Hold Checker

```text
Checker.HoldViolations
```

target:

```text
0
```

---

# 60. Max Slew Checker

```text
Checker.MaxSlewViolations
```

target:

```text
0
```

---

# 61. Max Cap Checker

```text
Checker.MaxCapViolations
```

target:

```text
0
```

---

# 62. Manufacturability Report

ท้าย `Chip` flow มี:

```text
Misc.ReportManufacturability
```

รวบรวม manufacturing-relevant flow status

เป็น useful executive summary แต่ยังต้องอ่าน underlying reports

---

# 63. Final Antenna

routing stage มี antenna checker

full-chip IHP flow variants ยังอาจมี KLayout antenna/density stepsขึ้นกับ flow/tool support

ต้องบันทึกว่า:

```text
antenna checker ใดรัน
checker ใดไม่ได้รัน
เหตุผล
```

---

# 64. Density

full-chip manufacturing มักมี density requirements

ถ้า PDK/flow รองรับ KLayout density check ต้อง review

อย่าถือว่า fill insertion = density signoff โดยอัตโนมัติ

---

# 65. Step 17 — Discover Final Artifacts

```bash
make artifacts
```

สร้าง:

```text
reports/15_final_artifacts.txt
```

พยายามค้น:

```text
GDS
LEF
DEF
ODB
netlists
SDC
SPEF
SPICE
reports
JSON
```

พร้อม size/checksum บางไฟล์

---

# 66. Why Checksums Matter

release artifact ควร identifiable

SHA-256 ช่วยตอบ:

```text
ไฟล์นี้เป็นไฟล์เดียวกับที่ signoff หรือไม่?
```

---

# 67. Step 18 — Release Manifest

```bash
make release-manifest
```

จะ copy checklist ไป:

```text
results/TAPEOUT_CHECKLIST.md
```

และสร้าง:

```text
results/RELEASE_MANIFEST.md
```

---

# 68. Release Package ควรมีอะไร

ขั้นต่ำ:

```text
primary GDS
secondary GDS if retained
final DEF
final ODB
final gate netlist
SDC
SPEF
LEF
DRC reports
LVS report
STA reports
IR-drop report
manufacturability report
tool versions
PDK revision
config
checksums
```

---

# 69. Step 19 — Final Lab Report

```bash
make report
```

ได้:

```text
reports/LAB09_REPORT.md
```

---

# 70. Recommended First-Time Run Sequence

```bash
make clean
make setup-bondpad
make preflight

make postroute
make check-postroute

make streamout
make check-streamout

make xor
make check-xor

make drc
make check-drc

make lvs
make check-lvs

make signoff
make check-signoff

make metrics
make artifacts
make release-manifest
make report
```

---

# 71. Fast Re-run

เมื่อ flow stable:

```bash
make all
```

---

# 72. Signoff Matrix

สร้างตาราง:

| Check | Tool | Result | Target |
|---|---|---|---|
| Setup | OpenROAD STA | measured | 0 violations |
| Hold | OpenROAD STA | measured | 0 violations |
| Max slew | Checker | measured | 0 |
| Max cap | Checker | measured | 0 |
| Antenna | OpenROAD/KLayout | measured | 0 |
| XOR | KLayout | measured | 0 |
| DRC | Magic | measured | 0 |
| DRC | KLayout | measured | 0 |
| LVS | Netgen | measured | equivalent |
| IR Drop | OpenROAD | measured | reviewed |

---

# 73. What Counts as PASS

strong signoff pass:

```text
all mandatory checkers executed
+
zero unwaived physical violations
+
zero timing/electrical violations
+
LVS equivalent
+
release artifacts archived
```

---

# 74. What Does Not Count as PASS

ไม่พอ:

```text
"LibreLane reached GDS"
```

ไม่พอ:

```text
"KLayout opened the file"
```

ไม่พอ:

```text
"Routing completed"
```

ไม่พอ:

```text
"LVS step ran"
```

ต้องดู result

---

# 75. Waiver Discipline

ถ้าต้อง waive:

บันทึก:

```text
check/tool
violation identifier
location/net
reason
evidence
risk
approver
date
```

ห้ามใช้:

```text
known warning
```

โดยไม่มีรายละเอียด

---

# 76. Production PDK Caveat

IHP SG13G2 open PDK/template เป็น excellent research/training environment

แต่ production/MPW submission ต้อง follow:

```text
specific shuttle/foundry release requirements
approved tool/rule versions
submission checks
```

Lab 9 เป็น training signoff workflow ไม่แทน foundry release procedure

---

# 77. Troubleshooting — KLayout Streamout Fail

ตรวจ:

```text
EXTRA_GDS
bondpad
library GDS
top cell
layer mapping
```

---

# 78. Troubleshooting — Magic Streamout Fail

ตรวจ:

```text
Magic tech
macro GDS/LEF
unsupported cell geometry
power pads
```

---

# 79. Troubleshooting — XOR Non-Zero

หา spatial differences

ถาม:

```text
standard cells?
pad?
bondpad?
fill?
labels?
power geometry?
```

differences around one macro มักชี้ macro-view inconsistency

---

# 80. Troubleshooting — Magic DRC vs KLayout DRC Disagree

อย่าตัดสินจากจำนวนอย่างเดียว

ดู:

```text
rule class
marker location
rule-deck coverage
flattening
macro treatment
```

---

# 81. Troubleshooting — LVS Power Mismatch

ตรวจ:

```text
VDD
VSS
IOVDD
IOVSS
MAGIC_EXT_UNIQUE
power-pin models
global-net rules
```

---

# 82. Troubleshooting — LVS Pin Mismatch

compare:

```text
chip_top ports
extracted ports
netlist ports
pad-cell connectivity
```

---

# 83. Troubleshooting — Setup Violations

ใช้ exact worst corner/path

ตรวจ:

```text
data path
clock path
SPEF
drive/load
constraint
```

อย่าปิด checker

---

# 84. Troubleshooting — Hold Violations

ตรวจ minimum paths

hold repair ต้องเพิ่ม minimum delay/adjust physical design

clock period ไม่ใช่ primary fix

---

# 85. Troubleshooting — IR Drop High

ตรวจ:

```text
PDN width
straps/rails
power-pad locations
current assumptions
cell clustering
```

อย่าเพิ่ม metal widthโดยไม่ตรวจ DRC/routing impact

---

# 86. Troubleshooting — DRC Around Bondpad

ตรวจ official bondpad GDS/LEF และ IHP template behavior

อย่าแก้ physical IP ด้วยการวาด geometry เดาเอง

---

# 87. Visual Inspection Before Release

เปิด final GDS ใน KLayout

ตรวจ:

```text
chip outline
pad ring
all 18 pad structures
bondpads
power ring
core
routes
fill
top-cell hierarchy
```

---

# 88. Gate-Level Simulation

official IHP template รองรับ gate-level simulation หลัง final views ถูก copy ไป final folder

สำหรับ course extension ควรทำ:

```text
post-layout netlist
+
same NOP smoke test
```

ยืนยัน output:

```text
PC[9:2] increments
```

แต่ timing annotation/SDF capability ต้องดู flow/tool availabilityจริง

---

# 89. Logical Equivalence

Lab baseline `RUN_EQY: false`

แต่ advanced extension สามารถเปิด:

```yaml
RUN_EQY: true
```

ถ้า environment/RTL supports Yosys EQY

physical LVS กับ logical equivalence ตอบคนละคำถาม

---

# 90. Final Deliverables

```text
config/signoff_plan.yaml
build/config.yaml

signoff/TAPEOUT_CHECKLIST.md

reports/
├── 00_environment.log
├── 01_pad_plan_check.txt
├── 02_bondpad_check.txt
├── 03_pdn_plan_check.txt
├── 04_placement_cts_plan_check.txt
├── 05_routing_plan_check.txt
├── 06_signoff_plan_check.txt
├── 07_config_check.txt
├── 08_postroute_check.txt
├── 09_streamout_check.txt
├── 10_xor_check.txt
├── 11_drc_check.txt
├── 12_lvs_check.txt
├── 13_full_signoff_check.txt
├── 14_signoff_metrics.txt
├── 15_final_artifacts.txt
└── LAB09_REPORT.md

results/
├── TAPEOUT_CHECKLIST.md
└── RELEASE_MANIFEST.md
```

---

# 91. Pass Criteria — Timing

```text
[ ] RCX completed
[ ] multi-corner STA completed
[ ] setup = 0 violations
[ ] hold = 0 violations
[ ] max slew = 0
[ ] max cap = 0
```

---

# 92. Pass Criteria — GDS/XOR

```text
[ ] Magic GDS generated
[ ] KLayout GDS generated
[ ] primary GDS identified as KLayout
[ ] top cell = chip_top
[ ] XOR completed
[ ] XOR = 0 or fully dispositioned
```

---

# 93. Pass Criteria — DRC

```text
[ ] Magic DRC completed
[ ] KLayout DRC completed
[ ] zero unwaived Magic violations
[ ] zero unwaived KLayout violations
```

---

# 94. Pass Criteria — LVS

```text
[ ] extraction completed
[ ] Netgen LVS completed
[ ] Checker.LVS passed
[ ] circuit/layout equivalent
```

---

# 95. Pass Criteria — Power / Manufacturability

```text
[ ] IR-drop report generated and reviewed
[ ] final antenna reviewed
[ ] disconnected-pin checker clean
[ ] manufacturability report reviewed
```

---

# 96. Release Criteria

```text
[ ] signoff reports archived
[ ] final GDS checksum recorded
[ ] config archived
[ ] RTL revision archived
[ ] PDK/tool versions recorded
[ ] waivers documented
[ ] tapeout checklist complete
```

---

# 97. Design Review Questions

1. DRC กับ LVS ต่างกันอย่างไร?
2. XOR กับ LVS ต่างกันอย่างไร?
3. ทำไมต้องสร้าง GDS จากสอง tools?
4. ทำไม post-route STA ต้องใช้ parasitics?
5. setup กับ hold worst corner อาจต่างกันเพราะอะไร?
6. ทำไม DRC=0 ไม่พอสำหรับ tapeout?
7. `MAGIC_EXT_UNIQUE: notopports` มีประโยชน์อย่างไรใน full-chip?
8. ทำไม IR-drop report ไม่เท่ากับ EM signoff?
9. ทำไม simulation I/O stub ห้ามเข้า LVS/signoff source set?
10. ถ้า flow จบแต่ Checker.LVS fail ถือว่า tapeout-ready หรือไม่?

คำตอบข้อ 10:

```text
ไม่
```

---

# 98. Freeze หลัง Lab 9

เมื่อ signoff clean ให้ freeze:

```text
RTL revision
resolved config
PDK revision
tool versions
final routed ODB
final DEF
final GDS
final netlist
SDC/SPEF
DRC results
LVS result
timing reports
IR-drop report
waivers
checksums
```

---

# 99. จาก Training Flow สู่ MPW Release

ขั้นต่อไปไม่ใช่ PnR step อีกแล้ว

แต่เป็น:

```text
MPW submission preparation
package/bond plan
release documentation
foundry precheck
submission manifest
version locking
archive
```

---

# 100. Engineering Rule ของ Lab 9

> Tapeout readiness เป็นสถานะที่ได้จากหลักฐานหลายชุด ไม่ใช่จากคำว่า “flow completed”

และ:

> Check ที่ถูก disable คือ check ที่ยังไม่ได้พิสูจน์ ไม่ใช่ check ที่ผ่าน

ดังนั้น final report ต้องบอกอย่างตรงไปตรงมาว่า:

```text
PASS
FAIL
WAIVED
NOT RUN
```

สำหรับทุก signoff category
