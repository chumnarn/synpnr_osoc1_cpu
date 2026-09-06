# Lab 17 — CPU External Interrupt + CSR/Trap Integration
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC Machine-Mode External Interrupt Path

**Previous:** Lab 14 CPU Wait-State, Lab 15 Timer IRQ, Lab 16 PLIC  
**Input:** `cpu_ext_irq_i` from PLIC  
**Privilege:** Machine-mode subset  
**Trap vector:** `mtvec` direct mode  
**Interrupt cause:** Machine External Interrupt = 11  
**Return:** `mret`

---

# 1. เป้าหมาย

Lab 16 จบที่:

```text
PLIC
  |
  v
cpu_ext_irq_o
```

แต่ CPU ยังไม่รู้ว่าจะ:

```text
หยุด flow ตอนไหน
เก็บ return PC ที่ไหน
เก็บ cause ที่ไหน
jump ไป ISR อย่างไร
mask nested interrupt อย่างไร
กลับด้วยอะไร
```

Lab 17 เติมทั้งหมดนี้ด้วย:

```text
CSR
+
precise trap control
+
MRET
```

---

# 2. End-to-End Path

```text
Timer/GPIO/SPI
      |
      v
     PLIC
      |
      v
 cpu_ext_irq
      |
      v
   mip.MEIP
      |
   mie.MEIE
      |
 mstatus.MIE
      |
      v
precise boundary
      |
      +--> mepc
      +--> mcause
      +--> MIE -> MPIE
      +--> MIE = 0
      +--> PC = mtvec
                    |
                    v
                   ISR
                    |
                   mret
                    |
                    v
             PC = mepc
             MIE restored
```

---

# 3. Why CSR Is Required

interrupt handling needs architectural state visible to software

minimum:

```text
mstatus
mie
mtvec
mepc
mcause
mip
```

---

# 4. CSR `mstatus`

address:

```text
0x300
```

Lab implements only:

```text
MIE  bit3
MPIE bit7
```

---

# 5. MIE

global machine interrupt enable

```text
MIE=0
```

blocks machine interrupts even if PLIC is asserting

---

# 6. MPIE

stores previous MIE during trap entry

used by:

```text
mret
```

---

# 7. CSR `mie`

address:

```text
0x304
```

Lab implements:

```text
MEIE bit11
```

Machine External Interrupt Enable

---

# 8. CSR `mip`

address:

```text
0x344
```

Lab implements:

```text
MEIP bit11
```

Machine External Interrupt Pending

---

# 9. MEIP Source

not a normal writable storage bit

Lab drives it from:

```text
cpu_ext_irq_i
```

therefore:

```text
PLIC output high
->
mip.MEIP = 1
```

---

# 10. MIP Write Policy

baseline:

```text
read-only
```

software write returns CSR error in standalone verification

---

# 11. CSR `mtvec`

address:

```text
0x305
```

holds trap-handler base

---

# 12. mtvec Mode

Lab supports:

```text
Direct only
```

low two bits forced:

```text
00
```

---

# 13. Why Direct Only

vectored mode adds:

```text
BASE + 4*cause
```

and changes verification matrix

direct mode is enough for first complete interrupt path

---

# 14. CSR `mepc`

address:

```text
0x341
```

holds resume PC

---

# 15. MEPC Alignment

low 2 bits forced:

```text
00
```

for RV32I baseline without compressed instructions

---

# 16. CSR `mcause`

address:

```text
0x342
```

external interrupt:

```text
bit31 = 1
cause = 11
```

---

# 17. MCAUSE Value

```text
0x8000000B
```

---

# 18. Interrupt Eligibility

all must be true:

```text
cpu_ext_irq_i
mie.MEIE
mstatus.MIE
not stalled
```

---

# 19. Layered Enable Chain

real system:

```text
Peripheral local enable
PLIC source enable
PLIC priority > threshold
mie.MEIE
mstatus.MIE
```

all layers matter

---

# 20. Precise Interrupt

asynchronous interrupt must be taken:

```text
between instructions
```

not halfway through a memory operation

---

# 21. Lab 14 Interaction

during SRAM wait:

```text
cpu_stall = 1
```

current instruction is not committed

therefore:

```text
trap_enter = 0
```

---

# 22. IRQ Can Remain Pending

while stalled:

```text
PLIC output may stay high
mip.MEIP = 1
```

but trap waits

---

# 23. After Stall Clears

next precise boundary:

```text
trap accepted
```

---

# 24. Why This Matters

if CPU traps in the middle of LW:

possible problems:

```text
load duplicated
load lost
incorrect mepc
RF partially updated
```

---

# 25. Trap Entry State Update

on external trap:

```text
mepc   <- normal_next_pc
mcause <- 0x8000000B
MPIE   <- MIE
MIE    <- 0
PC     <- mtvec
```

---

# 26. Why MEPC Uses `normal_next_pc`

Lab models asynchronous interrupt acceptance after current instruction commits

resume point is:

```text
next instruction
```

---

# 27. Contrast with Exception

synchronous exception often saves faulting PC

external interrupt here saves next PC after committed instruction boundary

---

# 28. No Nested IRQ by Default

trap entry:

```text
MIE <- 0
```

therefore another machine interrupt does not immediately nest

---

# 29. Software Can Re-enable

advanced ISR may set MIE intentionally

not part of baseline

---

# 30. MRET

encoding:

```text
0x30200073
```

---

# 31. MRET State

```text
PC <- mepc
MIE <- MPIE
MPIE <- 1
```

---

# 32. Why MPIE Becomes 1

matches standard machine-return bookkeeping semantics

---

# 33. CSR Instruction Support

decoder includes:

```text
CSRRW
CSRRS
CSRRC
CSRRWI
CSRRSI
CSRRCI
```

---

# 34. CSRRW

```text
rd <- old CSR
CSR <- rs1
```

---

# 35. CSRRS

```text
rd <- old CSR
CSR <- old | rs1
```

if:

```text
rs1=x0
```

then read-only access, no write

---

# 36. CSRRC

```text
rd <- old CSR
CSR <- old & ~rs1
```

---

# 37. Immediate CSR Forms

use:

```text
zimm = instr[19:15]
```

---

# 38. CSR Decoder File

```text
rtl/osoc_csr_decode.sv
```

---

# 39. CSR State File

```text
rtl/osoc_machine_csr.sv
```

---

# 40. Trap Controller

```text
rtl/osoc_trap_control.sv
```

---

# 41. Standalone Subsystem

```text
rtl/osoc_irq_csr_trap_subsystem.sv
```

combines CSR and trap logic

---

# 42. Architectural Shell

```text
rtl/osoc_irq_arch_shell.sv
```

provides tiny PC register for fully runnable verification independent of CPU repo

---

# 43. Why Two-Level Verification

Part A:

```text
CSR/trap semantics
```

Part B:

```text
CPU decoder/writeback/PC integration
```

if combined immediately, debug becomes difficult

---

# 44. Ready-to-Run Part

Part A runs with:

```bash
make all
```

without needing original CPU source

---

# 45. Integration Part

after standalone passes, apply:

```text
integration/osoc1_cpu_core_irq_patch.md
```

to Lab-14 core

---

# 46. Step 1 — Environment

```bash
make check-env
```

---

# 47. Step 2 — CSR Map

```bash
make check-map
```

validates:

```text
mstatus
mie
mtvec
mepc
mcause
mip
```

---

# 48. Step 3 — Contract

```bash
make check-contract
```

checks:

```text
CSR state
trap entry
stall rule
mret
CSR decoder
external cause
```

---

# 49. Step 4 — Firmware Header

```bash
make check-header
```

---

# 50. Step 5 — Lint

```bash
make lint
```

---

# 51. Step 6 — Simulation

```bash
make sim
```

---

# 52. Reset Test

expected:

```text
mstatus=0
mie=0
mtvec=0
mepc=0
mcause=0
mip=0
```

---

# 53. mtvec Alignment Test

write:

```text
0x00000103
```

expected readback:

```text
0x00000100
```

---

# 54. Enable MEIE

write/set:

```text
mie[11]=1
```

---

# 55. Enable Global MIE

write/set:

```text
mstatus[3]=1
```

---

# 56. Raise PLIC IRQ

test drives:

```text
cpu_ext_irq_i=1
```

---

# 57. MIP Test

expected:

```text
mip.MEIP=1
```

---

# 58. Trap Entry Test

with:

```text
MIE=1
MEIE=1
MEIP=1
stall=0
```

expected:

```text
trap_enter=1
```

---

# 59. PC Redirect

expected:

```text
PC = mtvec
```

---

# 60. MEPC Test

testbench computes:

```text
expected_mepc = pc_before_trap + 4
```

---

# 61. MCAUSE Test

expected:

```text
0x8000000B
```

---

# 62. MIE on Entry

expected:

```text
MIE -> 0
```

---

# 63. MPIE on Entry

old:

```text
MIE=1
```

therefore:

```text
MPIE=1
```

---

# 64. Clear External Source

represent software doing:

```text
claim PLIC
clear peripheral
complete PLIC
```

test lowers:

```text
cpu_ext_irq_i=0
```

---

# 65. MIP After Clear

expected:

```text
MEIP=0
```

---

# 66. MRET Test

assert:

```text
mret_request
```

---

# 67. MRET PC

expected:

```text
PC = mepc
```

---

# 68. MRET MIE

expected:

```text
MIE restored from MPIE
```

---

# 69. Global Disable Test

set:

```text
mstatus.MIE=0
```

raise external IRQ

expected:

```text
MEIP=1
but no trap
```

---

# 70. MEIE Disable Test

set:

```text
mie.MEIE=0
```

external IRQ still cannot cause trap

---

# 71. Stall Precision Test

set:

```text
stall=1
external IRQ=1
```

for several cycles

expected:

```text
trap_enter=0
PC stable
```

---

# 72. Release Stall

set:

```text
stall=0
```

external IRQ remains pending

expected:

```text
trap accepted immediately at safe boundary
```

---

# 73. Why This Is Key Test

this connects Lab 14 wait-state correctness with Lab 17 interrupt correctness

---

# 74. Write MIP Test

software attempts write:

```text
mip
```

expected:

```text
CSR error
```

---

# 75. Unknown CSR

address:

```text
0x999
```

expected:

```text
CSR error
```

---

# 76. Expected End

```text
PASS: Lab 17 CPU External Interrupt + CSR/Trap integration completed.
```

---

# 77. Check Simulation

```bash
make check-sim
```

---

# 78. Yosys

optional:

```bash
make yosys
```

---

# 79. Report

```bash
make report
```

---

# 80. One Command

```bash
make all
```

---

# 81. Reports

```text
reports/
├── 00_environment.log
├── 01_csr_map.txt
├── 02_rtl_contract.txt
├── 03_header.txt
├── 04_lint.log
├── 05_sim_build.log
├── 05_sim.log
├── 06_sim_check.txt
├── 07_yosys_probe.log
└── LAB17_REPORT.md
```

---

# 82. CPU Integration — New Input

Lab-14 CPU adds:

```systemverilog
input logic cpu_ext_irq_i;
```

---

# 83. CPU Integration — CSR Decode

decode SYSTEM opcode:

```text
0x73
```

---

# 84. CPU Integration — RF Read

CSR register form requires:

```text
rs1 value
```

already available from register file

---

# 85. CPU Integration — RF Writeback

CSR instruction writes old CSR value to `rd`

therefore writeback mux must gain:

```text
CSR
```

input

---

# 86. CSR Read with rd=x0

CSR operation still happens

RF write suppressed

---

# 87. CSRRS rs1=x0

means:

```text
read CSR
do not modify CSR
```

---

# 88. CSR Commit and Stall

CSR write must not occur while:

```text
stall_i=1
```

---

# 89. Trap and Stall

trap must not occur while:

```text
stall_i=1
```

---

# 90. MRET and Stall

MRET must also wait until:

```text
stall_i=0
```

---

# 91. PC Priority

recommended:

```text
reset
>
trap entry
>
mret
>
normal next pc
```

---

# 92. Why Trap Beats Normal Next PC

trap redirection is architectural control transfer

normal branch/JAL result becomes resume information only through MEPC policy

---

# 93. Trap vs MRET Same Cycle

should not normally coexist

Lab prioritizes external trap before MRET only when mret_request is not active

trap controller explicitly prevents external trap on same cycle as MRET request

---

# 94. Firmware Header

file:

```text
firmware/include/osoc_csr.h
```

---

# 95. Interrupt Initialization

```c
csr_disable_global_mie();

configure_plic();

csr_write_mtvec(
    (uint32_t)&machine_trap_entry
);

csr_enable_meie();
csr_enable_global_mie();
```

---

# 96. Trap Assembly

file:

```text
firmware/examples/trap_entry.S
```

saves:

```text
ra
t0-t2
a0-a3
```

then calls C handler

---

# 97. Production Handler

must save every register it modifies

provided assembly is training skeleton

---

# 98. C External IRQ Handler

file:

```text
firmware/examples/machine_external_irq.c
```

---

# 99. Handler Checks MCAUSE

expected:

```text
0x8000000B
```

---

# 100. Handler Claims PLIC

```text
id = PLIC_CLAIM
```

---

# 101. Timer Case

correct order:

```text
clear TIMER.STATUS
then PLIC complete
```

---

# 102. MRET

assembly ends:

```assembly
mret
```

---

# 103. Why `mret` Is Not `ret`

`ret` expands to:

```text
jalr x0,0(ra)
```

but trap return needs:

```text
mepc
mstatus restoration
```

so must use:

```text
mret
```

---

# 104. What Lab Does Not Implement

not yet:

```text
ecall
ebreak exception handling
illegal instruction trap
load/store access fault
instruction access fault
misaligned exception
timer interrupt via standard MTIP
software interrupt
S-mode/U-mode
delegation
PMP
```

---

# 105. Why Scope Is Limited

goal is first complete:

```text
PLIC external IRQ -> machine trap -> ISR -> mret
```

---

# 106. Bus Error Future

Lab 14 exposes CPU bus error

future exception integration should map it to:

```text
load access fault
store/AMO access fault
```

---

# 107. Synchronous Exceptions

differ from external interrupt

faulting instruction may not commit

MEPC usually points to faulting instruction

---

# 108. Precise Architecture Principle

interrupt:

```text
after instruction
```

exception:

```text
because of instruction
```

this distinction drives MEPC/commit behavior

---

# 109. mtvec Direct Handler

all traps enter same address

handler reads:

```text
mcause
```

to dispatch

---

# 110. Vectored Future

future:

```text
MODE=1
```

for interrupts

not implemented now

---

# 111. Nested Interrupt Future

baseline trap entry disables MIE

future ISR can intentionally re-enable after saving sufficient context

---

# 112. Risks of Nested Interrupts

```text
stack depth
priority inversion
reentrancy
context corruption
```

---

# 113. Why Start Non-Nested

far easier to verify and teach

---

# 114. CSR Timing

CSR state updates at:

```text
posedge
```

CSR read is combinational

---

# 115. Critical Timing Path

possible:

```text
CSR read
 -> RF writeback mux
 -> reg-file D
```

---

# 116. Another Critical Path

```text
PLIC irq
 -> CSR enable logic
 -> trap control
 -> PC next mux
```

---

# 117. External IRQ Is Same Clock Domain?

PLIC output is generated in system clock domain

so no new CDC in integrated O'SoC

---

# 118. If External Asynchronous IRQ Added Later

must synchronize before feeding CPU/PLIC gateway

---

# 119. Reset Policy

all interrupt enables reset:

```text
0
```

so CPU cannot unexpectedly trap during reset release

---

# 120. mtvec Reset

```text
0
```

software must configure before enabling interrupts

---

# 121. Safe Initialization Order

```text
1 disable global MIE
2 configure peripherals
3 clear stale peripheral pending
4 configure PLIC
5 configure mtvec
6 enable MEIE
7 enable global MIE
```

---

# 122. Why Clear Stale Pending

otherwise CPU may trap immediately after MIE is enabled

---

# 123. PLIC + CSR Debug Ladder

if interrupt not entering:

check:

```text
peripheral STATUS
peripheral local IRQ enable
PLIC pending
PLIC enable
PLIC threshold
cpu_ext_irq
mip.MEIP
mie.MEIE
mstatus.MIE
```

---

# 124. If cpu_ext_irq=1 but no trap

check:

```text
stall
MIE
MEIE
mret overlap
```

---

# 125. If trap loops immediately after MRET

likely:

```text
peripheral root cause not cleared
```

or PLIC source still pending/high

---

# 126. If wrong MEPC

review whether interrupt was taken before or after current instruction commit

---

# 127. If duplicate store before trap

likely violating Lab-14 precise stall/commit rule

---

# 128. Pass Criteria — CSR

```text
[ ] mstatus MIE/MPIE
[ ] mie MEIE
[ ] mip MEIP
[ ] mtvec alignment
[ ] mepc
[ ] mcause
```

---

# 129. Pass Criteria — Trap

```text
[ ] external IRQ enters when fully enabled
[ ] no trap if MIE=0
[ ] no trap if MEIE=0
[ ] no trap while stalled
[ ] pending IRQ enters after stall release
```

---

# 130. Pass Criteria — Entry State

```text
[ ] PC -> mtvec
[ ] mepc -> resume PC
[ ] mcause = 0x8000000B
[ ] MPIE <- old MIE
[ ] MIE <- 0
```

---

# 131. Pass Criteria — MRET

```text
[ ] PC -> mepc
[ ] MIE <- MPIE
[ ] MPIE <- 1
```

---

# 132. Pass Criteria — CSR Decode

```text
[ ] CSRRW
[ ] CSRRS
[ ] CSRRC
[ ] CSRRWI
[ ] CSRRSI
[ ] CSRRCI
[ ] MRET
```

---

# 133. Pass Criteria — Software Assets

```text
[ ] osoc_csr.h
[ ] interrupt_init.c
[ ] trap_entry.S
[ ] machine_external_irq.c
```

---

# 134. Freeze After Lab 17

freeze:

```text
mstatus.MIE bit3
mstatus.MPIE bit7

mie.MEIE bit11
mip.MEIP bit11

mtvec direct mode
mepc 4-byte aligned

machine external cause = 11
mcause = 0x8000000B

trap forbidden while stalled
mret = 0x30200073
```

---

# 135. Natural Next Step

after CPU integration passes:

```text
CPU + IMEM + SRAM + GPIO + Timer + PLIC + CSR/Trap
```

can execute a real periodic interrupt firmware

---

# 136. Recommended Lab 18

```text
Lab 18 — Full SoC Firmware Interrupt Demo
```

where CPU actually:

```text
initializes PLIC
initializes Timer
sets mtvec
enables MEIE/MIE
runs background loop
takes Timer ISR
toggles GPIO
returns with mret
```

---

# 137. Engineering Rule

> An interrupt is precise only when the CPU can identify a clean architectural
boundary at which all earlier instructions are committed and no later
instruction has committed.

and:

> `cpu_ext_irq` alone is not CPU interrupt support; complete support requires
CSR state, precise trap entry, handler dispatch, peripheral acknowledge, PLIC
complete, and `mret`.
