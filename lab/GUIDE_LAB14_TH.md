# Lab 14 — CPU Bus Adapter and Wait-State Control
## Deep Step-by-Step Ready-to-Run Guide
### Making `osoc1_cpu_core` Work with Synchronous SRAM

**Previous Lab:** Lab 12 — SRAM and Instruction Memory Integration  
**CPU baseline:** `osoc1_cpu_core`  
**Lab CPU variant:** `osoc1_cpu_core_wait`  
**Bus adapter:** `osoc_cpu_bus_adapter`  
**Instruction memory:** combinational ROM  
**Data memory:** 1-cycle synchronous SRAM  
**Clock:** 50 MHz / 20 ns

---

# 1. ปัญหาที่ Lab นี้แก้

CPU เดิมถูกออกแบบให้:

```text
instruction
decode
execute
memory
write-back
PC update
```

เกิดเป็น single-cycle architectural transaction

แต่ SRAM จริง:

```text
request cycle N
response cycle N+1
```

ดังนั้นถ้า CPU ไม่หยุด:

```text
LW instruction
  |
request SRAM
  |
PC advances too early
  |
next instruction arrives
  |
old/invalid SRAM data may be written
```

---

# 2. Source Observation จาก CPU ปัจจุบัน

current `osoc1_cpu_core` มี internal control:

```text
mem_re
master_mem_we
rf_we
```

ดังนั้นข้อมูลว่า instruction ปัจจุบันเป็น load/store มีอยู่แล้ว

ปัญหาคือไม่ได้ expose ออก top-level

---

# 3. Original Data Interface

public CPU interface:

```text
dmem_we_o[3:0]
dmem_addr_o[31:0]
dmem_wdata_o[31:0]
dmem_rdata_i[31:0]
```

---

# 4. Ambiguity

ถ้า:

```text
dmem_we_o = 0000
```

อาจหมายถึง:

```text
LOAD
```

หรือ:

```text
non-memory instruction
```

ดังนั้น adapter ภายนอกอย่างเดียวไม่สามารถสร้าง valid ที่ถูกต้องจาก `dmem_we_o`

---

# 5. Correct Request Valid

inside current core:

```text
mem_re
master_mem_we
```

จึง define:

```systemverilog
dmem_valid_o = mem_re | master_mem_we;
```

---

# 6. Second Problem — CPU Cannot Stall

even with valid signal:

```text
bus ready=0
```

CPU เดิมยัง update:

```text
PC
register file
```

ทุก clock

---

# 7. Architectural State in Current Core

สำหรับ Lab นี้ sequential architectural updates หลักคือ:

```text
PC register
register-file write
```

---

# 8. PC Behavior

original:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni)
    pc_q_o <= pc_d_i;
```

ไม่มี enable

---

# 9. Register File Behavior

original:

```systemverilog
always_ff @(posedge clk_i)
    if (we_i)
        registers[rd] <= wd_i;
```

ดังนั้นต้อง suppress write ระหว่าง stall

---

# 10. Lab 14 Solution

สร้าง:

```text
pc_reg_ce
osoc1_cpu_core_wait
osoc_cpu_bus_adapter
```

---

# 11. Commit Enable

```systemverilog
commit_en = !stall_i;
```

PC:

```text
en = commit_en
```

register file:

```text
we = rf_we && commit_en
```

---

# 12. Why This Is Better Than RTL Clock Gating

ไม่ใช้:

```systemverilog
cpu_clk = clk_i & enable;
```

เพราะ derived clock ทำให้:

```text
glitch risk
CTS complexity
timing complexity
clock-tree methodology changes
```

---

# 13. Future Low-Power Clock Gating

ถ้าต้องการจริง:

```text
integrated clock-gating cell
```

ผ่าน synthesis/PD methodology

ไม่ควรทำด้วย random AND gate

---

# 14. Adapter Interface

CPU side:

```text
cpu_valid
cpu_addr
cpu_wdata
cpu_wstrb
cpu_rdata
cpu_stall
cpu_error
```

Bus side:

```text
bus_valid
bus_addr
bus_wdata
bus_wstrb
bus_rdata
bus_ready
bus_error
```

---

# 15. Stall Equation

```systemverilog
cpu_stall_o =
    cpu_valid_i &&
    !bus_ready_i;
```

---

# 16. No Request

ถ้า:

```text
cpu_valid = 0
```

then:

```text
stall = 0
```

CPU executes normal ALU/branch instruction without bus dependency

---

# 17. Memory Request Begins

ถ้า CPU decodes:

```text
LW
SW
LB
SB
...
```

then:

```text
dmem_valid = 1
```

---

# 18. Bus Not Ready

first SRAM cycle:

```text
valid=1
ready=0
```

adapter generates:

```text
stall=1
```

---

# 19. What Stall Freezes

```text
PC
register-file write
```

current instruction stays active

---

# 20. What Is Allowed to Recompute

combinational blocks:

```text
decoder
ALU
SAU
LAU
branch logic
writeback mux
```

may continue to evaluate

no architectural state commits while stalled

---

# 21. Bus Ready

following cycle:

```text
ready=1
```

adapter:

```text
stall=0
```

---

# 22. Load Commit

for LW:

```text
bus_rdata
 -> LAU
 -> RF writeback mux
 -> register file
```

at commit edge

---

# 23. Store Commit

for SW:

SRAM write occurs in memory slave

when bus transaction is accepted

CPU then advances after ready

---

# 24. Load Timeline

```text
              Cycle N               Cycle N+1
CPU instr       LW                     LW
valid           1                      1
ready           0                      1
stall           1                      0
PC              hold                   commit next
RF write        blocked                allowed
rdata           not ready              valid
```

---

# 25. Store Timeline

```text
              Cycle N               Cycle N+1
CPU instr       SW                     SW
valid           1                      1
wstrb           !=0                    !=0
ready           0                      1
stall           1                      0
PC              hold                   advance
```

---

# 26. Why Request Does Not Duplicate

SRAM slave uses internal:

```text
busy_q
```

when request accepted:

```text
busy=1
```

while CPU remains stalled

on response cycle:

```text
ready=1
```

slave completes rather than accepting another transaction

---

# 27. Firmware Test Program

```assembly
lui   x1,0x20000
addi  x2,x0,0x12
sw    x2,0(x1)
lw    x3,0(x1)
addi  x4,x3,1
sw    x4,4(x1)
lw    x5,4(x1)
jal   x0,0
```

---

# 28. Expected Register Values

```text
x1 = 0x20000000
x2 = 0x00000012
x3 = 0x00000012
x4 = 0x00000013
x5 = 0x00000013
```

---

# 29. Expected SRAM

```text
SRAM[0] = 0x00000012
SRAM[1] = 0x00000013
```

---

# 30. Expected Bus Transactions

exactly:

```text
2 stores
2 loads
```

---

# 31. Memory Addresses

```text
SW  -> 0x20000000
LW  -> 0x20000000
SW  -> 0x20000004
LW  -> 0x20000004
```

---

# 32. Directory Structure

```text
lab14_cpu_bus_adapter_waitstate/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB14_TH.md
│
├── config/
│   ├── cpu_source_manifest.txt
│   └── architecture.yaml
│
├── rtl/
│   ├── pc_reg_ce.sv
│   ├── osoc1_cpu_core_wait.sv
│   ├── osoc_cpu_bus_adapter.sv
│   ├── osoc_imem_rom.sv
│   ├── sram_1kx32_beh.sv
│   ├── ihp_sram_1kx32.sv
│   ├── osoc_sram_bus_slave.sv
│   └── osoc_cpu_waitstate_demo.sv
│
├── firmware/
│   ├── start.S
│   ├── linker.ld
│   ├── firmware.hex
│   └── README.md
│
├── tb/
│   └── tb_cpu_waitstate.sv
│
├── docs/
│   ├── STALL_PROTOCOL.md
│   └── CPU_PATCH_NOTES.md
│
├── scripts/
├── build/
└── reports/
```

---

# 33. Original CPU Files Reused

Lab reuses current repository:

```text
cpu_sv_package.sv
pc_plus_4.sv
decoder.sv
ctrl.sv
alu_in_muxes.sv
alu.sv
sau.sv
lau.sv
rf_wb_mux.sv
reg_file.sv
bcu.sv
next_pc_logic.sv
```

---

# 34. Files Not Reused

Lab does not use original:

```text
pc_reg.sv
osoc1_cpu_core.sv
```

because stallable versions replace them

---

# 35. Original Repo Is Not Overwritten

this is deliberate

original CPU remains:

```text
known baseline
```

Lab adds a controlled derivative

---

# 36. Step 1 — Enter Lab

example:

```bash
cd ~/workshop/synpnr_osoc1_cpu/labs/lab14_cpu_bus_adapter_waitstate
```

---

# 37. Step 2 — Environment Check

```bash
make check-env
```

required:

```text
python3
verilator
```

---

# 38. Step 3 — Repository Check

```bash
make REPO_ROOT=../.. check-repo
```

verifies all reused modules exist

and checks original core still contains:

```text
mem_re
master_mem_we
rf_we
```

---

# 39. Why Check Original Source

the Lab depends on current control architecture

if upstream CPU changes:

```text
memory request generation
writeback
sequential state
```

must be re-reviewed

---

# 40. Step 4 — Adapter Contract Check

```bash
make check-contract
```

checks:

```text
dmem_valid exposed
stall equation
PC commit enable
RF write masking
no manual clock gating
```

---

# 41. Step 5 — Firmware Check

```bash
make check-firmware
```

validates all 8 machine words

---

# 42. Step 6 — Lint

```bash
make REPO_ROOT=../.. lint
```

uses behavioral SRAM:

```text
SRAM_BEHAV_MODEL
```

---

# 43. Compile Order

package first:

```text
cpu_sv_package.sv
```

then reused CPU blocks

then Lab stallable CPU and memory subsystem

---

# 44. Step 7 — Simulation

```bash
make REPO_ROOT=../.. sim
```

---

# 45. Testbench Observation 1 — PC Freeze

during:

```text
stall=1
```

testbench records PC

if next stalled cycle sees different PC:

```text
FAIL
```

---

# 46. Why PC Freeze Is the Primary Proof

without it CPU has moved to next instruction

even if final SRAM accidentally looks correct

---

# 47. Observation 2 — Memory Operation Count

expected:

```text
2 STORE complete
2 LOAD complete
```

not:

```text
duplicate requests
```

---

# 48. Observation 3 — Stall Count

with one-cycle SRAM each load/store creates wait state

test requires:

```text
stall_cycles >= 4
```

---

# 49. Observation 4 — x3

after first LW:

```text
x3 = 0x12
```

proves load data arrived before RF commit

---

# 50. Observation 5 — x5

after second LW:

```text
x5 = 0x13
```

---

# 51. Observation 6 — SRAM Word 0

```text
mem[0] = 0x12
```

---

# 52. Observation 7 — SRAM Word 1

```text
mem[1] = 0x13
```

---

# 53. Expected Log

example:

```text
BUS STORE complete pc=00000008 addr=20000000 ...
BUS LOAD  complete pc=0000000c addr=20000000
BUS STORE complete pc=00000014 addr=20000004 ...
BUS LOAD  complete pc=00000018 addr=20000004

stall_cycles=...
completed_mem_ops=4

PASS: Lab 14 CPU bus adapter and wait-state control completed.
```

---

# 54. Step 8 — Simulation Check

```bash
make check-sim
```

parses:

```text
store count
load count
stall count
completed transactions
PASS signature
```

---

# 55. Step 9 — Optional Yosys Probe

```bash
make REPO_ROOT=../.. yosys
```

structural check only

---

# 56. Step 10 — Report

```bash
make report
```

output:

```text
reports/LAB14_REPORT.md
```

---

# 57. One-Command Run

```bash
make REPO_ROOT=../.. all
```

---

# 58. Why `stall` Is Combinational

adapter must prevent commit at the first rising edge after a memory request
appears

therefore:

```text
request valid
+
ready
```

directly determines stall

---

# 59. Potential Combinational Path

```text
CPU decode/ALU
 -> dmem_valid/address
 -> bus decode/slave ready
 -> stall
 -> PC/RF enables
```

for complex SoC this can become timing-critical

---

# 60. Why It Is Acceptable Baseline

current SoC is:

```text
single master
simple slave
50 MHz baseline
```

and educational clarity matters

---

# 61. Future Registered Adapter

larger SoC can register request:

```text
IDLE
REQ
WAIT
RESP
```

FSM

but CPU must still be frozen correctly

---

# 62. Future Outstanding Transaction Register

request can be latched:

```text
addr
wdata
wstrb
```

allowing CPU combinational outputs to be decoupled from bus

---

# 63. Why We Do Not Need It Yet

while stalled:

```text
PC does not change
register file does not change
```

thus decode and address remain stable

for this single-cycle core

---

# 64. Stability Assumption

during stall:

```text
instr_i remains same
PC remains same
register operands remain same
```

therefore:

```text
addr
wdata
wstrb
valid
```

remain stable

---

# 65. Important Verification Extension

production verification should assert:

```text
stall -> stable(PC)
stall -> stable(bus_addr)
stall -> stable(bus_wdata)
stall -> stable(bus_wstrb)
```

---

# 66. Bus Error Handling

adapter exposes:

```text
cpu_error_o
```

when:

```text
valid && ready && error
```

---

# 67. Current CPU Error Policy

Lab does not implement:

```text
exception trap
mcause
mtval
```

yet

---

# 68. Why Not Silently Ignore in System Top

demo top latches:

```text
fault_seen_o
```

for verification

---

# 69. Future Precise Exception

later CSR/exception Lab should convert bus error to:

```text
load access fault
store/AMO access fault
```

with PC preserved precisely

---

# 70. Instruction Fetch Error

IMEM has:

```text
hit_o
```

demo top also treats missing IMEM hit as fault observation

---

# 71. No Stall for ALU Instructions

example:

```text
ADDI
LUI
JAL
```

have:

```text
dmem_valid=0
```

therefore:

```text
stall=0
```

---

# 72. Load Request

ctrl produces:

```text
mem_re=1
```

therefore:

```text
dmem_valid=1
```

even though:

```text
dmem_we=0000
```

this solves the Lab-11 ambiguity

---

# 73. Store Request

ctrl:

```text
master_mem_we=1
```

SAU creates:

```text
byte strobe
```

and:

```text
dmem_valid=1
```

---

# 74. Why dmem_valid Is Separate from wstrb

because:

```text
wstrb=0
```

means LOAD or no request

`valid` distinguishes them

---

# 75. Byte/Halfword Loads

LAU already handles alignment/sign/zero extension

wait-state mechanism is independent of width

---

# 76. Byte/Halfword Stores

SAU generates write strobes

adapter forwards them unchanged

---

# 77. Future Test Expansion

add:

```text
SB
SH
LB
LBU
LH
LHU
```

once base wait-state test passes

---

# 78. Why First Test Uses LW/SW

simplest data-path proof

isolates wait-state control from byte-alignment details

---

# 79. Synthesizability

stall logic adds:

```text
one PC enable mux behavior
RF write-enable AND
valid output
small adapter combinational logic
```

minimal area impact

---

# 80. Clock Tree Impact

clock remains:

```text
one original clock
```

no new clock domain

---

# 81. Why This Helps CTS

no generated clock is introduced

CTS remains simpler

---

# 82. Power Implication

while stalled:

```text
PC/RF architectural state does not toggle
```

but combinational CPU logic can still toggle

---

# 83. Future Low-Power Improvement

later:

```text
operand isolation
integrated clock gating
bus request registers
```

can reduce stall-cycle switching

---

# 84. No Clock-Gating Claim

Lab 14 is:

```text
functional wait-state control
```

not low-power clock-gating Lab

---

# 85. Integration with Lab 12 IMEM

direct:

```text
pc_o -> osoc_imem_rom.addr
rom.rdata -> instr_i
```

no wait

---

# 86. Integration with Lab 12 SRAM

adapter:

```text
CPU
 ->
valid/addr/wdata/wstrb
 ->
SRAM slave
```

---

# 87. Integration with System Bus

replace direct SRAM connection with:

```text
osoc_system_bus
```

later

same adapter interface remains

---

# 88. GPIO Integration

once bus connects real GPIO:

```text
SW xN, GPIO_BASE(...)
```

will stall only according to GPIO ready

GPIO same-cycle ready may produce:

```text
stall=0
```

for that transaction

---

# 89. Mixed-Latency Slave Support

this is exactly why handshake matters:

```text
GPIO: 0 wait state
SRAM: 1 wait state
SPI: many wait states
```

CPU adapter does not need per-slave special logic

---

# 90. Adapter Invariant

```text
CPU instruction commits iff
  no data request
  OR current data request is ready
```

equivalent:

```text
commit_en = !(valid && !ready)
```

---

# 91. Formal Property Candidate

```systemverilog
assert property (
  cpu_stall |=> $stable(pc)
);
```

---

# 92. Request Stability Property

```systemverilog
assert property (
  cpu_stall |=> $stable(bus_addr)
);
```

---

# 93. No Spurious Stall Property

```systemverilog
assert property (
  !cpu_valid |-> !cpu_stall
);
```

---

# 94. Ready Releases Stall

```systemverilog
assert property (
  cpu_valid && bus_ready |-> !cpu_stall
);
```

---

# 95. Pass Criteria — CPU Modification

```text
[ ] dmem_valid exposed
[ ] PC has enable
[ ] RF write masked during stall
[ ] no RTL generated clock
```

---

# 96. Pass Criteria — Adapter

```text
[ ] request forwarded
[ ] response forwarded
[ ] stall while valid&&!ready
[ ] no stall without request
[ ] bus error observable
```

---

# 97. Pass Criteria — Execution

```text
[ ] 2 stores complete
[ ] 2 loads complete
[ ] PC stable during stall
[ ] x3=0x12
[ ] x5=0x13
[ ] SRAM[0]=0x12
[ ] SRAM[1]=0x13
[ ] no bus fault
```

---

# 98. Reports

```text
reports/
├── 00_environment.log
├── 01_repo_check.txt
├── 02_adapter_contract.txt
├── 03_firmware.txt
├── 04_lint.log
├── 05_sim_build.log
├── 05_sim.log
├── 06_sim_check.txt
├── 07_yosys_probe.log
└── LAB14_REPORT.md
```

---

# 99. Recommended Run

```bash
make clean
make REPO_ROOT=../.. check-env
make REPO_ROOT=../.. check-repo
make check-contract
make check-firmware
make REPO_ROOT=../.. lint
make REPO_ROOT=../.. sim
make check-sim
make REPO_ROOT=../.. yosys
make report
```

---

# 100. One Command

```bash
make REPO_ROOT=../.. all
```

---

# 101. Common Failure — `dmem_valid` Never Asserts on Load

inspect:

```text
ctrl.datamem_re_o
mem_re
```

do not infer load only from wstrb

---

# 102. Common Failure — PC Advances During Wait

check:

```text
stall_i
commit_en
pc_reg_ce.en_i
```

---

# 103. Common Failure — Load Writes Garbage Before Ready

check RF write masking:

```text
rf_we && !stall
```

---

# 104. Common Failure — Duplicate Stores

check SRAM slave handshake:

```text
busy_q
ready
```

and ensure CPU request remains stable until ready

---

# 105. Common Failure — Store Address Changes

usually means architectural state was not fully frozen

check PC and register-file commit paths

---

# 106. Common Failure — Final x3 Wrong

debug sequence:

```text
LW decode
dmem_valid
stall
SRAM ren
SRAM ready
rdata
LAU
rf_wd
RF commit
```

---

# 107. Common Failure — Native Yosys Parser

current CPU uses SystemVerilog packages/enums

LibreLane flow should prefer:

```text
Slang
```

native Yosys probe is optional diagnostic

---

# 108. Physical Flow Impact

new stall logic remains standard-cell RTL

IHP SRAM remains hard macro

no change to pad ring yet

---

# 109. Timing Path to Watch

post-synthesis:

```text
bus_ready
 -> stall
 -> PC enable / RF write-enable
```

must meet setup timing

---

# 110. Another Timing Path

```text
SRAM rdata
 -> LAU
 -> writeback mux
 -> reg-file D
```

on ready/commit cycle

this may become significant at higher frequency

---

# 111. 50-MHz Baseline

20 ns gives generous training margin

do not assume 100/200 MHz until STA confirms

---

# 112. Next Integration

after Lab 14:

```text
CPU
+ IMEM
+ adapter
+ System Bus
+ SRAM
+ GPIO
```

can execute real memory-mapped I/O firmware

---

# 113. Natural Next Firmware

```assembly
lui GPIO base
sw direction
sw output
```

to blink GPIO through CPU rather than testbench bus master

---

# 114. Future Timer/SPI

same CPU adapter works with:

```text
timer
SPI
PLIC
debug
```

because all are bus slaves with ready/error

---

# 115. Why Adapter Must Remain Generic

do not encode:

```text
if address is SRAM stall one cycle
```

inside CPU adapter

latency belongs to slave handshake

---

# 116. Design Review Questions

1. ทำไม `dmem_we=0` ระบุ LOAD ไม่ได้?
2. ทำไมต้อง expose `mem_re` เป็น valid?
3. อะไรต้อง freeze ระหว่าง wait-state?
4. ทำไมไม่ใช้ `clk & !stall`?
5. LOAD commit cycleเกิดเมื่อใด?
6. STORE ต้อง hold requestถึงเมื่อใด?
7. ทำไม adapterไม่ควรรู้ SRAM latency?
8. mixed-latency slavesรองรับอย่างไร?
9. bus errorควรกลายเป็น exceptionแบบใดในอนาคต?
10. ถ้า SRAM dataถูกแต่ PCเปลี่ยนระหว่าง stall ถือว่า Labผ่านหรือไม่?

คำตอบข้อ 10:

```text
ไม่ผ่าน
```

---

# 117. Freeze after Lab 14

freeze:

```text
dmem_valid semantics
stall semantics
commit enable rule
PC freeze behavior
RF write suppression behavior
adapter valid/ready mapping
bus-error observation
```

---

# 118. Engineering Rule

> Wait-state correctness is an architectural commit problem, not merely a bus wiring problem.

CPU must not advance visible state until the transaction that the current
instruction depends on is complete.

และ:

> Never solve a synchronous-memory latency mismatch by pretending the memory is zero-latency in simulation.

The handshake and stall behavior must match the silicon memory timing model.
