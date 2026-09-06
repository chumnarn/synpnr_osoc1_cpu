# Lab 2 — RTL Lint and Synthesis Readiness
## Deep Step-by-Step Ready-to-Run Guide สำหรับ `synpnr_osoc1_cpu`

**Target RTL:** `osoc1_cpu_core`  
**Target technology:** IHP SG13G2  
**Flow:** LibreLane  
**Primary RTL frontend:** Slang through LibreLane  
**Baseline clock:** 20 ns = 50 MHz

---

## 1. เป้าหมายของ Lab

Lab 1 ตอบคำถามว่า “CPU นี้ประกอบด้วยอะไรและทำงานขั้นพื้นฐานได้หรือไม่”

Lab 2 ต้องตอบคำถามที่ต่างออกไป:

> RTL ชุดนี้พร้อมถูกส่งให้ synthesis tool หรือยัง?

คำว่า synthesis-ready ไม่ได้หมายถึงเพียง Verilator ไม่รายงาน syntax error แต่ต้องครอบคลุมอย่างน้อย:

```text
source-set determinism
package ordering
module uniqueness
top-module resolution
port sanity
lint cleanliness
synthesis frontend compatibility
timing-constraint availability
technology-flow compatibility
no unresolved/unmapped design hierarchy
```

Lab นี้จึงเป็น gate ระหว่าง:

```text
Functional RTL
      |
      v
RTL/Synthesis Readiness
      |
      v
Technology Mapping
      |
      v
Physical Design
```

---

# 2. ทำไมต้องแยก Lint ออกจาก Synthesis

Lint กับ synthesis ตรวจคนละมุม

```text
                    RTL
                     |
          +----------+----------+
          |                     |
          v                     v
        Lint                Synthesis
          |                     |
syntax/width/style       elaboration/mapping
missing ports           technology cells
multiple drivers        unsupported constructs
latch risks             unresolved hierarchy
```

RTL ที่ lint ผ่านยังอาจ synthesis fail ได้

ตัวอย่าง:

```text
unsupported SystemVerilog construct
package/frontend incompatibility
unresolved black box
invalid parameterization
technology mapping failure
```

ดังนั้น Lab นี้มีทั้ง lint gate และ synthesis smoke gate

---

# 3. Source Set ที่ใช้

Canonical source list อยู่ที่:

```text
config/source_manifest.txt
```

เนื้อหา:

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

ไฟล์ต่อไปนี้จงใจไม่อยู่ใน source set:

```text
src/rf_wb_mux.flat.v
src/chip_core.sv
src/chip_top.sv
```

เหตุผล:

- `.flat.v` ไม่ควรถูก compile ซ้ำกับ RTL source ที่มี module เดียวกัน
- `chip_core`/`chip_top` เป็น integration layer สำหรับ Lab full-chip
- Lab 2 ต้อง isolate CPU synthesis problems ออกจาก pad-ring/full-chip problems

---

# 4. ติดตั้ง Lab

แนะนำ:

```text
~/workshop/synpnr_osoc1_cpu/
└── labs/
    └── lab02_rtl_lint_synthesis_readiness/
```

เข้า Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab02_rtl_lint_synthesis_readiness
```

ถ้าวาง Lab แยก directory สามารถระบุ:

```bash
make REPO_ROOT=$HOME/workshop/synpnr_osoc1_cpu readiness
```

---

# 5. Step 1 — ตรวจ Tool Environment

รัน:

```bash
make check-env
```

Required สำหรับ local readiness:

```text
python3
verilator
yosys
```

Optional ในขั้น local แต่จำเป็นสำหรับ synthesis smoke:

```text
librelane
openroad
```

ผลถูกเก็บที่:

```text
reports/00_environment.log
```

### Pass criterion

อย่างน้อย:

```text
PASS required python3
PASS required verilator
PASS required yosys
```

สำหรับ `make synth-smoke` ต้องมี:

```text
librelane
```

และ IHP SG13G2 PDK ที่ LibreLane มองเห็น

---

# 6. Step 2 — Freeze Source Set

รัน:

```bash
make check-src
```

script:

```text
scripts/check_sources.py
```

ทำสามอย่าง:

1. อ่าน canonical manifest
2. ตรวจว่าไฟล์มีจริง
3. บันทึก SHA-256 prefix ของแต่ละ source

ตัวอย่าง report:

```text
FILE                                  BYTES        SHA256[:16]
------------------------------------------------------------------------------
src/cpu_sv_package.sv                 ....        ................
...
src/osoc1_cpu_core.sv                 ....        ................

PASS: canonical CPU RTL source set exists.
```

การบันทึก hash ทำให้รู้ว่า source เปลี่ยนหรือไม่ระหว่าง workshop/run

---

# 7. Step 3 — ตรวจ Source Ordering

รัน:

```bash
make source-order
```

pass conditions:

```text
cpu_sv_package.sv = first
osoc1_cpu_core.sv = last
rf_wb_mux.flat.v = absent
```

ทำไม package ต้อง first?

เพราะ module หลายตัวอาจใช้:

```systemverilog
import cpu_sv_package::*;
```

frontend จึงต้องเห็น package declaration ก่อน

---

# 8. Step 4 — ตรวจ Package/Import Relationship

รัน:

```bash
make package-check
```

script จะ scan:

```systemverilog
package <name>
```

และ:

```systemverilog
import <name>::*
```

แล้วตรวจว่าทุก imported package ถูกประกาศใน canonical source set

Pass:

```text
PASS: all package imports resolve within canonical source set.
```

ถ้า fail อย่าเริ่ม synthesis

---

# 9. Step 5 — ตรวจ Duplicate Module ใน Active Source Set

รัน:

```bash
make duplicate-check
```

ต่างจากการ scan repository ทั้งหมด

เราสนใจคำถามว่า:

> source files ที่เราจะส่งให้ synthesis มี module ชื่อซ้ำหรือไม่?

expected:

```text
PASS: no duplicate module definitions in active source set.
```

ถึง repository จะมี `rf_wb_mux.flat.v` ก็ไม่เป็นปัญหา ตราบใดที่มันไม่ถูกใส่ใน active manifest

---

# 10. Step 6 — Baseline Verilator Lint

รัน:

```bash
make lint
```

command ใช้:

```bash
verilator \
  --lint-only \
  --Wall \
  --Wno-DECLFILENAME \
  --Wno-UNUSEDSIGNAL \
  --top-module osoc1_cpu_core \
  <ordered RTL files>
```

### เหตุผลที่ suppress `DECLFILENAME`

Lab นี้สนใจ synthesis correctness มากกว่า filename-style policy

### เหตุผลที่ suppress `UNUSEDSIGNAL`

CPU datapath/control อาจมี decoded fields หรือ internal signals ที่ไม่ถูกใช้ทุก mode และ warning นี้มักไม่ใช่ synthesis blocker

แต่ไม่ควร suppress warning แบบสุ่มเพิ่ม

---

# 11. Step 7 — Strict Lint Gate

รัน:

```bash
make lint-strict
```

Lab ยกระดับ warning ต่อไปนี้เป็น error:

```text
PINMISSING
PINCONNECTEMPTY
WIDTH
LATCH
MULTIDRIVEN
```

เหตุผล:

### `PINMISSING`

อาจหมายถึง instantiation ไม่ตรง interface

### `PINCONNECTEMPTY`

อาจหมายถึง port ถูกทิ้งโดยไม่ได้ตั้งใจ

### `WIDTH`

อันตรายต่อ datapath 32-bit เพราะ truncate/extend ผิดอาจผ่าน simulation บาง case ได้

### `LATCH`

RTL synchronous CPU โดยทั่วไปไม่ควรสร้าง unintended latch

### `MULTIDRIVEN`

net/register ที่มีหลาย driver เป็น synthesis hazard สำคัญ

ผล:

```text
reports/06_verilator_lint_strict.log
```

---

# 12. Step 8 — Native Yosys Probe

รัน:

```bash
make yosys-native-probe
```

target นี้เป็น **diagnostic only**

ไม่ใช่ pass/fail gate

เหตุผลคือ RTL นี้ใช้ SystemVerilog package และ Yosys native `read_verilog -sv` ไม่ได้มี SystemVerilog coverage เทียบเท่า frontend อย่าง Slang

ดังนั้นอาจเห็น failure ที่ package syntax แม้ RTL ถูกต้อง

Lab จึงใช้ probe นี้เพื่อสอนความแตกต่างระหว่าง:

```text
RTL correctness
```

กับ:

```text
frontend language support
```

หาก native Yosys fail แต่ Verilator pass สิ่งที่ต้องทำไม่ใช่ rewrite RTL ทันที แต่ให้ใช้ frontend ที่รองรับ SystemVerilog ดีกว่า

---

# 13. ทำไม LibreLane Lab นี้ใช้ Slang

Official IHP SG13G2 LibreLane template แนะนำให้เปิด:

```yaml
USE_SLANG: true
```

เมื่อ design ต้องการ SystemVerilog support ที่ครอบคลุมมากขึ้น

ดังนั้น generated config ของ Lab มี:

```yaml
USE_SLANG: true

SLANG_ARGUMENTS:
  - --keep-hierarchy
```

นี่คือ intended synthesis path ของ Lab 2

---

# 14. Step 9 — สร้าง Portable LibreLane Config

อย่า hard-code:

```text
../../src
```

ใน YAML หาก Lab อาจถูกย้าย

รัน:

```bash
make gen-config
```

script:

```text
scripts/gen_librelane_config.py
```

จะอ่าน:

```text
REPO_ROOT
config/source_manifest.txt
constraints/osoc1_cpu_core.sdc
```

และสร้าง:

```text
build/core_synth.yaml
```

ด้วย absolute paths

ดังนั้นทั้งสองแบบใช้ได้:

```bash
make gen-config
```

หรือ:

```bash
make REPO_ROOT=/work/other/synpnr_osoc1_cpu gen-config
```

---

# 15. Generated Core-Only Config

config ที่สร้างมีโครงสร้าง:

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

PNR_SDC_FILE: "/absolute/path/constraints/osoc1_cpu_core.sdc"
SIGNOFF_SDC_FILE: "/absolute/path/constraints/osoc1_cpu_core.sdc"
FALLBACK_SDC: "/absolute/path/constraints/osoc1_cpu_core.sdc"

CLOCK_PORT: clk_i
CLOCK_PERIOD: 20.0
```

Lab ใช้ `meta.version: 3`

เพื่อสอดคล้องกับ configuration style ของ IHP LibreLane template ปัจจุบัน

---

# 16. Step 10 — Timing Constraint Baseline

ไฟล์:

```text
constraints/osoc1_cpu_core.sdc
```

สร้าง clock:

```tcl
create_clock \
  -name core_clk \
  -period 20.000 \
  [get_ports clk_i]
```

ดังนั้น baseline:

```text
T = 20 ns
f = 50 MHz
```

นี่ไม่ใช่คำกล่าวว่า CPU maximum frequency = 50 MHz

แต่เป็น initial target สำหรับ synthesis readiness

---

# 17. Clock Uncertainty

กำหนด:

```tcl
set_clock_uncertainty 0.250 [get_clocks core_clk]
```

ทำให้ synthesis/pre-PnR timing ไม่ optimistic เกินไป

---

# 18. Instruction Input Delay

```tcl
set_input_delay 2.000 \
  -clock core_clk \
  [get_ports instr_i]
```

ตีความว่า instruction memory ภายนอก CPU core มีเวลาใช้ไปประมาณ 2 ns ก่อน data มาถึง CPU interface

---

# 19. Data Memory Read Delay

```tcl
set_input_delay 2.000 \
  -clock core_clk \
  [get_ports dmem_rdata_i]
```

เป็น external-interface assumption สำหรับ core-only exploration

เมื่อ integrate SRAM จริง constraint นี้ต้องถูกทบทวนใหม่

---

# 20. Output Delays

ตัวอย่าง:

```tcl
set_output_delay 4.000 \
  -clock core_clk \
  [get_ports pc_o]
```

ใช้กับ:

```text
pc_o
dmem_we_o
dmem_addr_o
dmem_wdata_o
```

เพื่อป้องกัน synthesis จากการมอง output paths ว่า unconstrained

---

# 21. Reset Constraint

`rst_ni` เป็น asynchronous active-low reset

จึงกำหนด:

```tcl
set_false_path -from [get_ports rst_ni]
```

เราไม่ต้องการให้ normal setup analysis พยายาม optimize reset assertion เหมือน synchronous data path

หมายเหตุ: final implementation ยังต้องพิจารณา reset recovery/removal และ reset-tree behavior แยกต่างหาก

---

# 22. Step 11 — ตรวจ Generated Config + SDC

รัน:

```bash
make config-check
```

ตรวจ:

```text
meta version 3
SynthesisExploration flow
DESIGN_NAME
USE_SLANG
CLOCK_PORT
CLOCK_PERIOD
create_clock
reset false path
```

expected:

```text
PASS  config exists
PASS  SDC exists
PASS  meta version 3
PASS  SynthesisExploration flow
PASS  correct DESIGN_NAME
PASS  USE_SLANG enabled
PASS  clock port clk_i
PASS  20 ns clock
PASS  SDC create_clock
PASS  async reset false path
```

---

# 23. Step 12 — Local Readiness Run

รัน:

```bash
make clean
make readiness
```

ลำดับ:

```text
check-env
check-src
source-order
package-check
duplicate-check
lint
lint-strict
yosys-native-probe
config-check
analyze-readiness
```

จุดสำคัญ:

```text
yosys-native-probe
```

ไม่ทำให้ overall readiness fail เพราะเป็น frontend diagnostic

---

# 24. เข้า LibreLane/IHP SG13G2 Environment

สำหรับ technology-aware synthesis ต้องมี LibreLane + PDK

แนะนำใช้ Nix environment ของ IHP template

ตัวอย่าง:

```bash
cd ~/workshop/ihp-sg13g2-librelane-template
nix-shell
```

ตรวจ:

```bash
which librelane
librelane --version
```

และ PDK:

```bash
ls ~/.ciel
```

ถ้ายังไม่มี IHP PDK ให้ทำตาม official template:

```bash
make clone-pdk
```

จากนั้นกลับ Lab:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab02_rtl_lint_synthesis_readiness
```

---

# 25. Step 13 — LibreLane Synthesis Smoke

รัน:

```bash
make synth-smoke
```

คำสั่งหลักคือ:

```bash
librelane \
  --pdk ihp-sg13g2 \
  --flow SynthesisExploration \
  --run-tag lab02_synth_smoke \
  --to Yosys.Synthesis \
  build/core_synth.yaml
```

เป้าหมายคือหยุดทันทีหลัง:

```text
Yosys.Synthesis
```

ไม่ทำ Floorplan

ไม่ทำ Placement

ไม่ทำ CTS

ไม่ทำ Routing

นี่คือวิธี isolate synthesis stage

---

# 26. สิ่งที่ LibreLane Synthesis ทำ

conceptually:

```text
SystemVerilog RTL
      |
      v
Slang frontend
      |
      v
Yosys internal representation
      |
      v
RTL optimization
      |
      v
generic logic
      |
      v
ABC / technology mapping
      |
      v
IHP SG13G2 standard cells
      |
      v
gate-level netlist
```

---

# 27. Success Criteria ของ Synthesis Smoke

ต้องไม่มี:

```text
unresolved module
unmapped cell
synthesis check error
frontend parse error
technology mapping failure
```

LibreLane มี checker สำหรับ unmapped Yosys instances และ synthesis checks ใน flow ปกติ

ถ้าหยุดตรง `--to Yosys.Synthesis` ให้ inspect synthesis metrics/netlist แล้ว Lab ถัดไปสามารถ run checker ต่อได้

---

# 28. Step 14 — Synthesis Exploration + Pre-PnR STA

หลัง smoke ผ่าน:

```bash
make synth-explore
```

LibreLane `SynthesisExploration` flow ปัจจุบันประกอบด้วย:

```text
Yosys.Synthesis
OpenROAD.CheckSDCFiles
OpenROAD.STAPrePNR
```

จึงเหมาะมากสำหรับ Lab นี้

มันตอบคำถามต่อจาก “synthesize ได้ไหม” ว่า:

```text
SDC โหลดได้ไหม
clock ถูก recognize ไหม
pre-PnR timing มีรูปแบบสมเหตุผลไหม
```

---

# 29. อย่าสับสน Pre-PnR STA กับ Signoff STA

ผล timing ใน Lab 2 เป็น:

```text
pre-PnR
```

ยังไม่มี:

```text
real placement
real routed RC
CTS
actual clock tree
post-route parasitics
```

ดังนั้นห้ามใช้ Lab 2 WNS เป็น final timing conclusion

มันใช้เพื่อ:

```text
constraint sanity
architecture baseline
synthesis comparison
```

---

# 30. Step 15 — Readiness Summary

รัน:

```bash
make analyze-readiness
```

ผล:

```text
reports/12_readiness_summary.txt
```

ตัวอย่าง:

```text
PASS  Canonical source set
PASS  Source order
PASS  Package resolution
PASS  No duplicate active modules
PASS  Verilator lint
PASS  Verilator strict lint
PASS  LibreLane config/SDC
PASS  LibreLane synthesis smoke

Overall local readiness: PASS
```

---

# 31. Step 16 — Generate Lab Report

รัน:

```bash
make report
```

ได้:

```text
reports/LAB02_REPORT.md
```

บันทึก:

```text
environment
source hashes
source ordering
package resolution
duplicates
lint logs
native Yosys diagnostic
generated config
SDC/config validation
LibreLane synthesis log
readiness summary
Git revision
```

---

# 32. Full Ready-to-Run Sequence

จาก Lab directory:

```bash
make clean
make readiness
```

จากนั้นภายใน LibreLane/IHP environment:

```bash
make synth-smoke
make analyze-readiness
make report
```

ถ้าต้องการ pre-PnR timing exploration:

```bash
make synth-explore
make report
```

---

# 33. Troubleshooting — Native Yosys Package Error

อาการ:

```text
syntax error
unexpected TOK_PACKAGE
unsupported SystemVerilog
```

จาก:

```bash
make yosys-native-probe
```

อย่าเพิ่งแก้ RTL

เพราะ target นี้ diagnostic

ตรวจ:

```bash
make lint-strict
```

ถ้าผ่าน ให้ใช้ intended frontend:

```yaml
USE_SLANG: true
```

ผ่าน LibreLane

---

# 34. Troubleshooting — Slang/LibreLane Parse Fail

ถ้า LibreLane ยัง parse fail:

ตรวจ source order:

```bash
make source-order
```

ตรวจ package:

```bash
make package-check
```

เปิด config:

```bash
cat build/core_synth.yaml
```

ยืนยัน:

```yaml
USE_SLANG: true
```

และตรวจ LibreLane version:

```bash
librelane --version
```

---

# 35. Troubleshooting — Module Not Found

เช่น:

```text
module alu not found
```

ตรวจ manifest:

```bash
cat config/source_manifest.txt
```

และ:

```bash
make check-src
```

ห้ามแก้โดยใช้ wildcard:

```text
src/*
```

แบบสุ่ม เพราะอาจดึง `.flat.v`, `chip_top.sv` และ generated source เข้ามา

---

# 36. Troubleshooting — Duplicate `rf_wb_mux`

ถ้าเจอ module redefinition:

```bash
grep -n "^module" \
  "$REPO_ROOT/src/rf_wb_mux.sv" \
  "$REPO_ROOT/src/rf_wb_mux.flat.v"
```

canonical source set ของ Lab 2 ต้องมีเพียง:

```text
rf_wb_mux.sv
```

---

# 37. Troubleshooting — WIDTH Error

หาก strict lint fail:

```text
%Error-WIDTH
```

อย่า suppress ก่อนตรวจ

ต้องพิจารณา:

```text
signed vs unsigned
32-bit vs narrower immediate
shift amount width
byte/halfword selection
concatenation width
comparison operands
```

WIDTH warning สามารถเป็น functional bug จริง

---

# 38. Troubleshooting — LATCH

ถ้า:

```text
%Error-LATCH
```

ตรวจ combinational block ว่ามี default assignment ครบหรือไม่

ตัวอย่าง pattern ที่ดี:

```systemverilog
always_comb begin
    next = default_value;

    case (...)
       ...
    endcase
end
```

CPU control logic ไม่ควรสร้าง latch โดยไม่ตั้งใจ

---

# 39. Troubleshooting — MULTIDRIVEN

ถ้า signal ถูก assign จากมากกว่าหนึ่ง process:

```text
always_comb
always_ff
continuous assign
```

ต้องแก้ ownership ของ signal

ห้าม suppress warning นี้เพื่อให้ synthesis ผ่าน

---

# 40. Troubleshooting — Unmapped Cells

ถ้า LibreLane/Yosys รายงาน unmapped instance:

แยกสองประเภท

### Type A — Missing RTL module

เช่น:

```text
unknown module xyz
```

แก้ source manifest/hierarchy

### Type B — Logic ยัง map ไม่ได้เป็น technology cell

ตรวจ synthesis log, unsupported construct และ library setup

Full-chip flow ไม่ควรเดินต่อถ้า unmapped instance count ไม่เป็นศูนย์

---

# 41. Synthesis Readiness Gate

Lab 2 ผ่านเมื่อ:

```text
[ ] Environment required tools available
[ ] Canonical source set exists
[ ] Source hashes recorded
[ ] Package first
[ ] CPU top last
[ ] Package imports resolve
[ ] No duplicate module in active source set
[ ] rf_wb_mux.flat.v excluded
[ ] Verilator baseline lint passes
[ ] Strict lint passes
[ ] Generated config is valid
[ ] USE_SLANG=true
[ ] SDC has clock
[ ] SDC handles reset
[ ] LibreLane can elaborate/synthesize RTL
[ ] No unresolved design hierarchy
[ ] No unintended unmapped logic
[ ] Lab report generated
```

---

# 42. Deliverables

ส่ง:

```text
reports/00_environment.log
reports/01_source_check.txt
reports/02_source_order.txt
reports/03_package_check.txt
reports/04_duplicate_check.txt
reports/05_verilator_lint.log
reports/06_verilator_lint_strict.log
reports/07_yosys_native_probe.log
reports/08_generated_core_synth.yaml
reports/09_config_check.txt
reports/10_librelane_synth_smoke.log
reports/12_readiness_summary.txt
reports/LAB02_REPORT.md
```

ถ้ารัน SynthesisExploration เพิ่ม:

```text
reports/11_librelane_synth_explore.log
```

---

# 43. Design Review Questions

1. ทำไม lint pass ไม่ได้แปลว่า synthesis pass?
2. ทำไม Lab นี้ใช้ explicit source manifest แทน `src/*.sv`?
3. `cpu_sv_package.sv` มีผลต่อ compile order อย่างไร?
4. ทำไม native Yosys probe ไม่ถูกใช้เป็น gating criterion?
5. `USE_SLANG` แก้ปัญหาประเภทใด?
6. ทำไม `rf_wb_mux.flat.v` ไม่ควรถูก compile พร้อม RTL source?
7. ทำไม reset path ถูก false-path ใน baseline SDC?
8. pre-PnR STA ต่างจาก post-route STA อย่างไร?
9. unmapped cell กับ missing RTL module ต่างกันอย่างไร?
10. เพราะเหตุใดเราควร synthesize `osoc1_cpu_core` แยกก่อน `chip_top`?

---

# 44. สิ่งที่ Freeze หลัง Lab 2

เมื่อ Lab ผ่าน ให้ freeze:

```text
TOP:
osoc1_cpu_core

LANGUAGE:
SystemVerilog

FRONTEND:
Slang through LibreLane

PDK:
ihp-sg13g2

CLOCK:
clk_i

BASELINE PERIOD:
20 ns

ACTIVE RESET:
rst_ni, active low, asynchronous

CANONICAL WRITEBACK SOURCE:
rf_wb_mux.sv
```

นี่เป็น baseline สำหรับ Core-Only Synthesis/PPA และ Full-Chip wrapper integration ต่อไป

---

# 45. Transition ไป Lab ถัดไป

Lab ถัดไปควรเปลี่ยนจาก:

```text
Can this RTL be synthesized?
```

ไปสู่:

```text
What did synthesis produce?
```

โดยวิเคราะห์:

```text
technology-mapped cell count
sequential/combinational split
area
critical path
WNS/TNS
cell histogram
logic depth
unmapped-cell count
synthesis strategy
50/100/200 MHz comparison
```

จากนั้นจึงนำ CPU เข้า:

```text
chip_core
   |
chip_top
   |
IHP SG13G2 pad ring
```

หลักการคือ:

> อย่าเพิ่ม Full-Chip complexity จนกว่า CPU core synthesis baseline จะ reproducible และ clean
