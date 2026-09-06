# Lab 22 — IHP SG13G2 Full-Chip RTL-to-GDSII
## Deep Step-by-Step Ready-to-Run Guide
### LibreLane `Chip` Flow + IHP SG13G2 + SRAM + Pad Ring + PDN + Signoff

Lab นี้เป็น physical-design culmination ของ O'SoC 1.0 หลัง Full SoC Simulation

---

# 1. เป้าหมายของ Lab 22

Lab 22 เป็น physical implementation lab สำหรับ full chip ของ O'SoC 1.0

เป้าหมายคือเปลี่ยน:

```text
verified RTL
```

เป็น:

```text
manufacturing-layout candidate
```

ผ่าน flow:

```text
Synthesis
Floorplan
Pad ring
Macro placement
PDN
Placement
CTS
Routing
Extraction
STA
DRC
LVS
GDS
```

---

# 2. ความสัมพันธ์กับ Lab 21

Lab 21 พิสูจน์ functional behavior

Lab 22 พิสูจน์ physical implementability

ดังนั้น revision ที่จะเข้า Lab22 ควรผ่าน:

```bash
make all
```

ของ Lab21 ก่อน

---

# 3. Flow baseline

ใช้:

```yaml
meta:
  version: 3
  flow: Chip
```

เพราะ design มี:
- I/O pads
- power pads
- bondpads
- SRAM macro

---

# 4. ทำไมไม่ใช้ core-only flow

core-only flow ไม่ครอบคลุม full-chip pad-ring integration แบบเดียวกับ `Chip`

จุดสำคัญของ Lab นี้คือ pad/macro/PDN/signoff ที่ระดับ chip

---

# 5. Official IHP template as baseline

แนวทาง Lab ใช้ concept เดียวกับ IHP LibreLane full-chip template:
- `chip_top`
- `chip_core`
- pad side lists
- external bondpad views
- IHP PDK
- `USE_SLANG`

---

# 6. Level A และ Level B

Level A:
```text
osoc22_physical_core
```

ใช้ debug physical flow

Level B:
```text
real O'SoC from Lab21
```

ใช้ก่อน final project signoff

---

# 7. เหตุผลที่ต้องมี Level A

หากเริ่มด้วย CPU + XIP + CSR + PLIC + SRAM พร้อมกัน ปัญหา synthesis/macro/pad/PDN
จะซ้อนกันมาก

Level A ทำให้รู้ว่า physical infrastructure ถูกก่อน

---

# 8. Top-level architecture

```text
bondpad
  |
IHP IO pad
  |
chip_top
  |
chip_core
  |
O'SoC logic + SRAM
```

---

# 9. Clock

baseline:

```text
50 MHz
20 ns
```

---

# 10. Clock port

top port:

```text
clk_PAD
```

หลัง pad:

```text
clk_pad/p2c
```

---

# 11. Clock SDC

SDC สร้าง clock ที่ pad output pin ไม่ใช่ raw package port:

```tcl
[get_pins clk_pad/p2c]
```

---

# 12. Reset

```text
rst_n_PAD
```

active-low asynchronous

---

# 13. Reset timing

ตั้ง:

```tcl
set_false_path -from [get_ports rst_n_PAD]
```

สำหรับ baseline async-reset constraint

---

# 14. Signal pad count

signal pads:

```text
CLK
RESET
SPI_MISO
SPI_CS_N
SPI_SCK
SPI_MOSI
GPIO0..GPIO7
```

รวม 14

---

# 15. Power pad count

```text
2 VDD
2 VSS
2 IOVDD
2 IOVSS
```

รวม 8

---

# 16. Total pad count

```text
14 + 8 = 22
```

---

# 17. Pad cells

ใช้:
```text
sg13g2_IOPadIn
sg13g2_IOPadOut30mA
sg13g2_IOPadVdd
sg13g2_IOPadVss
sg13g2_IOPadIOVdd
sg13g2_IOPadIOVss
```

---

# 18. Simulation stubs

`tb/ihp_io_stubs.sv` มีไว้ lint/smoke เท่านั้น

ห้ามใส่ใน physical `VERILOG_FILES`

---

# 19. Pad South

```text
CLK
RESET
SPI_MISO
VDD0
VSS0
```

---

# 20. Pad East

```text
SPI_CS_N
SPI_SCK
SPI_MOSI
GPIO0
GPIO1
IOVDD0
```

---

# 21. Pad North

```text
GPIO7
GPIO6
GPIO5
GPIO4
GPIO3
GPIO2
IOVSS0
```

---

# 22. Pad West

```text
VDD1
VSS1
IOVDD1
IOVSS1
```

---

# 23. Generated hierarchy escaping

YAML/Tcl ต้อง escape `[` `]`

เช่น:

```text
"outputs\\[7\\].output_pad"
```

---

# 24. Bondpad requirement

bondpad:

```text
bondpad_70x70_novias
```

ไม่ควรสร้าง GDS ปลอม

---

# 25. ติดตั้ง bondpad

```bash
make setup-bondpad \
 IHP_TEMPLATE_ROOT=/path/to/ihp-sg13g2-librelane-template
```

---

# 26. Bondpad LEF

baseline LEF size:

```text
70 x 70 um
```

---

# 27. Bondpad GDS

ต้องเป็น real geometry จาก template/source ที่เชื่อถือได้

preflight จะ fail ถ้า GDS ไม่มี

---

# 28. SRAM macro

ใช้:

```text
RM_IHPSG13_1P_1024x32_c2_bm_bist
```

---

# 29. SRAM capacity

```text
1024 x 32 bit
= 32768 bit
= 4096 byte
= 4 KiB
```

---

# 30. SRAM delivered views

PDK ต้องมี:
```text
GDS
LEF
Liberty
Verilog
CDL/doc
```

physical flowใช้ GDS/LEF/Liberty/Verilog

---

# 31. SRAM wrapper

file:

```text
src/ihp_sram_1kx32.sv
```

---

# 32. SRAM A_DLY

wrapper tie:

```systemverilog
.A_DLY(1'b1)
```

---

# 33. SRAM BIST

baseline physical functional mode:

```text
BIST disabled
```

DFT/MBIST integrationเป็น lab ถัดไปได้

---

# 34. Byte mask

4 byte strobesถูก expand เป็น 32-bit bit mask

---

# 35. SRAM hierarchy

baseline:

```text
i_chip_core.i_osoc.i_sram.sram_0
```

---

# 36. Hierarchy is physical configuration

macro instance nameไม่ใช่ cosmetic

มันถูกใช้โดย:
- macro placement
- PDN hooks
- dedicated PDN grid

---

# 37. SRAM placement

baseline:

```text
[700,680]
orientation N
```

---

# 38. Die area

```text
0 0 1600 1600
```

---

# 39. Core area

```text
365 365 1235 1235
```

---

# 40. Why conservative core area

full-chip pad ring และ power ring ต้องมี space รอบ core

พื้นที่นี้เป็น training baseline ไม่ใช่ optimum

---

# 41. Placement density

```text
20%
```

ใช้เพื่อเริ่ม closureง่ายก่อน

---

# 42. Congestion

`GRT_ALLOW_CONGESTION: true` ใช้ early bring-up

final releaseต้อง review overflowจริง

---

# 43. PDN core ring

เปิด:

```text
PDN_CORE_RING=true
```

---

# 44. Ring connection

```text
PDN_CORE_RING_CONNECT_TO_PADS=true
```

---

# 45. PDN dimensions

baseline:
```text
width 15 um
spacing 5 um
```

---

# 46. Standard-cell PDN

custom `pdn_cfg.tcl` สร้าง:
- vertical stripes
- horizontal stripes
- rails
- ring

---

# 47. SRAM PDN

dedicated SRAM gridใช้:
```text
Metal4
Metal5
TopMetal1
```

---

# 48. Why macro PDN requires review

geometry overlapไม่เท่ากับ electrical connectivity

ต้องตรวจ vias/connected shapes

---

# 49. Power aliases

SRAM uses aliases such as:
```text
VDDARRAY!
VDD!
VSS!
```

ผูกเข้ากับ VDD/VSS top-level

---

# 50. Config validation

```bash
make check-config
```

---

# 51. Pad-plan validation

```bash
make check-pad-plan
```

---

# 52. Environment validation

```bash
make check-env
```

---

# 53. Find PDK

```bash
python3 scripts/find_pdk.py
```

---

# 54. Check SRAM PDK views

```bash
make check-sram-views \
 PDK_PATH=/absolute/path/to/ihp-sg13g2
```

---

# 55. Static preflight

```bash
make preflight
```

must include real bondpad GDS

---

# 56. RTL lint

```bash
make lint
```

---

# 57. RTL smoke

```bash
make smoke
```

expected:
```text
PASS: Lab 22 full-chip RTL wrapper smoke completed.
```

---

# 58. Why smoke before synthesis

ช่วยจับ:
- wrapper port mismatch
- pad direction mistakes
- SRAM wrapper syntax
ก่อน LibreLane run

---

# 59. Synthesis

```bash
make synth
```

---

# 60. Synthesis endpoint

ใช้:

```text
--to Yosys.Synthesis
```

---

# 61. Synthesis pass criteria

ตรวจ:
- no unmapped logic
- SRAM macro preserved
- pad hierarchy present

---

# 62. Unmapped cell debugging

ห้าม disable checkerทันที

ค้น cell exact nameใน synthesis report/netlist

---

# 63. Floorplan + PDN

```bash
make floorplan
```

endpoint:
```text
OpenROAD.GeneratePDN
```

---

# 64. Floorplan visual checklist

ตรวจ:
- die
- core
- all 4 pad sides
- SRAM
- core ring
- channels

---

# 65. Macro check failure

ถ้า macro instanceไม่พบ:
1. inspect synthesized hierarchy
2. update exact path
3. rerun

---

# 66. Placement

```bash
make place
```

---

# 67. Placement review

ดู:
- density
- hotspots
- SRAM halo
- pad-to-core fanout

---

# 68. CTS

```bash
make cts
```

---

# 69. CTS root

ต้องเริ่มจาก:
```text
clk_pad/p2c
```

---

# 70. CTS review

ดู:
- skew
- inserted buffers
- max transition
- max capacitance
- hold repair

---

# 71. Routing

```bash
make route
```

---

# 72. Routing review

ดู:
- overflow
- DRT violations
- antenna
- pad escape
- SRAM channels

---

# 73. Routing layers

ห้าม copy layer namesจาก SKY130/GF180

IHP uses its own layer stack

---

# 74. Full flow

```bash
make full
```

---

# 75. Flow completion meaning

flow completeหมายถึง tools completed

ไม่เท่ากับ tapeout-ready

---

# 76. Post-route timing

ต้อง review STA หลัง parasitic extraction

---

# 77. Setup

check negative setup slack across relevant corners

---

# 78. Hold

check negative hold slack across relevant corners

---

# 79. Slew/capacitance

timing passต้องรวม electrical checks

---

# 80. Antenna

antenna reportต้องถูก reviewหลัง routing

---

# 81. DRC

DRC:
```text
executed + reviewed
```

ถึงเรียก PASS

---

# 82. LVS

LVS compare:
```text
layout connectivity vs intended netlist
```

---

# 83. IR drop

IR reportเป็น evidenceของ power delivery

ไม่เท่ากับ full EM signoff

---

# 84. KLayout streamout

primary GDS tool:
```text
KLayout
```

---

# 85. GDS visual inspection

เปิด final GDS และตรวจ:
- top hierarchy
- die boundary
- pads
- bondpads
- SRAM
- routing
- PDN

---

# 86. Copy final views

```bash
make copy-final
```

---

# 87. Check final views

```bash
make check-final
```

---

# 88. Signoff evidence index

```bash
make summarize-signoff
```

สร้าง:
```text
reports/LAB22_SIGNOFF_SUMMARY.md
```

---

# 89. Report

```bash
make report
```

สร้าง:
```text
reports/LAB22_REPORT.md
```

---

# 90. Release manifest

```bash
make manifest
```

---

# 91. SHA256

manifestใช้ SHA256 เพื่อผูก:
- source
- config
- reports
- final views
เข้าด้วยกัน

---

# 92. Tool versions

manifestเก็บ:
- LibreLane
- Yosys
- Verilator
- OpenROAD
เท่าที่ environmentมี

---

# 93. One-command flow

หลัง bondpadและ preflightพร้อม:

```bash
make all
```

---

# 94. Recommended staged flow

สำหรับ workshopไม่ควรเริ่ม `make full` ทันที

ใช้:
```text
synth
floorplan
place
cts
route
full
```

---

# 95. Why staged flow

แต่ละ stageสร้าง checkpointสำหรับ:
- report
- GUI inspection
- targeted debug

---

# 96. Unknown key

LibreLane config variablesเปลี่ยนตาม version

หาก unknown:
- consult installed version docs
- compare official IHP template

---

# 97. LibreLane CLI

ใช้:
```text
--run-tag
```

ไม่ใช้ `--tag` ใน environment v3 ที่เคยใช้งาน

---

# 98. No validate-only assumption

ถ้า installed versionไม่มี `--validate-only`
ใช้ static preflight + staged flowแทน

---

# 99. Bondpad fail

preflightตั้งใจ failถ้าไม่มี real bondpad GDS

---

# 100. Fake GDS prohibition

ห้ามสร้าง dummy GDSเพื่อหลอก flow

เพราะ DRC/package resultจะไม่มีความหมาย

---

# 101. Simulation IO stubs

stubs:
```text
tb/ihp_io_stubs.sv
```

ไม่เข้า physical source list

---

# 102. SRAM blackbox

`tb/sram_blackbox.sv` มีไว้ lint/smoke

physical flowใช้ PDK macro Verilog views

---

# 103. Macro location tuning

เมื่อ real O'SoCใหญ่ขึ้น SRAMตำแหน่งอาจต้องเปลี่ยน

---

# 104. Floorplan tuning order

หาก congestion:
1. move macro
2. enlarge core
3. reduce density
4. inspect high-fanout/long nets

---

# 105. Real SoC swap

อ่าน:
```text
integration/LAB21_TO_LAB22.md
```

---

# 106. Real SoC blocks

must include:
```text
CPU
Boot ROM
XIP
SRAM
GPIO
Timer
PLIC
CSR/Trap
```

---

# 107. Maintain chip_core contract

real core swapไม่ควรเปลี่ยน package-facing pad contractโดยไม่ตั้งใจ

---

# 108. Real CPU stall

preserve:
```text
cpu_stall = imem_stall | dmem_stall
```

---

# 109. Real SoC SRAM hierarchy

หลัง synthให้ค้น exact instanceอีกครั้ง

---

# 110. Level-B synthesis

actual CPUต้องไม่มี unmapped logic

---

# 111. Lab21 regression before P&R

real SoC revisionต้องผ่าน Lab21 regressionก่อน

---

# 112. Lab21 regression after ECO

หลัง functional ECO:
- rerun Lab21
- rerun impacted Lab22 stages

---

# 113. Signoff state classification

ใช้:
```text
PASS
FAIL
WAIVED
NOT PROVEN
```

---

# 114. Skipped is not PASS

```text
skipped DRC = NOT PROVEN
skipped LVS = NOT PROVEN
```

---

# 115. Training vs production

die size, pad count, loads, output delays และ power pad countเป็น training baseline

---

# 116. External SPI timing

ต้องแทน SDC assumptionsด้วย Flash/package/PCB timingจริงก่อน product closure

---

# 117. Power pad sizing

2 VDD + 2 VSSเป็น workshop baseline

real current requirementอาจต้องมากกว่านี้

---

# 118. IO power

IOVDD/IOVSSเป็น separate I/O supply domain

---

# 119. PDN/IR review

power connectivityต้อง reviewทั้ง geometryและ reports

---

# 120. EM caveat

IR drop passไม่เท่ากับ electromigration signoff

---

# 121. SRAM timing corners

macro Libertyต้องโหลดสำหรับ relevant corners

---

# 122. PDK revision discipline

บันทึก:
- PDK path/revision
- LibreLane version
- OpenROAD version
- config checksum

---

# 123. Final artifact set

releaseควรประกอบด้วย:
```text
GDS
netlist
DEF
LEF
SDC
SPEF if generated
reports
manifest
```

---

# 124. Final GDS integrity

อย่าดูแค่ file exists

ตรวจ:
- parse/openได้
- top cellถูก
- hierarchyครบ

---

# 125. LVS macro awareness

hard macro extraction/LVSอาจมี PDK-specific handling

ต้องใช้ viewsจาก PDK revisionเดียวกัน

---

# 126. DRC waiver discipline

ถ้ามี waiver:
- rule ID
- geometry
- reason
- owner
- approval
ต้องถูกบันทึก

---

# 127. Timing waiver discipline

timing exception/false pathต้องมี architectural reason

---

# 128. Clock uncertainty baseline

```text
0.25 ns
```

เป็น training assumption

---

# 129. Output load baseline

```text
0.033442
```

---

# 130. Output delay baseline

```text
4 ns
```

---

# 131. SPI MISO input delay

```text
max 2 ns
```

---

# 132. GUI review

ใช้ OpenROAD/KLayout GUIจาก installed flow version

---

# 133. Why scripts avoid invented GUI syntax

GUI CLIเปลี่ยนตาม version

helperแสดง latest run/state candidateแทน

---

# 134. Stage log checker

สามารถใช้:
```bash
python3 scripts/check_stage_log.py ...
```

เป็น conservative text scan

---

# 135. Human review still required

log checkerไม่แทน engineer review

---

# 136. Physical proof vs functional proof

Lab21:
```text
functional
```

Lab22:
```text
physical
```

ต้องผ่านทั้งคู่

---

# 137. Full-chip success condition

full-chip successต้องมี evidenceในทุก domain:
- logic
- timing
- geometry
- power
- release

---

# 138. Tapeout readiness

Labนี้เป็น training/reference flow

foundry/shuttle checklistจริงยังเป็น authorityสุดท้าย

---

# 139. Recommended sequence

```bash
make clean

make setup-bondpad IHP_TEMPLATE_ROOT=...

make check-env
make check-config
make check-pad-plan
make preflight

make lint
make smoke

make synth
make floorplan
make place
make cts
make route
make full

make copy-final
make check-final
make summarize-signoff
make report
make manifest
```

---

# 140. Level-A pass checklist

```text
[ ] real bondpad GDS
[ ] config contract
[ ] pad plan
[ ] lint
[ ] smoke
[ ] synth
[ ] SRAM macro
[ ] floorplan
[ ] PDN
[ ] placement
[ ] CTS
[ ] route
[ ] post-route timing
[ ] antenna
[ ] DRC
[ ] LVS
[ ] IR
[ ] GDS
[ ] manifest
```

---

# 141. Level-B pass checklist

```text
[ ] actual Lab21 SoC
[ ] actual CPU
[ ] XIP controller
[ ] PLIC/CSR/Timer/GPIO
[ ] one real SRAM
[ ] no unmapped logic
[ ] macro hierarchy updated
[ ] Lab21 functional regression still PASS
[ ] post-route STA reviewed
[ ] DRC/LVS reviewed
```

---

# 142. What is not proven

Lab22 aloneไม่พิสูจน์:
- DFT coverage
- package reliability
- ESD compliance
- EM signoff
- silicon functionality
- secure boot

---

# 143. Possible next Lab

natural next:
```text
Lab 23 — Gate-Level/Post-Layout Simulation + SDF
```

หรือ:
```text
Lab 23 — DFT/Scan/MBIST
```

---

# 144. Engineering rule 1

> A full-chip run is only as trustworthy as the physical views, constraints,
macro hierarchy and signoff evidence used by that exact run.

---

# 145. Engineering rule 2

> `Flow complete` is a tool status. `Tapeout ready` is an engineering decision
supported by timing, DRC, LVS, power, manufacturability and release evidence.
