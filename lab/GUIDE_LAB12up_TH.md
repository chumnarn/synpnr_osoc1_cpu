# Lab 12 — SRAM and Instruction Memory Integration
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 Memory Subsystem with IHP SG13G2 SRAM

**CPU target:** `osoc1_cpu_core`  
**Instruction interface:** `pc_o` / `instr_i`  
**Instruction memory:** 4 KiB combinational ROM  
**Instruction base:** `0x0000_0000`  
**Data SRAM:** IHP `RM_IHPSG13_1P_1024x32_c2_bm_bist`  
**Data base:** `0x2000_0000`  
**SRAM capacity:** 1024 × 32 = 4 KiB  
**Clock baseline:** 50 MHz

---

# 1. เป้าหมายของ Lab

Lab นี้สร้าง memory subsystem ที่ประกอบด้วยสองฝั่ง:

```text
Instruction Memory
+
Data SRAM
```

แต่ไม่ทำให้ทั้งสองฝั่งมี timing model เหมือนกันอย่างผิดธรรมชาติ

architecture:

```text
             future osoc1_cpu_core
               /              \
              /                \
        pc_o/instr_i         data access
             |                   |
             v                   v
      +--------------+    CPU bus adapter
      | IMEM ROM     |      (next Lab)
      | 4 KiB        |           |
      | combinational|           v
      +--------------+      data bus
                                  |
                                  v
                         +----------------+
                         | IHP SRAM bank0 |
                         | 1024 x 32      |
                         | 4 KiB          |
                         +----------------+
```

---

# 2. Critical Architectural Constraint

current CPU instruction interface:

```text
output pc_o
input  instr_i
```

ไม่มี:

```text
imem_valid
imem_ready
stall
```

ดังนั้น CPU expects instruction value to be available as a function of PC
without a memory handshake.

---

# 3. IHP SRAM Timing

IHP SRAM macro is synchronous

documentation specifies one-cycle data access

ดังนั้นถ้าใช้ SRAM macro directly as instruction memory:

```text
PC cycle N
 -> SRAM address capture
 -> instruction appears cycle N+1
```

แต่ CPU current architectureไม่ได้ stall

instructionจะเลื่อนผิด cycle

---

# 4. Baseline Decision

Lab 12 จึงใช้:

```text
Instruction memory = combinational ROM
Data memory        = synchronous IHP SRAM
```

นี่ไม่ใช่ workaround แบบสุ่ม

แต่เป็น deliberate architectureที่ตรงกับ CPU interfaceปัจจุบัน

---

# 5. Memory Map

```text
0x00000000 - 0x00000FFF
Instruction ROM
4 KiB

0x20000000 - 0x20000FFF
Data SRAM bank0
4 KiB

0x20001000 - 0x2000FFFF
Reserved future SRAM banks
60 KiB

0x40000000 ...
Peripherals
```

---

# 6. Why 4-KiB IMEM

1024 words × 4 bytes:

```text
4096 bytes
```

พอสำหรับ:

```text
startup
small bare-metal examples
GPIO bring-up
memory tests
```

และ map cleanlyด้วย 10-bit word index

---

# 7. Why 4-KiB Data SRAM Bank

IHP macro:

```text
RM_IHPSG13_1P_1024x32_c2_bm_bist
```

exactly:

```text
1024 words × 32 bits
```

same 4-KiB size

---

# 8. Instruction Addressing

byte address:

```text
PC = 0,4,8,12,...
```

word index:

```text
addr[11:2]
```

---

# 9. Data SRAM Addressing

same decomposition:

```text
0x20000000 -> word0
0x20000004 -> word1
...
0x20000FFC -> word1023
```

---

# 10. Instruction ROM RTL

file:

```text
rtl/osoc_imem_rom.sv
```

internally:

```systemverilog
logic [31:0] mem [0:1023];
```

---

# 11. ROM Initialization

on simulation/elaboration:

```systemverilog
$readmemh(INIT_FILE, mem);
```

default:

```text
firmware/firmware.hex
```

---

# 12. Safe Initialization

before loading firmware:

```text
all ROM words = 0x00000013
```

which is:

```assembly
addi x0,x0,0
```

RV32I NOP

---

# 13. Why NOP Fill Is Better Than X

unused ROM locations returning X cause:

```text
X propagation
unpredictable decoder behavior
difficult bring-up
```

NOP is deterministic and harmless for baseline verification

---

# 14. Out-of-Range Fetch

if address:

```text
misaligned
or
outside 4 KiB
```

ROM outputs:

```text
0x00000013
```

and:

```text
hit_o = 0
```

---

# 15. Why Expose `hit_o`

CPU interface does not use it yet

but verification/debug can distinguish:

```text
valid firmware fetch
```

from:

```text
safe fallback NOP
```

future CPU exception logic may consume it

---

# 16. Firmware Image

provided:

```text
firmware/firmware.hex
```

contains:

```text
00500093
00308113
00110193
0000006f
```

---

# 17. Firmware Disassembly

```text
0x00000000  00500093  addi x1,x0,5
0x00000004  00308113  addi x2,x1,3
0x00000008  00110193  addi x3,x2,1
0x0000000C  0000006F  jal x0,0
```

---

# 18. Why Use a Tiny Known Program

it provides unique words at consecutive addresses

therefore testbench can prove:

```text
ROM contents
word indexing
byte-address conversion
image ordering
```

better than filling every word with identical NOPs

---

# 19. Firmware Source

file:

```text
firmware/start.S
```

is rebuildable

---

# 20. Optional Firmware Rebuild

```bash
make firmware
```

default:

```text
RISCV_PREFIX=riscv64-unknown-elf-
```

---

# 21. Override Toolchain

```bash
make \
  RISCV_PREFIX=riscv32-unknown-elf- \
  firmware
```

---

# 22. ISA Flags

Makefile uses:

```text
-march=rv32i_zicsr
-mabi=ilp32
```

---

# 23. Link Address

linker:

```text
ORIGIN = 0x00000000
```

matching CPU reset PC

---

# 24. Binary-to-Hex Conversion

script:

```text
scripts/bin2hex.py
```

reads binary little-endian words and writes:

```text
8-hex-digit word per line
```

for `$readmemh`

---

# 25. Why Endianness Matters

RISC-V system is little-endian in this flow

binary bytes:

```text
93 00 50 00
```

must become word:

```text
00500093
```

in readmemh word image

---

# 26. Data SRAM Wrapper

file:

```text
rtl/ihp_sram_1kx32.sv
```

selects between:

```text
behavioral model
```

and:

```text
IHP hard macro
```

---

# 27. Simulation Mode

compile:

```text
SRAM_BEHAV_MODEL
```

then:

```text
sram_1kx32_beh
```

is used

---

# 28. Physical Mode

do not define:

```text
SRAM_BEHAV_MODEL
```

then instantiate:

```text
RM_IHPSG13_1P_1024x32_c2_bm_bist
```

---

# 29. SRAM Bus Slave

file:

```text
rtl/osoc_sram_bus_slave.sv
```

protocol:

```text
valid
addr
wdata
wstrb
->
rdata
ready
error
```

---

# 30. SRAM Read Latency

baseline:

```text
one cycle
```

request accepted on one clock

response `ready` asserts in following cycle

---

# 31. Why Data Side Can Tolerate Latency

because O'SoC bus has:

```text
ready
```

although CPU core itselfยังต้อง adapter/stall logic before direct connection

---

# 32. Instruction Side Has No Ready

therefore combinational ROM is mandatory for unchanged CPU microarchitecture

---

# 33. Memory Subsystem Top

file:

```text
rtl/osoc_memory_subsystem.sv
```

interfaces:

```text
imem_addr_i
imem_rdata_o
imem_hit_o

dmem_valid_i
dmem_addr_i
dmem_wdata_i
dmem_wstrb_i
dmem_rdata_o
dmem_ready_o
dmem_error_o
```

---

# 34. Why Separate IMEM/DMEM Ports

this mirrors Harvard-style CPU organization

benefits:

```text
instruction fetch and data access can proceed independently
no bus arbitration yet
simpler timing
matches current CPU interface
```

---

# 35. Directory Structure

```text
lab12_sram_and_instruction_memory/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB12_TH.md
│
├── rtl/
│   ├── osoc_imem_rom.sv
│   ├── sram_1kx32_beh.sv
│   ├── ihp_sram_1kx32.sv
│   ├── osoc_sram_bus_slave.sv
│   └── osoc_memory_subsystem.sv
│
├── tb/
│   └── tb_memory_subsystem.sv
│
├── firmware/
│   ├── start.S
│   ├── linker.ld
│   ├── firmware.hex
│   └── README.md
│
├── config/
│   ├── memory_map.yaml
│   └── memory_policy.yaml
│
├── scripts/
├── docs/
├── openroad/
├── reports/
└── build/
```

---

# 36. Step 1 — Enter Lab

```bash
cd lab12_sram_and_instruction_memory
```

---

# 37. Step 2 — Check Environment

```bash
make check-env
```

required:

```text
python3
verilator
```

optional:

```text
yosys
librelane
openroad
RISC-V GCC
```

---

# 38. Step 3 — Check Memory Map

```bash
make check-map
```

expected:

```text
IMEM_ROM    0x00000000..0x00000FFF
SRAM_BANK0  0x20000000..0x20000FFF
GPIO        0x40000000..0x40000FFF

PASS
```

---

# 39. Step 4 — Check Firmware

```bash
make check-firmware
```

checks supplied words against expected machine code

---

# 40. Why Verify Firmware Separately

if simulation fetch mismatch occurs:

possible causes:

```text
wrong binary
wrong endian conversion
wrong address index
wrong ROM path
```

checking image separately shortens debug

---

# 41. Step 5 — Architecture Contract Check

```bash
make check-arch
```

verifies:

```text
ROM exists
readmemh used
NOP fallback present
separate IMEM interface
data SRAM valid/ready interface
correct SRAM base
```

---

# 42. Step 6 — Lint

```bash
make lint
```

uses:

```text
-DSRAM_BEHAV_MODEL
```

---

# 43. Step 7 — Run Simulation

```bash
make sim
```

---

# 44. IMEM Test 1

fetch:

```text
0x00000000
```

expected:

```text
0x00500093
```

---

# 45. IMEM Test 2

fetch:

```text
0x00000004
```

expected:

```text
0x00308113
```

---

# 46. IMEM Test 3

fetch:

```text
0x00000008
```

expected:

```text
0x00110193
```

---

# 47. IMEM Test 4

fetch:

```text
0x0000000C
```

expected:

```text
0x0000006F
```

---

# 48. Unused In-Range Word

fetch:

```text
0x00000010
```

expected:

```text
NOP = 0x00000013
hit=1
```

---

# 49. Misaligned Instruction Fetch

fetch:

```text
0x00000002
```

expected:

```text
NOP
hit=0
```

---

# 50. Out-of-Range Instruction Fetch

fetch:

```text
0x00001000
```

expected:

```text
NOP
hit=0
```

---

# 51. Data SRAM Test 1

write:

```text
0x11223344
```

to:

```text
0x20000000
```

read back same value

---

# 52. Data SRAM Test 2

independent word:

```text
0x20000004
```

write/read:

```text
0xA5A55A5A
```

---

# 53. Byte Write Lane 0

start:

```text
11223344
```

write:

```text
000000EE
wstrb=0001
```

expected:

```text
112233EE
```

---

# 54. Byte Write Lane 3

write:

```text
99000000
wstrb=1000
```

expected:

```text
992233EE
```

---

# 55. Last SRAM Word

address:

```text
0x20000FFC
```

word index:

```text
1023
```

test value:

```text
CAFEBABE
```

---

# 56. Reserved SRAM Region

address:

```text
0x20001000
```

is reserved but not physically implemented

expected:

```text
error=1
```

---

# 57. Misaligned Data Access

```text
0x20000002
```

expected:

```text
error=1
```

---

# 58. SRAM Latency Assertion

testbench additionally ensures legal SRAM transactions do not return as a
zero-cycle combinational slave

at least one wait cycle must occur

---

# 59. Expected Simulation End

```text
PASS: Lab 12 SRAM and instruction-memory integration completed.
```

---

# 60. Step 8 — Check Simulation

```bash
make check-sim
```

---

# 61. Step 9 — Discover Installed IHP SRAM

```bash
make discover-sram
```

search root:

```text
$PDK_ROOT/ihp-sg13g2/libs.ref/sg13g2_sram
```

---

# 62. Current Delivered Views

current IHP OpenPDK SRAM library includes:

```text
cdl/
gds/
lef/
lib/
verilog/
doc/
```

---

# 63. Required Physical Views

at minimum:

```text
LEF
GDS
Verilog/blackbox
Liberty
```

and for LVS:

```text
CDL/SPICE-equivalent model
```

---

# 64. Why Use Installed PDK Discovery

avoid hard-coded paths and stale corner filenames

the local installed PDK must be source of truth

---

# 65. Step 10 — Generate Macro Blackbox

```bash
make blackbox
```

creates:

```text
build/RM_IHPSG13_1P_1024x32_c2_bm_bist.bb.v
```

---

# 66. Step 11 — Generate LibreLane Macro Snippet

```bash
make macro-snippet
```

output:

```text
build/librelane_sram_macro.yaml
```

---

# 67. Generated Instance Path

physical instance expected:

```text
u_dmem.u_sram.u_macro
```

must match synthesis hierarchy

---

# 68. LibreLane `MACROS`

generated structure:

```yaml
MACROS:
  RM_IHPSG13_1P_1024x32_c2_bm_bist:
    instances:
      "u_dmem.u_sram.u_macro":
        location: [...]
        orientation: N
    gds:
      - ...
    lef:
      - ...
    nl:
      - ...
```

---

# 69. Why Use `MACROS`

current LibreLane uses the `MACROS` object to describe hardened macros and
their views/instances

this is preferable to ad-hoc legacy path lists

---

# 70. Macro PDN

current control:

```yaml
FP_PDN_ENABLE_MACROS_GRID: true
```

explicit hook variable:

```yaml
FP_PDN_MACRO_HOOKS:
```

---

# 71. Deprecated PDN Name

do not build new manuals around:

```text
PDN_MACRO_CONNECTIONS
```

the current name is:

```text
FP_PDN_MACRO_HOOKS
```

---

# 72. BIST Pins

macro name:

```text
..._bm_bist
```

current IHP docs specify BIST-related signals

before physical signoff:

```text
inspect exact local model
tie normal-mode values explicitly
```

---

# 73. SRAM Supply Pins

IHP docs describe supply pins such as:

```text
VDD
VSS
VDDARRAY
```

do not assume VDDARRAY can float

---

# 74. PDN Connectivity Rule

visual overlap of power shapes is not proof of electrical connectivity

verify:

```text
vias
connected shapes
ODB
PDN reports
unconnected nodes
```

---

# 75. Why Instruction ROM Is Synthesizable

the combinational ROM may synthesize to:

```text
logic/mux structure
```

for small training firmware

this is acceptable for the first O'SoC integration stage

---

# 76. But It Is Not the Final Low-Power IMEM

larger programs need:

```text
ROM macro
SRAM
SPI XIP
cache/prefetch
```

depending architecture

---

# 77. Option A — Mask ROM Later

future silicon can replace combinational ROM with:

```text
hard ROM macro
```

if available

---

# 78. Option B — SPI XIP

program stored externally:

```text
SPI Flash
```

CPU fetches through:

```text
XIP controller/prefetch
```

---

# 79. Option C — SRAM Instruction Memory

requires:

```text
fetch wait-state
pipeline
prefetch buffer
or CPU clock enable
```

before synchronous SRAM can safely serve instruction fetch

---

# 80. Why Not Fake Zero-Latency SRAM

making behavioral SRAM combinational just to satisfy CPU would create:

```text
simulation architecture
!=
silicon architecture
```

which is dangerous

---

# 81. CPU Integration Plan

instruction side can already connect:

```text
cpu.pc_o -> imem_addr
imem_rdata -> cpu.instr_i
```

---

# 82. Data Side Still Needs Adapter

CPU outputs:

```text
dmem_we_o
dmem_addr_o
dmem_wdata_o
dmem_rdata_i
```

but no:

```text
valid
ready
stall
```

---

# 83. Why `dmem_we=0` Is Ambiguous

could mean:

```text
load
```

or:

```text
no data access
```

therefore adapter must know actual load/store request from CPU control/LSU

---

# 84. Next CPU-Bus Work

need identify or add:

```text
dmem_valid
```

and:

```text
cpu_stall / clock_enable
```

---

# 85. Correct Wait-State Behavior

for SRAM load:

```text
CPU presents load request
CPU freezes architectural state
SRAM request starts
ready arrives next cycle
load data captured
CPU resumes
```

---

# 86. Store Behavior

store:

```text
CPU presents addr/wdata/wstrb
CPU holds until ready
then advances
```

---

# 87. Why This Is Separate from Lab 12

memory subsystem should be independently verified first

otherwise CPU/stall and SRAM bugs are mixed together

---

# 88. Yosys Probe

optional:

```bash
make yosys
```

uses behavioral memory models

it is a structural sanity check only

---

# 89. Physical Synthesis Policy

when integrating SRAM hard macro:

```text
do not define SRAM_BEHAV_MODEL
```

and provide:

```text
blackbox
MACROS LEF/GDS/Liberty
```

---

# 90. IMEM Physical Synthesis

`osoc_imem_rom.sv` remains RTL in this baseline

synthesis maps it to available standard-cell logic unless later replaced

---

# 91. Area Warning

a 4-KiB combinational ROM synthesized from arbitrary firmware may consume
non-trivial area

measure synthesis area before committing to tapeout

---

# 92. Optimization Opportunity

because firmware is fixed, logic synthesis may aggressively optimize ROM
contents

this can be efficient for tiny programs but is not scalable

---

# 93. Training Benefit

this Lab makes memory-latency differences visible:

```text
ROM fetch:
same-cycle combinational

SRAM:
clocked one-cycle
```

an essential SoC architecture concept

---

# 94. Reports

after `make all`:

```text
reports/
├── 00_environment.log
├── 01_memory_map.txt
├── 02_firmware_hex.txt
├── 03_architecture.txt
├── 04_lint.log
├── 05_sim_build.log
├── 05_sim.log
├── 06_sim_check.txt
└── LAB12_REPORT.md
```

---

# 95. Physical Preparation Reports

after:

```bash
make discover-sram
```

also:

```text
reports/07_sram_views.txt
build/sram_views.json
```

---

# 96. Macro Output

after:

```bash
make macro-snippet
```

also:

```text
build/
├── RM_IHPSG13_1P_1024x32_c2_bm_bist.bb.v
└── librelane_sram_macro.yaml
```

---

# 97. Recommended Functional Run

```bash
make clean
make check-env
make check-map
make check-firmware
make check-arch
make lint
make sim
make check-sim
make report
```

---

# 98. One Command

```bash
make all
```

---

# 99. Recommended Physical Preflight

inside IHP/LibreLane environment:

```bash
make discover-sram
make macro-snippet
```

then inspect generated YAML before merging into full-chip config

---

# 100. IMEM Pass Criteria

```text
[ ] firmware.hex valid
[ ] address 0 -> first instruction
[ ] address 4 -> second instruction
[ ] address 8 -> third instruction
[ ] address C -> JAL
[ ] unused in-range word -> NOP
[ ] misaligned fetch -> NOP + hit=0
[ ] out-of-range fetch -> NOP + hit=0
```

---

# 101. SRAM Functional Pass Criteria

```text
[ ] full-word write/read
[ ] independent words
[ ] byte lane 0
[ ] byte lane 3
[ ] final word 1023
[ ] reserved bank address error
[ ] misaligned access error
[ ] one-cycle response
```

---

# 102. SRAM Physical Pass Criteria

```text
[ ] installed GDS found
[ ] LEF found
[ ] Verilog model found
[ ] Liberty models found
[ ] CDL recorded
[ ] blackbox generated
[ ] MACROS YAML generated
[ ] hierarchy path validated
```

---

# 103. Before Tapeout

must additionally verify:

```text
[ ] BIST normal-mode pins
[ ] VDD
[ ] VSS
[ ] VDDARRAY
[ ] macro PDN vias/connectivity
[ ] Liberty corner mapping
[ ] macro LVS/CDL model
```

---

# 104. Design Review Questions

1. ทำไม IMEM กับ DMEM ใช้ memory timing model ต่างกัน?
2. ทำไม synchronous SRAM ต่อ `instr_i` ตรงไม่ได้?
3. `addr[11:2]` หมายถึงอะไร?
4. ทำไม ROM fill เป็น NOP?
5. ทำไม `hit_o` useful แม้ CPU ยังไม่ใช้?
6. ทำไม SRAM data sideต้องมี `ready`?
7. ทำไม behavioral SRAMห้ามเข้า physical synthesis?
8. ทำไม firmware endiannessสำคัญ?
9. ทำไม `VDDARRAY` ต้องตรวจ?
10. ถ้า IMEM simulationผ่านแต่ SRAM hard macroถูก synthesizeเป็น flops ถือว่าผ่านหรือไม่?

คำตอบข้อ 10:

```text
ไม่ผ่าน
```

---

# 105. Freeze after Lab 12

freeze:

```text
IMEM base = 0x00000000
IMEM baseline size = 4 KiB
DMEM bank0 base = 0x20000000
DMEM bank0 size = 4 KiB
IMEM is combinational for current CPU
DMEM is synchronous one-cycle
firmware image format = one 32-bit hex word per line
```

---

# 106. Transition to CPU Integration

next architecture:

```text
                  osoc1_cpu_core
                   /          \
                  /            \
                PC              LSU
                |                |
                v                v
          IMEM ROM       CPU bus adapter
                               |
                               v
                          Data bus
                               |
                               v
                           IHP SRAM
```

---

# 107. Transition to GPIO

once CPU wait-state handling works:

```text
store instruction
   |
CPU bus adapter
   |
System Bus
   |
GPIO DATA_OUT
```

then firmware can blink a real GPIO register rather than testbench driving the bus

---

# 108. Engineering Rule

> Memory type must match the CPU timing contract.

Do not make a synchronous hard macro look combinational in simulation merely
because the CPU currently lacks `ready`.

and:

> A clean SoC integration proves instruction image correctness, memory protocol,
hard-macro preservation, and software address mapping separately before combining
them into a CPU-executed system.
