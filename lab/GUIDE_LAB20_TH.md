# Lab 20 — O'SoC 1.0 Full-Chip RTL-to-GDSII using LibreLane + IHP SG13G2
## Deep Step-by-Step Ready-to-Run Guide

คู่มือนี้เป็น physical-design culmination ของ O'SoC Labs 12–19

---

# 1. วัตถุประสงค์

Lab 20 นำ O'SoC จากระดับ RTL/SoC integration ไปสู่ full-chip physical
implementation ด้วย LibreLane `Chip` flow และ IHP SG13G2

เป้าหมายต้องเห็นครบ:

```text
RTL
 -> Synthesis
 -> Full-chip floorplan
 -> Pad ring
 -> SRAM macro placement
 -> PDN
 -> Placement
 -> CTS
 -> Global routing
 -> Detailed routing
 -> RC extraction / timing
 -> DRC
 -> LVS
 -> GDS streamout
```

---

# 2. เหตุผลที่ใช้ LibreLane Chip flow

`Chip` flow ถูกออกแบบสำหรับ complete chip มากกว่า core-only flow เพราะมี
pad-ring generation, filler/seal/density-related full-chip steps และ signoff
integration

ห้ามเปลี่ยนกลับเป็น core-only flow เพียงเพราะ synthesis ง่ายกว่า

---

# 3. Physical verification levels

Lab นี้แบ่งเป็น:

```text
Level A — Physical closure training shell
Level B — Real O'SoC CPU subsystem
```

Level A ใช้ `osoc20_training_soc.sv` เพื่อให้ debug physical flow ได้โดยไม่
ผูกกับ CPU integration revision

Level B เปลี่ยนข้างใน `chip_core` เป็น O'SoC จริงจาก Lab 19

---

# 4. Baseline chip dimensions

ใช้ baseline:

```text
Die  = 1600 x 1600 um
Core = (365,365) to (1235,1235)
```

พื้นที่นี้เป็น starting point ไม่ใช่ production optimum

---

# 5. Clock baseline

clock:

```text
50 MHz
20 ns
```

full-chip port:

```text
clk_PAD
```

clock pin หลัง I/O pad:

```text
clk_pad/p2c
```

---

# 6. Reset

reset เป็น active-low asynchronous:

```text
rst_n_PAD
```

SDC ตั้ง false path จาก reset port เพื่อไม่ให้ STA ปฏิบัติต่อ reset
เหมือน synchronous data path

---

# 7. Full-chip signal pads

signal pads:

```text
clk
reset
spi_miso
spi_cs_n
spi_sck
spi_mosi
gpio[7:0]
```

รวม 14 signal pads

---

# 8. Power pads

baseline:

```text
2 x VDD
2 x VSS
2 x IOVDD
2 x IOVSS
```

รวม 8 power-domain pads

total pad instances:

```text
22
```

---

# 9. SPI pad direction

```text
SPI_MISO : input
SPI_CS_N : output
SPI_SCK  : output
SPI_MOSI : output
```

SPI SCK เป็น external protocol output ไม่ใช่ internal CTS clock domain
ใน baseline นี้

---

# 10. IHP pad cells

ใช้:

```text
sg13g2_IOPadIn
sg13g2_IOPadOut30mA
sg13g2_IOPadVdd
sg13g2_IOPadVss
sg13g2_IOPadIOVdd
sg13g2_IOPadIOVss
```

physical flow ต้องใช้ IHP PDK models จริง ไม่ใช้ `tb/io_cells_stub.sv`

---

# 11. Simulation stubs

ไฟล์:

```text
tb/io_cells_stub.sv
tb/sram_blackbox.sv
```

มีไว้ lint/smoke เท่านั้น

ห้ามเพิ่มเข้า LibreLane `VERILOG_FILES`

---

# 12. SRAM macro

hard macro:

```text
RM_IHPSG13_1P_1024x32_c2_bm_bist
```

ขนาด logical:

```text
1024 words x 32 bit
= 4 KiB
```

---

# 13. SRAM exact interface

Lab ใช้ official port contract:

```text
A_CLK
A_MEN
A_WEN
A_REN
A_ADDR[9:0]
A_DIN[31:0]
A_DLY
A_DOUT[31:0]
A_BM[31:0]
BIST signals
```

`A_DLY` ต้อง tie high

---

# 14. SRAM byte mask

CPU bus ใช้ byte strobes:

```text
wstrb[3:0]
```

macro ใช้ bit mask:

```text
A_BM[31:0]
```

wrapper ขยาย 1 byte strobe เป็น 8 bit mask

---

# 15. SRAM BIST pins

ใน Lab 20 functional baseline:

```text
A_BIST_EN=0
A_BIST_* tied inactive
```

DFT/MBIST จะเป็น extension ภายหลัง

---

# 16. SRAM physical views

LibreLane config อ้างจาก PDK:

```text
GDS
LEF
Verilog
behavioral SRAM model
Liberty typ/fast/slow
```

อย่า copy macro GDS เข้า RTL directory

---

# 17. SRAM instance hierarchy

baseline exact instance:

```text
i_chip_core.i_osoc.i_sram.sram_0
```

ชื่อนี้ใช้พร้อมกันใน:

```text
MACROS.instances
PDN_MACRO_CONNECTIONS
pdn_cfg.tcl
```

ถ้า real CPU hierarchy เปลี่ยน ต้องแก้ทั้งสามจุด

---

# 18. SRAM placement

baseline:

```text
location = [700,680]
orientation = N
```

หลัง floorplan ต้องเปิด OpenROAD GUI ตรวจ:
- อยู่ใน core
- ไม่ชน pad/core ring
- มี routing channel
- PDN สามารถเข้าถึง macro

---

# 19. Bondpad

`bondpad_70x70_novias` ต้องมี real GDS

Lab ไม่สร้าง fake binary GDS

ให้ copy จาก local clone ของ official IHP LibreLane template

---

# 20. Setup bondpad

```bash
make setup-bondpad \
  IHP_TEMPLATE_ROOT=~/src/ihp-sg13g2-librelane-template
```

จากนั้น:

```bash
ls -lh ip/bondpad_70x70_novias/gds/
```

---

# 21. Bondpad preflight

```bash
make preflight
```

ต้องเห็น:

```text
PASS REAL bondpad GDS
```

ถ้า fail ห้ามเริ่ม full flow

---

# 22. LibreLane config metadata

```yaml
meta:
  version: 3
  flow: Chip
```

Lab ใช้ config v3

---

# 23. SystemVerilog frontend

เปิด:

```yaml
USE_SLANG: true
SLANG_ARGUMENTS:
  - --keep-hierarchy
```

เพื่อรองรับ SystemVerilog ได้ดีกว่า parser baseline

---

# 24. Source list

physical source list:

```text
chip_top.sv
chip_core.sv
osoc20_training_soc.sv
ihp_sram_4k.sv
```

simulation stubs ไม่อยู่ใน list

---

# 25. Power nets

```yaml
VDD_NETS: [VDD]
GND_NETS: [VSS]
```

ชื่อ power nets ต้องสอดคล้องกับ IHP pad/PDN conventions

---

# 26. Pad ring South

South มี:

```text
clk
reset
SPI MISO
VDD0
VSS0
```

---

# 27. Pad ring East

East:

```text
SPI CS
SPI SCK
SPI MOSI
GPIO0
GPIO1
IOVDD0
```

---

# 28. Pad ring North

North:

```text
GPIO7..GPIO2
IOVSS0
```

---

# 29. Pad ring West

West:

```text
VDD1
VSS1
IOVDD1
IOVSS1
```

---

# 30. Escaped generated names

generated pad instancesมี brackets

LibreLane YAML ต้อง escape เช่น:

```text
"outputs\\[7\\].output_pad"
```

ห้ามเขียน `outputs[7].output_pad` แบบไม่ escape แล้วคาดว่า Tcl/OpenROAD จะตรง

---

# 31. SDC

file:

```text
librelane/chip_top.sdc
```

constrains clock หลัง input pad:

```text
clk_pad/p2c
```

---

# 32. Clock uncertainty

baseline:

```text
0.25 ns
```

เป็น workshop assumption ไม่ใช่ signoff jitter model

---

# 33. I/O delays

MISO input:

```text
max 2 ns
```

outputs:

```text
max 4 ns
```

ต้องแทนด้วย board/Flash timing ก่อน production

---

# 34. Output load

baseline:

```text
0.033442
```

เป็น training load assumption

---

# 35. Floorplan

absolute floorplan ทำให้ pad/macro exercise deterministic

อย่าเริ่มด้วย aggressive utilization

---

# 36. Placement density

baseline:

```yaml
PL_TARGET_DENSITY_PCT: 20
```

real CPU อาจต้องเพิ่ม die/core area มากกว่าการดัน density

---

# 37. Congestion policy

baseline config:

```yaml
GRT_ALLOW_CONGESTION: true
```

มีไว้ช่วย early bring-up

ก่อน final signoff ควรแก้ congestion root cause และทดลอง false

---

# 38. PDN core ring

```yaml
PDN_CORE_RING: true
PDN_CORE_RING_CONNECT_TO_PADS: true
```

เป้าหมายคือเชื่อม core power mesh เข้ากับ power pads

---

# 39. PDN ring geometry

baseline:

```text
width   15 um
spacing 5 um
```

ต้องตรวจ DRC/IR และ current requirement

---

# 40. PDN_ENABLE_PINS

```yaml
PDN_ENABLE_PINS: false
```

ใช้ patternเดียวกับ official full-chip template

---

# 41. Custom PDN config

file:

```text
librelane/pdn_cfg.tcl
```

สร้าง:
- stdcell grid
- rails
- core ring
- SRAM macro grid

---

# 42. SRAM PDN

macro gridเพิ่ม stripe บน:

```text
Metal5
```

และ connect:

```text
Metal4 <-> Metal5
Metal5 <-> TopMetal1
```

---

# 43. PDN macro connections

SRAM power aliases:

```text
VDDARRAY!
VDD!
VSS!
```

ต้อง bind กับ top-level `VDD/VSS`

---

# 44. Environment check

```bash
make check-env
```

required:

```text
python3
librelane
yosys
verilator
```

---

# 45. Find PDK

```bash
python3 scripts/find_pdk.py
```

ช่วยค้นหา `ihp-sg13g2` ใต้ common PDK roots

---

# 46. PDK macro views check

ตั้ง:

```bash
export IHP_PDK=/path/to/ihp-sg13g2
```

แล้ว:

```bash
python3 scripts/check_pdk_views.py
```

---

# 47. Static config check

```bash
make check-config
```

ตรวจ config keys ที่ critical

---

# 48. RTL lint

```bash
make lint
```

ใช้ simulation-only stubs

PASS ของ lint ไม่ได้ยืนยัน PDK macro timing/physical views

---

# 49. Synthesis run

```bash
make synth
```

ใช้:

```text
--to Yosys.Synthesis
```

เพื่อ debug RTL/macro mapping ก่อน floorplan

---

# 50. Synthesis pass criteria

ต้องตรวจ:
- no unmapped logic
- one SRAM macro instance
- pad cells not destroyed
- expected clocks/nets exist

---

# 51. Unmapped cell failure

ถ้า:

```text
Checker.YosysUnmappedCells
```

fail ให้หา cell exact name จาก synthesis netlist/report

ห้ามแก้โดย disable checker ก่อนรู้ root cause

---

# 52. Floorplan/PDN run

```bash
make floorplan
```

endpoint:

```text
OpenROAD.GeneratePDN
```

---

# 53. Floorplan visual inspection

เปิด OpenROAD GUI แล้วตรวจ:
- die/core boundary
- 4 pad sides
- SRAM
- core ring
- straps
- no macro outside core

---

# 54. Pad ring check

จำนวน pad plan expected:

```text
22
```

ถ้าหายแม้หนึ่งตัวให้หยุดก่อน placement

---

# 55. Macro path failure

ถ้า LibreLane บอก macro instance missing:
1. inspect synthesized hierarchy
2. copy exact instance name
3. update MACROS/PDN/pdn_cfg

---

# 56. Placement run

```bash
make place
```

ใช้ endpoint:

```text
OpenROAD.GlobalPlacement
```

---

# 57. Placement review

ดู:
- core utilization
- macro halo
- channels รอบ SRAM
- dense clusters
- pad-to-core fanout

---

# 58. CTS run

```bash
make cts
```

clock root อยู่หลัง pad:

```text
clk_pad/p2c
```

---

# 59. CTS review

ตรวจ:
- inserted buffers
- max slew
- max cap
- clock skew
- hold fixing
- macro clock path

---

# 60. Route run

```bash
make route
```

endpoint:

```text
OpenROAD.DetailedRouting
```

---

# 61. Routing review

ตรวจ:
- global overflow
- detailed-route DRC
- antenna repair
- pad escape routing
- routes around SRAM
- PDN blockage interaction

---

# 62. Do not hard-code routing layers

อย่าใส่ layer names จาก technology อื่น เช่น `met5`

ให้ IHP PDK/LibreLaneกำหนด routing stack

custom PDN ใช้ IHP layer namesเพราะเป็น PDK-specific PDN recipe

---

# 63. Full run

หลัง staged runs ผ่าน:

```bash
make full
```

run ทั้ง Chip flow

---

# 64. Full flow is not automatically tapeout approval

`Flow complete` แปลว่า tool sequence complete

ยังต้อง review:
- timing
- DRC
- LVS
- antenna
- IR drop
- GDS hierarchy

---

# 65. KLayout GDS

primary:

```yaml
PRIMARY_GDSII_STREAMOUT_TOOL: klayout
```

เปิด final GDS visually

---

# 66. Magic

Magicสามารถเป็น secondary verification/streamout path ขึ้นกับ flow/PDK support

ผล KLayout และ Magic ไม่ควรถูกตีความว่าแทนกันทุกกรณี

---

# 67. DRC

DRC PASS ต้องหมายถึง:
- checkerรันจริง
- reportถูกอ่าน
- zero unwaived violations หรือมี formal disposition

---

# 68. LVS

LVSตรวจ:

```text
layout connectivity
vs
intended netlist
```

ไม่ใช่ functional simulation

---

# 69. SRAM LVS awareness

SRAM hard macrosอาจมี PDK-specific extraction/LVS handling

ถ้ามี mismatch:
- verify exact PDK revision
- verify macro CDL/GDS
- inspect documented IHP issues
- ห้าม black-box LVS โดยไม่บันทึกเหตุผล

---

# 70. Antenna

antenna resultต้อง review

repair diode/jumper อาจเพิ่ม routing/timing impact

---

# 71. RC extraction

post-route timingควรใช้ routed parasitics

pre-route timingไม่ใช่ signoff timing

---

# 72. Multi-corner STA

reviewอย่างน้อย corner setที่ PDK/flowเตรียม:

```text
typical
fast
slow
```

ทั้ง setup/hold

---

# 73. IR drop

IR-drop reportช่วยประเมิน PDN

ไม่เท่ากับ full EM signoff

---

# 74. Power pads

จำนวน 2+2 core power padsเป็น training baseline

real chipต้อง dimensionจาก:
- total power
- current density
- package
- IR/EM

---

# 75. IO power domain

IOVDD/IOVSS แยกจาก core VDD/VSS

ต้องรักษา domain semantics ใน pad ring และ package

---

# 76. Bondpad geometry

LEF size:

```text
70 x 70 um
```

GDSต้องเป็น official geometry

---

# 77. Why no fabricated GDS

binary GDS ที่สร้างเองโดยไม่มี official geometryทำให้:
- DRC meaningless
- bondability unknown
- package planผิด
- tapeout unsafe

---

# 78. Copy final

หลัง full run:

```bash
make copy-final
```

scriptคัดลอก runล่าสุด `final/`

---

# 79. Check final

```bash
make check-final
```

ตรวจ candidate views:

```text
GDS
netlist
DEF
LEF
```

---

# 80. Report

```bash
make report
```

สร้าง:

```text
reports/LAB20_REPORT.md
```

---

# 81. Release manifest

```bash
make manifest
```

สร้าง SHA256 manifest:

```text
release/manifest.json
```

---

# 82. Why checksum

ทำให้รู้ว่า:
- GDS versionใด
- netlist versionใด
- config versionใด
- reportชุดใด

อยู่ใน releaseเดียวกัน

---

# 83. Recommended run order

```bash
make clean
make setup-bondpad IHP_TEMPLATE_ROOT=...
make check-env
make preflight
make check-config
make lint
make synth
make floorplan
make place
make cts
make route
make full
make copy-final
make check-final
make report
make manifest
```

---

# 84. OpenROAD GUI

หลังแต่ละ stageสามารถใช้ LibreLane/OpenROAD stateของ runนั้นเปิด GUI

จุดประสงค์คือดู geometry ไม่ใช่เพียงอ่านข้อความ report

---

# 85. KLayout review

final GDSต้องตรวจ:
- top cell
- die outline
- pad ring
- bondpads
- SRAM hierarchy
- routed core
- PDN

---

# 86. Level-B real O'SoC swap

อ่าน:

```text
integration/REAL_OSOC_CPU_SWAP.md
```

เปลี่ยน training shellเป็น subsystemจริง

---

# 87. Real O'SoC blocks

Level-Bควรมี:

```text
CPU
Boot ROM
XIP controller
IHP SRAM
GPIO
Timer
PLIC
CSR/Trap
```

---

# 88. Keep physical interface stable

ตอน swap core ห้ามเปลี่ยน full-chip portsโดยไม่ตั้งใจ

รักษา:

```text
clk
reset
SPI 4 signals
GPIO[7:0]
```

---

# 89. Real SRAM hierarchy

หลัง synth real core:
ค้นหา exact SRAM instance

อย่า assumeว่าชื่อเดิมยังอยู่

---

# 90. Real CPU synthesis

PASS ต้องไม่มี unresolved CPU cells

โดยเฉพาะ:
- CSR extensions
- adapters
- package imports
- macro wrapper

---

# 91. Instruction XIP timing

XIPเป็น multi-cycle architecture

physical STA constrains synchronous internal controller logic
ไม่ใช่บังคับให้ external Flashตอบใน 20 ns

---

# 92. SPI external timing

ต้องสร้าง board/device timing modelในขั้น productization

Lab 20 SDC เป็น baselineเท่านั้น

---

# 93. SRAM synchronous timing

hard macro Libertyกำหนด:
- setup/hold
- clock-to-Q
- control timing

LibreLaneต้องโหลด macro `.lib`

---

# 94. Macro Liberty corners

configอ้าง:

```text
typ_1p20V_25C
fast_1p32V_m55C
slow_1p08V_125C
```

corner namesต้องตรง PDK revisionจริง

---

# 95. PDK revision discipline

เก็บ:
- PDK commit/version
- LibreLane version
- OpenROAD version
- config hash

ใน release notes

---

# 96. Why current official template matters

full-chip keys/pad/PDN patternsเปลี่ยนได้ตาม LibreLane/PDK

ใช้ official IHP templateเป็น source of truthก่อนแก้ config

---

# 97. Common error: unknown config key

ถ้า LibreLaneบอก:

```text
Unknown key
```

ให้ลบ/renameตาม documentationของ versionที่กำลังใช้

อย่าใช้ keyจาก OpenLane1/LibreLaneเก่าโดยอัตโนมัติ

---

# 98. Common error: --tag

LibreLane v3 flowของ environmentนี้ใช้:

```text
--run-tag
```

ไม่ใช่:

```text
--tag
```

---

# 99. Common error: validate-only

อย่าพึ่ง:

```text
--validate-only
```

ถ้า versionไม่มี option

ใช้ preflight scriptsและ staged `--to`

---

# 100. Common error: pad name mismatch

Pad placerต้องใช้ synthesized instance name exact

generated namesต้อง escape brackets

---

# 101. Common error: macro GDS path

macro physical viewควรใช้:

```text
pdk_dir::libs.ref/...
```

ไม่ควร pointไป simulation `.v`

---

# 102. Common error: SRAM blackbox in synthesis

simulation `tb/sram_blackbox.sv` มีไว้ lint

LibreLaneต้องใช้ PDK macro `vh`

---

# 103. Common error: A_DLY

IHP SRAM modelตรวจว่า:

```text
A_DLY == 1
```

จึง tie:

```systemverilog
.A_DLY(1'b1)
```

---

# 104. Common error: PDN cannot reach SRAM

ตรวจ:
- macro orientation
- macro top metal
- PDN grid
- halo
- location
- power aliases

---

# 105. Common error: congestion

ทางแก้ลำดับแรก:
- enlarge core
- move SRAM
- add routing channel
- reduce density

ไม่ใช่เปิด allow congestionตลอด

---

# 106. Common error: hold explosion

ถ้า post-CTSเพิ่ม hold buffersจำนวนมาก:
- inspect clock tree
- macro path
- min-delay paths
- placement density
- constraint realism

---

# 107. Common error: DRC skipped

ถ้า checkerถูก skip:

```text
NOT PROVEN
```

อย่าเขียนใน reportว่า DRC pass

---

# 108. Common error: LVS skipped

same principle:

```text
LVS disabled != LVS pass
```

---

# 109. Final Level-A pass criteria

```text
[ ] real bondpad GDS present
[ ] RTL lint clean/understood
[ ] synthesis no unmapped cells
[ ] SRAM macro found
[ ] 22 pad instances placed
[ ] PDN generated
[ ] placement completes
[ ] CTS completes
[ ] routing completes
[ ] timing reviewed
[ ] antenna reviewed
[ ] DRC reviewed
[ ] LVS reviewed
[ ] final GDS opened
[ ] release manifest generated
```

---

# 110. Final Level-B pass criteria

เพิ่ม:

```text
[ ] actual O'SoC CPU present
[ ] Boot ROM/XIP integration preserved
[ ] one real IHP SRAM macro
[ ] GPIO/Timer/PLIC/CSR/SPI synthesize
[ ] no unmapped cells
[ ] real hierarchy reflected in macro/PDN config
[ ] post-route timing reviewed on real CPU
```

---

# 111. What this Lab does not prove

ไม่พิสูจน์:
- foundry tapeout acceptance
- package reliability
- ESD signoff
- EM signoff
- silicon functionality
- external Flash timing across PVT
- DFT/scan coverage

ต้องมี separate methodology

---

# 112. Tapeout checklist mindset

releaseต้องมี evidence ไม่ใช่ความรู้สึก:

```text
config
tool versions
reports
netlist
GDS
DRC/LVS
timing
IR
manifest
waivers
```

---

# 113. Next extension

หลัง Lab 20:

```text
Lab 21 — DFT/Scan + MBIST integration
```

หรือ:

```text
Lab 21 — Package/Bond Plan + Board Bring-Up
```

ขึ้นกับเป้าหมาย course

---

# 114. Engineering rule

> Full-chip flow success is necessary but not sufficient for tapeout readiness.

และ:

> Hard macros, power delivery, pad-ring geometry, timing, DRC/LVS and release
evidence must all refer to the same exact design revision.
