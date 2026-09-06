# Lab 3 — Core-Only Synthesis
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + LibreLane + IHP SG13G2

**Design:** `osoc1_cpu_core`  
**Technology:** IHP SG13G2  
**Flow:** LibreLane `SynthesisExploration`  
**SystemVerilog frontend:** Slang  
**Baseline clock:** 50 MHz / 20 ns  
**Optional sweep:** 50 / 100 / 200 MHz

---

# 1. จุดประสงค์ของ Lab 3

Lab 1 ตอบว่า:

```text
CPU มี architecture อย่างไร?
```

Lab 2 ตอบว่า:

```text
RTL พร้อม synthesis หรือยัง?
```

Lab 3 ต้องตอบว่า:

```text
เมื่อ map CPU ลง IHP SG13G2 แล้ว
hardware ที่ synthesis สร้างขึ้นมีลักษณะอย่างไร?
```

สิ่งที่ต้องวัด ได้แก่:

```text
mapped cell count
unmapped cell count
standard-cell area
timing baseline
WNS / TNS
technology-mapped netlist
frequency sensitivity
```

Lab นี้ยังเป็น **Core-Only**

ยังไม่มี:

```text
chip_top
I/O pads
bondpads
floorplan
PDN
placement
CTS
routing
DRC
LVS
```

การแยก core synthesis ออกจาก full-chip implementation มีประโยชน์มาก เพราะถ้า synthesis fail เรารู้ทันทีว่าปัญหาอยู่ที่:

```text
RTL
frontend
constraint
technology mapping
```

ไม่ใช่:

```text
pad ring
PDN
floorplan
routing
```

---

# 2. Data Flow ของ Lab

```text
        SystemVerilog RTL
                |
                v
        +---------------+
        |     Slang     |
        |   frontend    |
        +-------+-------+
                |
                v
        +---------------+
        |     Yosys     |
        | elaboration   |
        | optimization  |
        +-------+-------+
                |
                v
        +---------------+
        | ABC / mapping |
        +-------+-------+
                |
                v
     IHP SG13G2 standard cells
                |
                +--------------------+
                |                    |
                v                    v
       mapped netlist          synthesis metrics
                                     |
                                     v
                              pre-PnR OpenSTA
                              (explore mode)
```

---

# 3. Scope และข้อจำกัด

ผล area ใน Lab นี้หมายถึง:

```text
sum of synthesized standard-cell instance area
```

ไม่ใช่:

```text
die area
core area
final placed area
final chip area
```

ผล timing ใน Lab นี้หมายถึง:

```text
pre-PnR timing
```

จึงยังไม่มี:

```text
placed wire length
clock-tree insertion delay
post-CTS skew
routed RC
extracted parasitics
signal integrity
```

ดังนั้น:

> WNS/TNS ใน Lab 3 เป็น architecture/synthesis indicator ไม่ใช่ signoff result

---

# 4. ตรวจ RTL Top ก่อนเริ่ม

CPU top จริงคือ:

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

ดังนั้น Lab ใช้:

```yaml
DESIGN_NAME: osoc1_cpu_core
```

และ:

```yaml
CLOCK_PORT: clk_i
```

---

# 5. Canonical Source Set

ไฟล์:

```text
config/source_manifest.txt
```

ประกอบด้วย:

```text
src/cpu_sv_package.sv
src/pc_reg.sv
src/pc_plus_4.sv
src/decoder.sv
src/ctrl.sv
src/alu_in_muxes.sv
src/alu.sv
src/sau.sv
src/lau.sv
src/rf_wb_mux.sv
src/reg_file.sv
src/bcu.sv
src/next_pc_logic.sv
src/osoc1_cpu_core.sv
```

ไม่ใช้:

```text
src/rf_wb_mux.flat.v
src/chip_core.sv
src/chip_top.sv
```

---

# 6. ติดตั้ง Lab

แนะนำ directory:

```text
~/workshop/synpnr_osoc1_cpu/
├── src/
└── labs/
    └── lab03_core_only_synthesis/
```

เข้า Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab03_core_only_synthesis
```

ถ้า Lab อยู่คนละตำแหน่ง:

```bash
make \
  REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu \
  preflight
```

---

# 7. เข้า LibreLane + IHP Environment

Lab 3 ต้องใช้ technology library จริง จึงต้องมี:

```text
LibreLane
IHP SG13G2 PDK
Yosys
OpenROAD/OpenSTA
Slang support
```

หากใช้ official IHP template environment:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

หากยังไม่มี PDK:

```bash
make clone-pdk
```

จากนั้นกลับ Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab03_core_only_synthesis
```

---

# 8. Step 1 — Environment Check

รัน:

```bash
make check-env
```

ต้องพบอย่างน้อย:

```text
python3
verilator
yosys
librelane
```

ตัวอย่าง:

```text
PASS required python3
PASS required verilator
PASS required yosys
PASS required librelane
```

บันทึกที่:

```text
reports/00_environment.log
```

---

# 9. Step 2 — Freeze RTL Source Revision

รัน:

```bash
make check-src
```

script จะ:

```text
verify file existence
verify package-first order
verify top
exclude rf_wb_mux.flat.v
compute SHA256 prefix
```

ผล:

```text
reports/01_source_freeze.txt
```

ทำไมต้อง hash source?

เพราะถ้าผล PPA เปลี่ยน เราต้องแยกให้ออกว่าเกิดจาก:

```text
constraint changed
tool changed
PDK changed
RTL changed
```

hash ช่วยยืนยันกรณีสุดท้าย

---

# 10. Step 3 — สร้าง Frequency Points

ไฟล์:

```text
config/sweep.csv
```

มี:

```csv
name,frequency_mhz,period_ns
50MHz,50,20.000
100MHz,100,10.000
200MHz,200,5.000
```

สูตร:

```text
T(ns) = 1000 / f(MHz)
```

ดังนั้น:

```text
50 MHz  -> 20 ns
100 MHz -> 10 ns
200 MHz -> 5 ns
```

---

# 11. Step 4 — Generate SDC + LibreLane Config

รัน:

```bash
make prepare
```

จะสร้าง:

```text
build/
├── 50MHz/
│   ├── config.yaml
│   └── osoc1_cpu_core.sdc
├── 100MHz/
│   ├── config.yaml
│   └── osoc1_cpu_core.sdc
└── 200MHz/
    ├── config.yaml
    └── osoc1_cpu_core.sdc
```

จุดสำคัญคือ paths ไป RTL ถูก generate เป็น absolute paths

จึงไม่ต้องแก้ YAML เมื่อย้าย Lab

---

# 12. Generated LibreLane Configuration

ตัวอย่าง 50 MHz:

```yaml
meta:
  version: 3
  flow: SynthesisExploration

DESIGN_NAME: osoc1_cpu_core

VERILOG_FILES:
  - "/absolute/path/src/cpu_sv_package.sv"
  ...
  - "/absolute/path/src/osoc1_cpu_core.sv"

USE_SLANG: true

SLANG_ARGUMENTS:
  - --keep-hierarchy

PNR_SDC_FILE: "/absolute/path/build/50MHz/osoc1_cpu_core.sdc"
SIGNOFF_SDC_FILE: "/absolute/path/build/50MHz/osoc1_cpu_core.sdc"
FALLBACK_SDC: "/absolute/path/build/50MHz/osoc1_cpu_core.sdc"

CLOCK_PORT: clk_i
CLOCK_PERIOD: 20.000

SYNTH_AUTONAME: true
```

---

# 13. ทำไมใช้ Slang

RTL ใช้:

```systemverilog
import cpu_sv_package::*;
```

และ package enums

เช่นใน top:

```systemverilog
alu_op_e alu_op;
wb_sel_e d2r;
```

ดังนั้น frontend ต้อง handle SystemVerilog package/type semantics ได้ดี

Lab จึงใช้:

```yaml
USE_SLANG: true
```

แทนการบังคับ native Yosys parser ให้รับ syntax ทุกอย่าง

---

# 14. Baseline SDC

50 MHz:

```tcl
create_clock \
  -name core_clk \
  -period 20.000 \
  [get_ports clk_i]
```

uncertainty:

```tcl
set_clock_uncertainty 0.250 \
  [get_clocks core_clk]
```

instruction input:

```tcl
set_input_delay 2.000 \
  -clock core_clk \
  [get_ports instr_i]
```

data-memory read:

```tcl
set_input_delay 2.000 \
  -clock core_clk \
  [get_ports dmem_rdata_i]
```

outputs:

```tcl
set_output_delay 4.000 \
  -clock core_clk \
  [get_ports pc_o]

set_output_delay 4.000 \
  -clock core_clk \
  [get_ports dmem_we_o]

set_output_delay 4.000 \
  -clock core_clk \
  [get_ports dmem_addr_o]

set_output_delay 4.000 \
  -clock core_clk \
  [get_ports dmem_wdata_o]
```

reset:

```tcl
set_false_path \
  -from [get_ports rst_ni]
```

---

# 15. Fixed vs Scaled I/O Timing Budget

default:

```bash
IO_MODE=fixed
```

หมายถึงทุก frequency ใช้:

```text
input delay  = 2 ns
output delay = 4 ns
```

ข้อดี:

```text
external-interface assumption คงที่
```

ทำให้ 100/200 MHz เป็น genuine timing stress

แต่ที่ 200 MHz:

```text
clock period = 5 ns
```

output delay 4 ns เหลือ internal budget น้อยมาก

นี่อาจ intentional สำหรับ stress test

ถ้าต้องการ compare architecture โดย scale I/O budget ตาม clock:

```bash
make IO_MODE=scaled prepare
```

scaled mode ใช้ประมาณ:

```text
input_delay  = 10% period
output_delay = 20% period
```

ต้องระบุ mode ทุกครั้งเมื่อรายงานผล

ห้ามนำ fixed-mode PPA ไปเทียบ scaled-mode PPA โดยไม่บอก

---

# 16. Step 5 — Full Preflight

รัน:

```bash
make clean
make preflight
```

ทำ:

```text
environment check
source freeze
50/100/200 SDC generation
50/100/200 LibreLane config generation
config summary
```

expected:

```text
PASS: Lab 3 preflight complete.
```

อย่า run synthesis ถ้า preflight ยัง fail

---

# 17. Step 6 — 50 MHz Synthesis-Only Baseline

เริ่มที่ frequency ต่ำสุดก่อน:

```bash
make synth50
```

command หลัก:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow SynthesisExploration \
  --run-tag lab03_50MHz_synth \
  --to Yosys.Synthesis \
  build/50MHz/config.yaml
```

`--to Yosys.Synthesis` ทำให้ flow หยุดหลัง synthesis

นี่เหมาะกับคำถาม:

```text
RTL map ลง technology ได้ไหม?
```

โดยยังไม่ผสม STA result

---

# 18. สิ่งที่เกิดขึ้นใน Synthesis

conceptual transformations:

```text
RTL hierarchy
     |
     v
Elaboration
     |
     v
Process lowering
     |
     v
Mux/register inference
     |
     v
Boolean optimization
     |
     v
Generic gate representation
     |
     v
Technology mapping
     |
     v
IHP SG13G2 standard cells
```

---

# 19. Technology Mapping คืออะไร

ก่อน mapping logic อาจเป็น abstract:

```text
AND
OR
MUX
DFF
ADD
COMPARE
```

หลัง mapping ต้องกลายเป็น cells ใน target library

conceptually:

```text
generic AND
     |
     v
sg13g2_* standard cell

generic DFF
     |
     v
sg13g2_* sequential cell
```

ชื่อ cell จริงขึ้นกับ standard-cell library และ mapping decision

อย่าคาดเดาชื่อ exact cell จาก RTL ก่อนดู synthesis netlist/report

---

# 20. Step 7 — ตรวจ Synthesis Log

หลัง run:

```bash
make check-logs
```

หรือ:

```bash
grep -RniE \
  'ERROR|unmapped|not found|failed' \
  reports/lab03_50MHz_synth.log
```

เป้าหมาย:

```text
no frontend error
no missing module
no technology mapping failure
no unmapped design instance
```

---

# 21. Unmapped Cell คืออะไร

ต้องแยก:

### unresolved RTL hierarchy

ตัวอย่าง:

```text
module xyz not found
```

หมายถึง source/hierarchy issue

### unmapped synthesis logic

หมายถึง logic บางส่วนยังไม่ถูก technology map

ทั้งสองกรณี:

```text
ไม่ควรเข้าสู่ physical design
```

---

# 22. Step 8 — 50 MHz SynthesisExploration

หลัง synthesis-only ผ่าน:

```bash
make explore50
```

flow นี้ต่อเพิ่ม:

```text
Yosys.Synthesis
        |
OpenROAD.CheckSDCFiles
        |
OpenROAD.STAPrePNR
```

จึงตรวจได้ว่า:

```text
SDC ถูกอ่านหรือไม่
clock ถูก recognize หรือไม่
timing paths ถูกสร้างหรือไม่
pre-PnR WNS/TNS เป็นอย่างไร
```

---

# 23. Timing Definitions

## WNS — Worst Negative Slack

```text
WNS = slack ที่แย่ที่สุด
```

ถ้า:

```text
WNS = +1.2 ns
```

หมายถึง worst path ยังเหลือ margin

ถ้า:

```text
WNS = -0.8 ns
```

หมายถึง worst path miss constraint 0.8 ns

---

## TNS — Total Negative Slack

รวม negative slack ของ violating endpoints

เป้าหมาย:

```text
TNS = 0
```

---

# 24. Timing Pass ใน Lab 3 หมายถึงอะไร

ถ้า 50 MHz pre-PnR:

```text
WNS >= 0
TNS = 0
```

แปลว่า synthesis netlist ภายใต้ pre-PnR wire assumptions มี timing margin

ไม่ได้รับประกันว่า post-route จะผ่าน

เพราะต่อไปยังมี:

```text
placement
clock tree
routing
parasitics
```

---

# 25. Step 9 — Locate LibreLane Run Artifacts

รัน:

```bash
make find-runs
```

script จะค้น directories ที่มี:

```text
lab03_
```

ภายใต้ Lab และ repository root

ผล:

```text
reports/run_directories.txt
```

LibreLane version/environment ต่างกันอาจวาง run directory ต่างตำแหน่ง จึงไม่ hard-code path ใน metrics parser

---

# 26. Step 10 — Collect PPA Metrics

รัน:

```bash
make collect
```

script จะค้น JSON metric files ใน run trees และพยายามดึง:

```text
instance_count
unmapped_count
instance_area
WNS
TNS
```

สร้าง:

```text
results/ppa_summary.csv
results/ppa_summary.md
```

สำคัญ:

> metrics parser เป็น convenience extractor

ก่อนใช้ตัวเลขใน publication/tapeout review ต้อง cross-check source metrics file และ timing report

---

# 27. PPA Summary Format

ตัวอย่าง:

```text
| Point  | MHz | Instances | Unmapped | Area | WNS | TNS |
|--------|----:|----------:|---------:|-----:|----:|----:|
| 50MHz  |  50 | ...       | 0        | ...  | ... | ... |
| 100MHz | 100 | ...       | 0        | ...  | ... | ... |
| 200MHz | 200 | ...       | 0        | ...  | ... | ... |
```

---

# 28. Area ที่ต้องอ่านอย่างถูกต้อง

Synthesis cell area คือ:

```text
Σ area(mapped standard-cell instances)
```

ไม่รวม physical effects เช่น:

```text
placement whitespace
routing channels
PDN
clock-tree routing
IO ring
macro halo
decap/filler/tap cells
```

ดังนั้นห้ามเอา synthesis area ไปเรียกว่า:

```text
chip area
```

---

# 29. Instance Count ไม่ใช่ Transistor Count

เช่น:

```text
instance count = N
```

หมายถึงจำนวน mapped cell instances

แต่ cell แต่ละชนิดมี transistor count ต่างกัน

เช่น conceptual:

```text
inverter
NAND
AOI
DFF
MUX
```

จึงไม่สามารถบอก transistor count จาก instance count โดยตรง

---

# 30. Step 11 — 50/100/200 MHz Synthesis Sweep

เมื่อ baseline ผ่าน:

```bash
make sweep-synth
```

flow จะรัน:

```text
50 MHz  -> Yosys.Synthesis
100 MHz -> Yosys.Synthesis
200 MHz -> Yosys.Synthesis
```

จากนั้น:

```bash
make collect
```

วัตถุประสงค์คือดูว่า synthesis optimizer เปลี่ยน:

```text
cell count
cell sizing/mapping
area
```

เมื่อ clock constraint เข้มขึ้นหรือไม่

---

# 31. Step 12 — 50/100/200 MHz Timing Sweep

สำหรับ pre-PnR timing:

```bash
make sweep-explore
```

รัน SynthesisExploration ครบทุกจุด

จากนั้น:

```bash
make collect
```

---

# 32. วิธีวิเคราะห์ Frequency Sweep

อย่าดูเฉพาะ WNS

ให้ดู relationship:

```text
Frequency ↑
    |
    +--> Timing pressure ↑
    |
    +--> Mapping may change
    |
    +--> Cell area may increase
    |
    +--> Instance count may change
    |
    +--> WNS margin decreases
```

ตัวอย่าง interpretation:

```text
50 MHz:
timing easy, smallest mapping

100 MHz:
timing tighter, similar/slightly higher area

200 MHz:
large negative slack or more aggressive mapping
```

แต่ต้องใช้ผลจริง ไม่ควรสรุปก่อน run

---

# 33. Critical-Path Thinking

ถ้า timing fail อย่าเริ่มจากเพิ่ม die area เพราะ Lab นี้ยังไม่มี floorplan

ให้ถามว่า critical path อยู่ใน architecture ใด:

```text
register file -> ALU -> register file
instruction decode -> control -> datapath
ALU -> branch decision -> next PC
data input -> load alignment -> writeback
```

จาก top RTL เรารู้ว่ามี path สำคัญผ่าน:

```text
decoder
ctrl
reg_file
alu_in_muxes
alu
bcu
next_pc_logic
rf_wb_mux
lau
```

แต่ critical path จริงต้องดู timing report

---

# 34. ทำไม 200 MHz อาจ Fail แต่ Lab ยังมีคุณค่า

ถ้า 200 MHz:

```text
WNS < 0
```

ไม่ได้แปลว่า Lab fail

ถ้า objective คือ sweep exploration

มันบอก:

```text
current architecture + library + constraints
ไม่รองรับ target นี้ใน pre-PnR model
```

นี่คือ engineering result

แต่ technology mapping ต้องยัง clean:

```text
unmapped = 0
```

---

# 35. Synthesis Baseline vs Timing Target

แบ่ง result เป็น:

### Functional synthesis success

```text
mapping completed
unmapped = 0
netlist produced
```

### Timing success

```text
WNS >= 0
TNS = 0
```

design สามารถ synthesis success แต่ timing fail ได้

ห้ามใช้คำว่า synthesis failed เมื่อจริง ๆ เป็น timing target miss

---

# 36. Generate Final Lab Report

รัน:

```bash
make report
```

สร้าง:

```text
reports/LAB03_REPORT.md
```

บันทึก:

```text
Git revision
environment/tool versions
source hashes
generated configs
synthesis log checks
PPA summary
```

---

# 37. Recommended Run Sequence

Baseline:

```bash
make clean
make preflight
make synth50
make check-logs
make collect
make report
```

Full 50 MHz exploration:

```bash
make clean
make preflight
make explore50
make collect
make report
```

Frequency sweep:

```bash
make clean
make preflight
make sweep-explore
make collect
make report
```

---

# 38. ถ้า Lab ไม่ได้วางใต้ Repository

ใช้:

```bash
make \
  REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu \
  preflight
```

แล้ว:

```bash
make \
  REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu \
  explore50
```

หรือ:

```bash
./QUICKSTART.sh \
  $HOME/workshop/synpnr_osoc1_cpu
```

---

# 39. Troubleshooting — `librelane` ไม่พบ

```bash
which librelane
```

ถ้าไม่พบ:

```text
เข้า Nix shell ของ LibreLane/IHP environment
```

Lab 3 ต่างจาก Lab 1/2 ตรงที่ technology-aware synthesis ต้องมี LibreLane environment จริง

---

# 40. Troubleshooting — IHP PDK ไม่พบ

ตรวจ:

```bash
ls ~/.ciel
```

และ environment:

```bash
echo "$PDK_ROOT"
echo "$PDK"
```

จาก official IHP template environment สามารถติดตั้ง PDK ด้วย:

```bash
make clone-pdk
```

จาก root ของ template

---

# 41. Troubleshooting — Slang Parse Error

ตรวจ:

```bash
cat build/50MHz/config.yaml
```

ต้องมี:

```yaml
USE_SLANG: true
```

ตรวจ source:

```bash
cat config/source_manifest.txt
```

package ต้อง first

---

# 42. Troubleshooting — `rf_wb_mux` Defined Twice

canonical source set ห้ามมี:

```text
rf_wb_mux.flat.v
```

ตรวจ:

```bash
grep rf_wb_mux config/source_manifest.txt
```

ต้องได้เพียง:

```text
src/rf_wb_mux.sv
```

---

# 43. Troubleshooting — Unmapped Module

ค้น:

```bash
grep -RniE \
  'unmapped|module .*not found|unknown module' \
  reports/
```

จากนั้นหา definition:

```bash
grep -R "^module " "$REPO_ROOT/src"
```

ห้ามแก้ด้วยการเพิ่มทุกไฟล์ใน `src/` แบบ wildcard เพราะอาจเพิ่ม duplicate/generated RTL

---

# 44. Troubleshooting — SDC Clock Not Found

ถ้า OpenROAD CheckSDCFiles บอกไม่พบ clock port:

ตรวจ top:

```text
osoc1_cpu_core
```

และ port:

```text
clk_i
```

generated SDC ต้องมี:

```tcl
[get_ports clk_i]
```

ไม่ใช่:

```text
clk_PAD
```

เพราะ `clk_PAD` เป็น full-chip top port ที่จะใช้ใน Lab หลัง ๆ

---

# 45. Troubleshooting — Timing Fail ที่ 200 MHz

ดูว่าใช้:

```text
IO_MODE=fixed
```

หรือ:

```text
IO_MODE=scaled
```

fixed mode ที่ 200 MHz มี period 5 ns แต่ output delay 4 ns

จึงเป็น aggressive interface constraint

ลอง architecture-oriented comparison:

```bash
make clean
make IO_MODE=scaled preflight
make IO_MODE=scaled sweep-explore
```

แต่ต้องเก็บผลเป็น experiment แยก

---

# 46. Troubleshooting — Metrics Parser ไม่เจอ JSON

`collect_ppa.py` ตั้งใจไม่ผูกกับ LibreLane run-directory layout

ถ้า:

```text
No metrics discovered
```

รัน:

```bash
make find-runs
```

แล้วดู:

```text
reports/run_directories.txt
```

ค้นด้วยตนเอง:

```bash
find . "$REPO_ROOT" \
  -iname '*metrics*.json' \
  -o -iname 'metrics.json'
```

จากนั้น cross-check metrics file โดยตรง

---

# 47. Lab Pass Criteria — Baseline

Lab 3 baseline ถือว่าผ่านเมื่อ:

```text
[ ] tool environment ถูกต้อง
[ ] source revision ถูก freeze
[ ] generated config ถูกสร้าง
[ ] generated SDC ถูกสร้าง
[ ] top = osoc1_cpu_core
[ ] clock = clk_i
[ ] USE_SLANG = true
[ ] Yosys.Synthesis completed
[ ] no unresolved RTL module
[ ] no unintended unmapped instances
[ ] mapped netlist/metrics ถูกสร้าง
[ ] reports ถูกเก็บ
[ ] LAB03_REPORT.md ถูกสร้าง
```

สำหรับ 50 MHz timing-qualified baseline เพิ่ม:

```text
[ ] CheckSDCFiles PASS
[ ] pre-PnR STA completed
[ ] WNS/TNS ถูกบันทึก
```

ไม่บังคับให้ WNS >= 0 เพื่อถือว่า Lab workflow ผ่าน เพราะค่าจริงเป็นผลการทดลอง แต่ต้องตีความ timing status ให้ถูกต้อง

---

# 48. Deliverables

```text
reports/00_environment.log
reports/01_source_freeze.txt
reports/02_generated_configs.txt
reports/03_synthesis_log_check.txt
reports/LAB03_REPORT.md

results/ppa_summary.csv
results/ppa_summary.md

build/50MHz/config.yaml
build/50MHz/osoc1_cpu_core.sdc
```

ถ้าทำ sweep:

```text
build/100MHz/*
build/200MHz/*
```

รวมถึง LibreLane run artifacts จริง

---

# 49. ตารางที่ควรใส่ในรายงาน

| Target | Period | Cells | Unmapped | Cell Area | WNS | TNS |
|---|---:|---:|---:|---:|---:|---:|
| 50 MHz | 20 ns | measured | 0 | measured | measured | measured |
| 100 MHz | 10 ns | measured | 0 | measured | measured | measured |
| 200 MHz | 5 ns | measured | 0 | measured | measured | measured |

ห้ามกรอกค่าจากการคาดเดา

ต้องใช้ output จาก flow เท่านั้น

---

# 50. Design Review Questions

1. Technology mapping ต่างจาก RTL elaboration อย่างไร?
2. ทำไม synthesis area ไม่เท่ากับ die area?
3. ทำไม instance count ไม่เท่ากับ transistor count?
4. ทำไม pre-PnR WNS ไม่ใช่ signoff WNS?
5. `USE_SLANG` สำคัญต่อ RTL นี้อย่างไร?
6. ทำไม core-only synthesis ต้องมาก่อน full-chip synthesis?
7. ถ้า unmapped count > 0 แต่ timing ผ่าน เราควรเดิน flow ต่อหรือไม่?
8. ถ้า synthesis ผ่านแต่ WNS < 0 หมายถึงอะไร?
9. fixed I/O budget กับ scaled I/O budget ตอบคำถามต่างกันอย่างไร?
10. ถ้า 200 MHz fail timing เราควร inspect path ใดก่อน?

---

# 51. สิ่งที่ Freeze หลัง Lab 3

หลัง baseline run ให้ freeze:

```text
RTL commit
LibreLane version
IHP SG13G2 PDK version
source manifest
SDC mode
clock target
mapped cell count
mapped cell area
unmapped count
pre-PnR WNS/TNS
```

นี่เป็น **Core Synthesis Baseline**

ใช้เทียบกับทุก optimization ต่อจากนี้

---

# 52. Transition ไป Full-Chip Integration

เมื่อ core synthesis clean:

```text
osoc1_cpu_core
       |
       v
mapped successfully
       |
       v
timing baseline known
```

จึงพร้อมเพิ่ม:

```text
chip_core
       |
       v
chip_top
       |
       v
IHP IO pads
       |
       v
Pad Ring + PDN
```

แนวทางนี้ลด debugging space จาก:

```text
RTL + synthesis + pads + PDN + floorplan + routing
```

ให้เหลือทีละ subsystem

---

# 53. Engineering Rule ของ Lab 3

กฎสำคัญที่สุดคือ:

> อย่าดูเพียงคำว่า “flow completed”

ต้องตรวจอย่างน้อย:

```text
correct top
correct source revision
correct PDK
correct clock
correct timing mode
unmapped = 0
area source
timing analysis stage
```

จึงจะกล่าวได้ว่าผล synthesis มีความหมายทางวิศวกรรม

---

# 54. Recommended Next Lab

หลัง Lab 3 ควรเข้าสู่:

```text
Lab 4 — Build Full-Chip Wrapper
```

โดยใช้ synthesis baseline นี้เป็น reference แล้วสร้าง:

```text
osoc1_cpu_core
   +
internal NOP/ROM source
   +
data-memory response
   +
observable PC outputs
   =
chip_core
```

จากนั้นจึงเริ่ม IHP SG13G2 pad-ring integration
