# Lab 4 — Build Full-Chip Wrapper
## Deep Step-by-Step Ready-to-Run Guide
### `synpnr_osoc1_cpu` + IHP SG13G2 Full-Chip Architecture

**CPU:** `osoc1_cpu_core`  
**Core wrapper:** `chip_core`  
**Chip wrapper:** `chip_top`  
**Technology target:** IHP SG13G2  
**Output observability:** `PC[9:2]` → 8 output pads  
**Bring-up program source:** constant RV32I NOP

---

# 1. เป้าหมายของ Lab

Lab 1–3 ทำให้เราได้ CPU core ที่:

```text
เข้าใจ hierarchy
lint ผ่าน
functional smoke test ผ่าน
synthesis-ready
technology mapping ได้
```

แต่ CPU core ยังไม่ใช่ chip

`osoc1_cpu_core` มี memory interfaces:

```text
pc_o[31:0]
instr_i[31:0]

dmem_we_o[3:0]
dmem_addr_o[31:0]
dmem_wdata_o[31:0]
dmem_rdata_i[31:0]
```

ถ้านำทุก bit ออก package โดยตรงจะต้องใช้ signal pads จำนวนมาก

Lab 4 จึงสร้าง wrapper architecture ที่ลดระบบให้เหลือ test chip ขั้นต่ำ:

```text
constant NOP source
CPU core
zero-valued data-memory response
8-bit PC observability
IHP input/output pads
```

---

# 2. ปัญหาของ Wrapper เดิมใน Repository

wrapper เดิมใน fork ยังเป็น placeholder architecture

`chip_core.sv` เดิมอ้าง:

```text
osoc1_cpu
gpio_in
gpio_out
```

แต่ CPU จริงคือ:

```text
osoc1_cpu_core
```

และใช้ instruction/data-memory ports

ดังนั้น placeholder เดิมไม่ควรถูกใช้เป็น synthesis source ของ full-chip flow

Lab นี้สร้าง wrapper ใหม่ที่ตรงกับ CPU interface จริง

---

# 3. Architecture ของ Lab 4

```text
                         CHIP PACKAGE
 +-----------------------------------------------------------+
 |                                                           |
 | clk_PAD                                                   |
 |    |                                                      |
 |    v                                                      |
 | sg13g2_IOPadIn                                            |
 |    | p2c                                                  |
 |    v                                                      |
 | +-------------------------------------------------------+ |
 | |                    chip_core                          | |
 | |                                                       | |
 | |   +----------------------+                            | |
 | |   |   RV32 NOP source    |------ instr_i             | |
 | |   +----------------------+        |                   | |
 | |                                   v                   | |
 | |                         +--------------------+         | |
 | |                         | osoc1_cpu_core     |         | |
 | |                         |                    |         | |
 | |                         | pc_o[31:0]         |         | |
 | |                         +---------+----------+         | |
 | |                                   |                    | |
 | |                             pc[9:2]                    | |
 | +-----------------------------------+--------------------+ |
 |                                     |                      |
 |             +-----------------------+------------------+   |
 |             |        8 output I/O cells               |   |
 |             +-----------------------+------------------+   |
 |                                     |                      |
 |                              output_PAD[7:0]                |
 +-------------------------------------------------------------+
```

reset path:

```text
rst_n_PAD
    |
sg13g2_IOPadIn
    |
rst_n_core
    |
chip_core
    |
osoc1_cpu_core.rst_ni
```

---

# 4. ทำไมใช้ NOP Generator ใน Baseline

Instruction:

```text
32'h0000_0013
```

คือ:

```assembly
addi x0, x0, 0
```

หรือ RISC-V NOP

ดังนั้น CPU ไม่ต้องมี instruction SRAM ใน Lab นี้

conceptually:

```text
pc = any address
       |
       v
instr = NOP
       |
       v
CPU executes NOP
       |
       v
PC = PC + 4
```

จึงเหมาะกับ first full-chip bring-up

---

# 5. ทำไมใช้ `PC[9:2]`

PC sequence:

```text
0x00000000
0x00000004
0x00000008
0x0000000c
0x00000010
...
```

เนื่องจาก increment = 4:

```text
PC[1:0] = 00
```

แทบตลอด normal aligned instruction execution

ดังนั้น:

```text
output = PC[9:2]
```

จะให้:

```text
cycle 0  -> 00
cycle 1  -> 01
cycle 2  -> 02
cycle 3  -> 03
...
```

เทียบเท่า observable 8-bit counter ที่สร้างจาก CPU execution จริง

---

# 6. ทำไมไม่ใช้ `pc[7:0]`

ถ้าใช้:

```text
PC[7:0]
```

output จะเป็น:

```text
00
04
08
0c
10
...
```

แต่ถ้าใช้:

```text
PC[9:2]
```

จะเป็น:

```text
00
01
02
03
04
...
```

สะดวกต่อ logic analyzer และ lab observation มากกว่า

---

# 7. Data Memory Baseline

wrapper กำหนด:

```systemverilog
assign dmem_rdata = 32'h0000_0000;
```

เพราะ NOP ไม่อ่านหรือเขียน data memory

แต่ wrapper ยัง connect outputs:

```text
dmem_we
dmem_addr
dmem_wdata
```

จาก CPU ไว้ภายใน

เพื่อไม่แก้ interface ของ CPU

Lab testbench ยังตรวจด้วยว่า:

```text
dmem_we == 0000
```

ระหว่าง NOP sequence

---

# 8. Package Structure

```text
lab04_build_fullchip_wrapper/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB04_TH.md
│
├── config/
│   └── cpu_source_manifest.txt
│
├── constraints/
│   └── chip_top.sdc
│
├── rtl/
│   ├── chip_core.sv
│   └── chip_top.sv
│
├── sim/
│   └── ihp_io_stubs.v
│
├── tb/
│   ├── tb_chip_core.sv
│   └── tb_chip_top.sv
│
├── scripts/
│   ├── check_env.sh
│   ├── check_repo.py
│   ├── check_wrapper.py
│   ├── gen_filelist.py
│   └── build_report.py
│
├── build/
└── reports/
```

---

# 9. Step 1 — ติดตั้ง Lab

แนะนำ:

```text
~/workshop/synpnr_osoc1_cpu/
└── labs/
    └── lab04_build_fullchip_wrapper/
```

จากนั้น:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab04_build_fullchip_wrapper
```

---

# 10. Step 2 — ตรวจ Environment

รัน:

```bash
make check-env
```

ขั้นต่ำต้องมี:

```text
python3
verilator
```

สำหรับ Lab ต่อไปควรมี:

```text
yosys
librelane
```

expected:

```text
PASS required python3
PASS required verilator
PASS optional yosys
PASS optional librelane
```

---

# 11. Step 3 — ตรวจ CPU Source จริง

รัน:

```bash
make check-repo
```

ตรวจ:

```text
canonical CPU source files
source SHA hashes
osoc1_cpu_core interface
```

script ตรวจ ports:

```text
clk_i
rst_ni
pc_o
instr_i
dmem_we_o
dmem_addr_o
dmem_wdata_o
dmem_rdata_i
```

ถ้า CPU interface upstream เปลี่ยน Lab จะหยุดก่อน simulation

---

# 12. Step 4 — สร้าง `chip_core`

ไฟล์:

```text
rtl/chip_core.sv
```

แกนหลักคือ:

```systemverilog
module chip_core (
    input  wire       clk,
    input  wire       rst_n,
    output wire [7:0] output_out
);
```

wrapper ใช้ชื่อ ports แบบ generic chip-core side:

```text
clk
rst_n
output_out
```

ส่วน mapping ไป CPU ทำใน module นี้

---

# 13. Instantiate CPU

```systemverilog
osoc1_cpu_core u_cpu (
    .clk_i        (clk),
    .rst_ni       (rst_n),

    .pc_o         (pc),
    .instr_i      (instr),

    .dmem_we_o    (dmem_we),
    .dmem_addr_o  (dmem_addr),
    .dmem_wdata_o (dmem_wdata),
    .dmem_rdata_i (dmem_rdata)
);
```

นี่แก้ปัญหา placeholder เดิมที่อ้าง module/ports ผิด

---

# 14. NOP Source

```systemverilog
localparam logic [31:0] RV32_NOP = 32'h0000_0013;
assign instr = RV32_NOP;
```

ข้อดี:

```text
ไม่มี ROM macro
ไม่มี initialization file
ไม่มี bus
ไม่มี firmware build dependency
```

ทำให้ Full-Chip baseline มีตัวแปรน้อยที่สุด

---

# 15. Observable Output

```systemverilog
assign output_out = pc[9:2];
```

นี่ไม่ใช่ arbitrary counter

ค่าเกิดจาก:

```text
CPU PC register
+
next-PC path
+
NOP decode/control
```

ดังนั้น output แสดง CPU activity จริง

---

# 16. Step 5 — ตรวจ Wrapper Structure

รัน:

```bash
make check-wrapper
```

script ตรวจ:

```text
chip_core exists
osoc1_cpu_core instance exists
NOP constant exists
data memory tie-off exists
PC[9:2] observable output exists

chip_top exists
IHP input pad cells exist
IHP output pad cells exist
chip_core instance exists
USE_POWER_PINS support exists
```

expected:

```text
PASS  chip_core module
PASS  CPU instance
PASS  NOP constant
PASS  data read tie-off
PASS  PC observability
PASS  chip_top module
PASS  clock input pad cell
PASS  reset input pad cell
PASS  output pad cell
PASS  chip_core instance
PASS  power pin conditional
```

---

# 17. Step 6 — Lint `chip_core`

ก่อนเพิ่ม I/O cells ให้พิสูจน์ wrapper logic ก่อน

รัน:

```bash
make lint-core
```

compile chain:

```text
cpu_sv_package
CPU submodules
osoc1_cpu_core
chip_core
```

ไม่มี:

```text
chip_top
IHP IO cells
```

นี่ช่วย isolate core-wrapper error

---

# 18. Step 7 — Simulation `chip_core`

รัน:

```bash
make sim-core
```

testbench:

```text
tb/tb_chip_core.sv
```

ทำ:

```text
assert reset
verify output = 0
release reset
execute 32 NOP cycles
check output_out = cycle
check dmem_we = 0
```

expected:

```text
CORE cycle=1 output=01 pc=00000004 PASS
CORE cycle=2 output=02 pc=00000008 PASS
...
CORE cycle=32 output=20 pc=00000080 PASS

PASS: chip_core NOP wrapper increments observable PC[9:2].
```

---

# 19. ทำไมต้อง Test Core Wrapper ก่อน Pad-Level

ถ้า `chip_top` simulation fail โดยไม่ได้ test `chip_core` ก่อน เราจะไม่รู้ว่า failure มาจาก:

```text
CPU
wrapper
pad model
pad direction
clock-pad propagation
reset-pad propagation
```

ด้วย two-level verification:

```text
sim-core
   |
   PASS
   |
   v
sim-top
```

ถ้า sim-top fail เราสามารถ focus ที่ pad integration

---

# 20. Step 8 — `chip_top`

ไฟล์:

```text
rtl/chip_top.sv
```

top-level ports:

```systemverilog
inout wire clk_PAD;
inout wire rst_n_PAD;
inout wire [7:0] output_PAD;
```

พร้อม conditional power pins:

```systemverilog
`ifdef USE_POWER_PINS
inout wire IOVDD;
inout wire IOVSS;
inout wire VDD;
inout wire VSS;
`endif
```

---

# 21. ทำไม Pad Ports เป็น `inout`

physical pad cell มี package/pad terminal ที่เป็น physical I/O terminal

แม้ functional direction จะเป็น input/output

official full-chip style จึงใช้:

```text
inout wire
```

ที่ chip-level pad ports

direction จริงถูกกำหนดโดย I/O cell:

```text
sg13g2_IOPadIn
sg13g2_IOPadOut30mA
```

---

# 22. Clock Pad

```systemverilog
sg13g2_IOPadIn clk_pad (
    .p2c (clk_core),
    .pad (clk_PAD)
);
```

ความหมาย:

```text
pad -> core
```

หรือ:

```text
p2c
```

Clock path:

```text
clk_PAD
  |
  v
IOPadIn
  |
  v
clk_core
  |
  v
chip_core
```

---

# 23. Reset Pad

```systemverilog
sg13g2_IOPadIn rst_n_pad (
    .p2c (rst_n_core),
    .pad (rst_n_PAD)
);
```

ทำให้ package reset:

```text
rst_n_PAD
```

กลายเป็น internal:

```text
rst_n_core
```

แล้วส่งต่อเข้า CPU

---

# 24. Output Pad

แต่ละ bit:

```systemverilog
sg13g2_IOPadOut30mA output_pad (
    .c2p (output_core[i]),
    .pad (output_PAD[i])
);
```

ความหมาย:

```text
core -> pad
```

หรือ:

```text
c2p
```

ดังนั้น:

```text
PC[9:2]
   |
chip_core
   |
output_core[7:0]
   |
8 × IOPadOut30mA
   |
output_PAD[7:0]
```

---

# 25. Power Domains

Lab สร้าง parameter:

```text
NUM_VDD_PADS
NUM_VSS_PADS
NUM_IOVDD_PADS
NUM_IOVSS_PADS
```

default:

```text
2
2
2
2
```

แยก:

```text
core power domain:
VDD/VSS

I/O power domain:
IOVDD/IOVSS
```

ใน Lab 5 จะใช้ instance hierarchy เหล่านี้สำหรับ pad placement

---

# 26. `USE_POWER_PINS`

IHP/full-chip flow ต้องสามารถ expose physical supply nets ได้

จึงใช้:

```systemverilog
`ifdef USE_POWER_PINS
...
`endif
```

ข้อดีคือ:

### RTL simulation

ไม่ต้องจำลอง supply behavior

### Physical implementation

compile ด้วย:

```text
USE_POWER_PINS
```

แล้ว connect:

```text
VDD
VSS
IOVDD
IOVSS
```

จริง

---

# 27. Simulation-only IHP I/O Stubs

ไฟล์:

```text
sim/ihp_io_stubs.v
```

มี behavioral models ขั้นต่ำ เช่น:

```systemverilog
assign p2c = pad;
```

สำหรับ input pad

และ:

```systemverilog
assign pad = c2p;
```

สำหรับ output pad

จุดประสงค์คือให้ Verilator จำลอง:

```text
package pin -> pad cell -> core
```

โดยไม่ต้องโหลด PDK transistor-level/physical model

---

# 28. กฎสำคัญของ I/O Stub

ห้ามใส่:

```text
sim/ihp_io_stubs.v
```

ใน LibreLane synthesis source list

เพราะ synthesis ต้องใช้:

```text
PDK I/O library models
LEF
Liberty
GDS
```

จริง

ไม่ใช่ behavioral simulation stub

Lab จึงมีแยก:

```text
simulation source set
```

และ:

```text
real synthesis source set
```

ชัดเจน

---

# 29. Step 9 — Lint Full Chip

รัน:

```bash
make lint-top
```

source chain:

```text
CPU RTL
chip_core
simulation IHP stubs
chip_top
```

top:

```text
chip_top
```

เป้าหมายคือยืนยัน:

```text
pad cell port mapping
generate loops
chip_core interface
clock/reset path
output path
```

---

# 30. Step 10 — Pad-Level Simulation

รัน:

```bash
make sim-top
```

testbench:

```text
tb/tb_chip_top.sv
```

จำลอง:

```text
testbench clock driver
      |
      v
clk_PAD
      |
      v
sg13g2_IOPadIn stub
      |
      v
clk_core
      |
      v
CPU
      |
      v
PC[9:2]
      |
      v
sg13g2_IOPadOut30mA stub
      |
      v
output_PAD
```

นี่เป็น end-to-end digital wrapper verification

---

# 31. Expected Pad-Level Result

```text
PAD cycle=1 output_PAD=01 PASS
PAD cycle=2 output_PAD=02 PASS
PAD cycle=3 output_PAD=03 PASS
...
PAD cycle=32 output_PAD=20 PASS

PASS: chip_top pad-level smoke test passed.
```

ถ้า `sim-core` ผ่านแต่ `sim-top` fail ให้ตรวจ:

```text
pad direction
p2c/c2p mapping
pad signal name
clock propagation
reset propagation
output indexing
```

---

# 32. Step 11 — Real-Synthesis File List

รัน:

```bash
make filelist
```

สร้าง:

```text
build/synthesis_files.f
```

ประกอบด้วย:

```text
CPU source files
rtl/chip_core.sv
rtl/chip_top.sv
```

และต้องไม่มี:

```text
sim/ihp_io_stubs.v
```

ตรวจ:

```bash
grep ihp_io_stubs \
  build/synthesis_files.f
```

expected:

```text
no output
```

นี่เป็น important tapeout-flow discipline

---

# 33. Step 12 — Full Preflight

รัน:

```bash
make preflight
```

ทำ:

```text
environment
CPU source/interface check
wrapper structural check
real synthesis file-list generation
```

จากนั้น:

```bash
make lint-core
make lint-top
make sim-core
make sim-top
```

หรือ:

```bash
make all
```

---

# 34. Step 13 — Install Wrapper เข้า Repository

Lab ไม่ overwrite source เดิมอัตโนมัติ

หลัง verification ผ่านเท่านั้นจึง:

```bash
make install-wrapper
```

ก่อน overwrite script จะ backup:

```text
src/chip_core.sv.lab04_backup_YYYYMMDD_HHMMSS
src/chip_top.sv.lab04_backup_YYYYMMDD_HHMMSS
```

แล้ว copy:

```text
rtl/chip_core.sv -> repo/src/chip_core.sv
rtl/chip_top.sv  -> repo/src/chip_top.sv
```

นี่สำคัญเพราะ wrapper เดิมใน repository อาจเป็น work-in-progress ที่ต้องเก็บไว้เปรียบเทียบ

---

# 35. Step 14 — Inspect Git Diff

หลัง install:

```bash
cd "$HOME/workshop/synpnr_osoc1_cpu"

git status
git diff -- src/chip_core.sv src/chip_top.sv
```

ตรวจให้แน่ใจว่า change มีเฉพาะ wrapper ที่ตั้งใจ

จากนั้น:

```bash
git add src/chip_core.sv src/chip_top.sv
```

ถ้าต้องการ commit:

```bash
git commit -m \
  "Add minimal CPU full-chip wrapper for IHP SG13G2"
```

---

# 36. Full-Chip Timing Interface

Lab ให้ baseline:

```text
constraints/chip_top.sdc
```

clock ถูกประกาศที่:

```tcl
[get_ports clk_PAD]
```

ไม่ใช่:

```text
clk_i
```

เพราะ hierarchy เปลี่ยนจาก core-only:

```text
clk_i
```

ไปเป็น physical chip port:

```text
clk_PAD
```

---

# 37. Internal Clock Net

ใน physical design clock path คือ:

```text
clk_PAD
   |
clk_pad
   |
p2c
   |
clk_core
```

ดังนั้น LibreLane full-chip config ใน Lab ถัดไปควรใช้แนวคิด:

```yaml
CLOCK_PORT: clk_PAD
CLOCK_NET: clk_pad/p2c
```

ชื่อ hierarchical net/instance ต้องตรวจกับ netlist/LibreLane version อีกครั้งก่อน freeze config

---

# 38. Reset Timing

reset เป็น asynchronous active-low

SDC:

```tcl
set_false_path \
  -from [get_ports rst_n_PAD]
```

นี่ remove reset จาก normal setup paths

แต่ final physical verification ยังต้องพิจารณา:

```text
recovery
removal
reset distribution
reset slew
```

แยกต่างหาก

---

# 39. Signal-Pad Budget

Lab 4 ใช้:

```text
clk       1
reset     1
outputs   8
------------
signals  10
```

power pads:

```text
VDD       2
VSS       2
IOVDD     2
IOVSS     2
------------
power      8
```

รวม baseline instances:

```text
18 pads
```

ไม่รวม corner/filler/bondpad structures

นี่เหมาะกว่าการ expose CPU memory bus ทั้งหมดมาก

---

# 40. Why 30 mA Output Pad?

Lab ใช้ cell:

```text
sg13g2_IOPadOut30mA
```

เพราะเป็น output-cell style ที่ official IHP full-chip template ใช้

ไม่ได้หมายความว่า CPU output ต้องใช้กระแส 30 mA จริงในการใช้งานทุกกรณี

การเลือก final pad drive strength ต้องพิจารณา:

```text
load capacitance
package
board
edge rate
signal integrity
EM/IR
power
```

อีกครั้งสำหรับ tapeout

---

# 41. Hierarchy หลัง Lab 4

expected logical hierarchy:

```text
chip_top
|
+-- clk_pad : sg13g2_IOPadIn
|
+-- rst_n_pad : sg13g2_IOPadIn
|
+-- outputs[0].output_pad : sg13g2_IOPadOut30mA
+-- ...
+-- outputs[7].output_pad : sg13g2_IOPadOut30mA
|
+-- vdd_pads[*]
+-- vss_pads[*]
+-- iovdd_pads[*]
+-- iovss_pads[*]
|
+-- i_chip_core : chip_core
    |
    +-- u_cpu : osoc1_cpu_core
        |
        +-- u_pc_reg
        +-- u_pc_plus_4
        +-- u_decoder
        +-- u_ctrl
        +-- u_reg_file
        +-- u_alu_muxes
        +-- u_alu
        +-- u_sau
        +-- u_lau
        +-- u_rf_wb_mux
        +-- u_bcu
        +-- u_next_pc_logic
```

---

# 42. Wrapper Boundaries

มีสาม abstraction levels:

```text
Level A:
osoc1_cpu_core
```

รู้จัก instruction/data-memory protocol

```text
Level B:
chip_core
```

รู้จัก CPU และ on-chip subsystem

```text
Level C:
chip_top
```

รู้จัก physical pads/power

ควรรักษาขอบเขตนี้ไว้เมื่อเพิ่ม SRAM/UART/GPIO ในอนาคต

---

# 43. ที่ใดควรใส่ SRAM ในอนาคต

ไม่ควรใส่ SRAM logic ใน:

```text
chip_top
```

ควรอยู่:

```text
chip_core
```

architecture:

```text
chip_top
   |
   +-- IO Pads
   |
   +-- chip_core
        |
        +-- CPU
        +-- instruction SRAM
        +-- data SRAM
        +-- GPIO
        +-- UART
```

ทำให้ physical I/O wrapper ไม่ปนกับ SoC architecture

---

# 44. ที่ใดควรใส่ Pad Cells

Pad cells ควรอยู่:

```text
chip_top
```

ไม่ใช่:

```text
chip_core
```

เพราะ pad cells เป็น:

```text
technology/package boundary
```

ส่วน CPU/peripherals เป็น:

```text
digital core domain
```

---

# 45. Troubleshooting — `osoc1_cpu` Not Found

ถ้าใช้ wrapper เดิมอาจพบ:

```text
module osoc1_cpu not found
```

สาเหตุ:

wrapper placeholder อ้าง module name ไม่ตรง

CPU จริง:

```text
osoc1_cpu_core
```

ใช้ไฟล์ Lab:

```text
rtl/chip_core.sv
```

แทน placeholder เดิม

---

# 46. Troubleshooting — GPIO Port Not Found

ถ้าเห็น:

```text
gpio_in
gpio_out
```

ใน wrapper ที่ instantiate CPU แสดงว่ายังใช้ placeholder architecture

CPU จริงไม่มี GPIO ports โดยตรง

ต้องเชื่อม:

```text
pc_o
instr_i
dmem_*
```

ผ่าน `chip_core`

---

# 47. Troubleshooting — IHP Pad Module Not Found ตอน Lint

Verilator standalone ไม่รู้จัก PDK cell โดยอัตโนมัติ

Lab จึงให้:

```text
sim/ihp_io_stubs.v
```

ใช้:

```bash
make lint-top
```

อย่า copy simulation stub เข้า:

```text
src/
```

หรือ LibreLane `VERILOG_FILES`

---

# 48. Troubleshooting — Output เป็น `Z`

ถ้า pad-level simulation:

```text
output_PAD = z
```

ตรวจ output stub:

```systemverilog
assign pad = c2p;
```

ตรวจ instance:

```systemverilog
.c2p(output_core[i])
.pad(output_PAD[i])
```

---

# 49. Troubleshooting — Clock ไม่เข้า CPU

ถ้า PC ไม่เดินที่ pad-level แต่ `sim-core` ผ่าน

ตรวจ:

```text
clk_PAD
 -> clk_pad.pad
 -> clk_pad.p2c
 -> clk_core
 -> chip_core.clk
```

ใน stub ต้องมี:

```systemverilog
assign p2c = pad;
```

---

# 50. Troubleshooting — Reset ไม่เข้า CPU

ตรวจ:

```text
rst_n_PAD
 -> rst_n_pad
 -> rst_n_core
 -> chip_core.rst_n
 -> osoc1_cpu_core.rst_ni
```

polarity ต้องไม่ invert

---

# 51. Troubleshooting — Output นับ 4,8,C แทน 1,2,3

ถ้า output ใช้:

```text
pc[7:0]
```

จะเห็น increment 4

Lab ต้องใช้:

```systemverilog
assign output_out = pc[9:2];
```

---

# 52. Troubleshooting — Power-Pin Compile Error

simulation ปกติไม่ define:

```text
USE_POWER_PINS
```

ถ้ากำหนด macro นี้ ต้อง connect testbench supplies หรือเพิ่ม power-net declarations ให้ครบ

สำหรับ basic functional simulation:

```text
do not define USE_POWER_PINS
```

สำหรับ real full-chip synthesis:

```text
define USE_POWER_PINS
```

ตาม PDK/flow configuration

---

# 53. Pass Criteria

Lab 4 ผ่านเมื่อ:

```text
[ ] CPU interface check PASS
[ ] wrapper structural check PASS
[ ] chip_core lint PASS
[ ] chip_top lint PASS
[ ] chip_core simulation PASS
[ ] pad-level simulation PASS
[ ] reset reaches CPU
[ ] clock reaches CPU
[ ] output_PAD[7:0] = PC[9:2]
[ ] dmem_we remains zero for NOP
[ ] synthesis file list excludes simulation stubs
[ ] LAB04_REPORT.md generated
```

---

# 54. Deliverables

```text
rtl/chip_core.sv
rtl/chip_top.sv

sim/ihp_io_stubs.v

tb/tb_chip_core.sv
tb/tb_chip_top.sv

constraints/chip_top.sdc

reports/00_environment.log
reports/01_repo_check.txt
reports/02_wrapper_check.txt
reports/03_chip_core_lint.log
reports/04_chip_top_lint.log
reports/05_chip_core_sim.log
reports/06_chip_top_sim.log
reports/07_synth_filelist.txt
reports/LAB04_REPORT.md
```

---

# 55. Design Review Questions

1. ทำไมไม่ expose instruction/data bus ทั้งหมดเป็น pads?
2. ทำไม `chip_core` กับ `chip_top` ควรแยกกัน?
3. ทำไม NOP source อยู่ใน `chip_core`?
4. ทำไมใช้ `PC[9:2]` แทน `PC[7:0]`?
5. `p2c` และ `c2p` หมายถึงอะไร?
6. ทำไม pad-level ports จึงใช้ `inout wire`?
7. ทำไม simulation I/O stubs ห้ามเข้า synthesis source list?
8. `USE_POWER_PINS` มีบทบาทอย่างไร?
9. ทำไม clock constraint เปลี่ยนจาก `clk_i` เป็น `clk_PAD`?
10. ถ้า `sim-core` ผ่านแต่ `sim-top` fail เราควรเริ่ม debug ที่ subsystem ใด?

---

# 56. สิ่งที่ Freeze หลัง Lab 4

หลัง Lab ผ่าน ให้ freeze architecture:

```text
Top:
chip_top

Core wrapper:
chip_core

CPU:
osoc1_cpu_core

Clock pad:
clk_PAD

Reset pad:
rst_n_PAD

Observable outputs:
output_PAD[7:0] = PC[9:2]

Instruction source:
constant RV32 NOP

Data read response:
0x00000000

Output I/O type:
sg13g2_IOPadOut30mA

Input I/O type:
sg13g2_IOPadIn
```

---

# 57. Transition ไป Lab 5

Lab 5 จะนำ hierarchy นี้:

```text
chip_top
   |
IHP pad cells
   |
chip_core
   |
CPU
```

เข้า LibreLane `Chip` flow และเริ่ม:

```text
pad instance enumeration
PAD_NORTH
PAD_SOUTH
PAD_EAST
PAD_WEST
bondpad
die/core dimensions
floorplan
power pads
PDN
```

ดังนั้น Lab 4 ต้องจบด้วย RTL wrapper ที่ stable ก่อนเริ่ม physical pad placement

---

# 58. Engineering Rule

กฎของ Lab นี้:

> simulation stub มีไว้พิสูจน์ logic connectivity แต่ PDK model มีไว้สร้าง silicon

ห้ามนำสองสิ่งนี้มาปน source set เดียวกัน

และ:

> `chip_top` ควรเป็น technology/package boundary; `chip_core` ควรเป็น digital-system boundary

การรักษา abstraction นี้จะทำให้การเพิ่ม SRAM, GPIO, UART และ DFT ในเวอร์ชันถัดไปง่ายขึ้นอย่างมาก
