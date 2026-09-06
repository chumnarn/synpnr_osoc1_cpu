# Lab 19 — Full SoC Boot from SPI Flash
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 End-to-End System Integration

**Reset vector:** `0x0000_0000`  
**Boot ROM:** `0x0000_0000-0x0000_0FFF`  
**XIP Flash:** `0x1000_0000-0x10FF_FFFF`  
**SRAM:** `0x2000_0000`  
**GPIO:** `0x4000_0000`  
**Timer:** `0x4000_1000`  
**SPI/XIP MMIO:** `0x4000_2000`  
**PLIC:** `0x4000_3000`  
**Timer interrupt source:** ID 2  
**Clock baseline:** 50 MHz

---

# 1. เป้าหมายของ Lab 19

Lab ก่อนหน้าแยกพิสูจน์ทีละ subsystem:

```text
Lab 12 SRAM + IMEM
Lab 13 GPIO
Lab 14 CPU wait-state
Lab 15 Timer
Lab 16 PLIC
Lab 17 CSR/Trap
Lab 18 SPI Flash/XIP
```

Lab 19 มีเป้าหมายต่างออกไป:

```text
System Integration
```

คือพิสูจน์ว่า subsystem เหล่านี้สามารถทำงานเป็น flow เดียวกัน

---

# 2. Integration Scenario

```text
Reset
  |
Internal Boot ROM
  |
configure SPI/XIP
  |
jump XIP
  |
SPI Flash instruction fetch
  |
run firmware
  |
configure Timer/PLIC
  |
Timer IRQ
  |
PLIC
  |
CPU trap/ISR
  |
GPIO toggle
  |
mret
  |
resume XIP
```

---

# 3. Why This Lab Is Important

peripheralแต่ละตัว simulationผ่านไม่ได้แปลว่า SoCทำงาน

integration bugs มักเกิดที่:

```text
address map
handshake
stall combination
interrupt ownership
boot memory mapping
endianness
initialization order
CSR enable order
```

---

# 4. Verification Strategy

Lab 19 intentionally uses two levels

---

# 5. Level A — Standalone Integration

runs with Lab files only

uses:

```text
osoc19_boot_sequencer
```

แทน CPU

---

# 6. What Level A Proves

```text
Boot ROM mapping
SPI register writes
XIP serial traffic
XIP ready/wait behavior
Timer generation
PLIC claim/complete
Timer clear sequence
GPIO write
```

---

# 7. What Level A Does Not Prove

ไม่พิสูจน์:

```text
actual RV32 instruction execution
actual RF contents
actual CSR instruction decode
actual mret execution
actual stack/data ABI behavior
```

---

# 8. Level B — Real CPU

uses:

```text
osoc1_cpu_core_wait
+
Lab 17 CSR/Trap integration
```

---

# 9. Why Split A and B

if full CPU test fails immediately, debug spaceใหญ่มาก

แบ่งเป็น:

```text
fabric verified
then CPU integration
```

ช่วย localize problem

---

# 10. Full Architecture

```text
                        +------------------+
Reset ---------------->|   RISC-V CPU     |
                        +---+----------+---+
                            |          |
                           IF         D-Bus
                            |          |
             +--------------+          +----------------+
             |                                          |
             v                                          v
      +--------------+                         +----------------+
      | Boot ROM     |                         | System MMIO    |
      | 0x00000000   |                         +----------------+
      +--------------+                           |   |   |   |
             |                                    |   |   |   |
             |                                GPIO Timer SPI PLIC
             |
             +--------> XIP Window
                         |
                         v
                   SPI Controller
                         |
                         v
                    SPI NOR Flash
```

---

# 11. Memory Map

```text
0x00000000  Boot ROM
0x10000000  XIP Flash
0x20000000  SRAM
0x40000000  GPIO
0x40001000  Timer
0x40002000  SPI
0x40003000  PLIC
```

---

# 12. Address Map Freeze

Lab 19 should be the point where these addresses stop changing casually

because software linker/header now depends on them

---

# 13. Boot Principle

reset must not depend immediately on slow external Flash

baseline:

```text
reset PC = 0
```

---

# 14. Internal Boot ROM

small deterministic ROM can:

```text
initialize SRAM
configure SPI
verify Flash
enable XIP
jump
```

---

# 15. Why Not Reset Directly Into XIP

possible in some systems

but then reset path depends on:

```text
SPI controller initialization
external Flash
board/package
instruction wait-state
```

all at once

---

# 16. Boot ROM Improves Bring-Up

if Flash unavailable:

```text
CPU still executes diagnostic code
```

---

# 17. Lab 19 Boot ROM File

```text
firmware/bootrom/bootrom.hex
```

---

# 18. Boot ROM RTL

```text
rtl/osoc19_bootrom.sv
```

---

# 19. Boot ROM Default Fill

unused words:

```text
0x00000013
```

RV32I NOP

---

# 20. XIP Window

same as Lab 18:

```text
0x10000000-0x10FFFFFF
```

---

# 21. XIP Physical Protocol

```text
SPI Mode0
0x03 READ
24-bit address
4 data bytes
```

---

# 22. XIP Miss

requires serial transaction

therefore:

```text
ready=0
```

for many system clocks

---

# 23. CPU Rule

real CPU:

```text
imem_stall = valid && !ready
```

---

# 24. Data Stall

from Lab 14:

```text
dmem_stall
```

---

# 25. Combined Stall

must be:

```systemverilog
cpu_stall =
    dmem_stall |
    imem_stall;
```

---

# 26. Freeze on Stall

must freeze:

```text
PC
RF commit
CSR commit
trap entry
MRET
```

---

# 27. Why Interrupt Also Waits

if XIP instruction only half-fetched:

```text
no precise instruction boundary
```

external interrupt waits until fetch completes

---

# 28. Lab-17 Rule Survives

```text
trap_enter only when !cpu_stall
```

---

# 29. XIP Cache

Lab keeps one-word cache

this is intentionally small

---

# 30. First XIP Fetch

```text
0x10000000
```

must miss

---

# 31. Serial Cost

baseline transaction transfers:

```text
8 command bits
24 address bits
32 data bits
```

minimum 64 serial bits

---

# 32. Boot Performance

a one-word cache makes functional proof possible

but production performance needs:

```text
line buffer
prefetch
instruction cache
```

---

# 33. Why Lab 19 Does Not Optimize Yet

first prove correctness

then optimize XIP

---

# 34. MMIO Fabric

Level-A fabric implements minimal real paths for:

```text
GPIO
Timer
SPI
PLIC
```

---

# 35. GPIO Base

```text
0x40000000
```

---

# 36. Timer Base

```text
0x40001000
```

---

# 37. SPI Base

```text
0x40002000
```

---

# 38. PLIC Base

```text
0x40003000
```

---

# 39. Timer Interrupt ID

```text
2
```

---

# 40. PLIC Policy

same freeze:

```text
GPIO=1
Timer=2
SPI=3
```

---

# 41. Timer Priority

standalone flow uses:

```text
Timer priority=5
```

---

# 42. PLIC Enable

bits:

```text
1,2,3 enabled
```

---

# 43. PLIC Threshold

```text
0
```

---

# 44. End-to-End Interrupt

```text
Timer pending
 -> timer_irq
 -> PLIC pending[2]
 -> PLIC target irq
```

---

# 45. Claim

software/master reads:

```text
0x4000310C
```

expected:

```text
2
```

---

# 46. Peripheral Clear

then write:

```text
Timer STATUS W1C
```

---

# 47. GPIO Service Action

toggle:

```text
GPIO bit0
```

---

# 48. Complete

write:

```text
2
```

back to PLIC claim/complete register

---

# 49. Why This Order Matters

level-sensitive Timer IRQ remains high until its own status clears

so:

```text
clear peripheral before complete
```

---

# 50. Level-A Boot Sequencer

file:

```text
rtl/osoc19_boot_sequencer.sv
```

---

# 51. Why It Is Not Called a CPU

it does not decode RV32 instructions

it performs deterministic integration transactions

---

# 52. Why Include It

allows:

```bash
make all
```

without depending on repo revision

---

# 53. Boot Sequencer States

```text
BOOT0
BOOT1
SPI_DIV
SPI_EN
XIP0
XIP1
TIMER_CMP
TIMER_PRE
TIMER_EN
WAIT_IRQ
PLIC_CLAIM
TIMER_CLEAR
GPIO_READ
GPIO_WRITE
PLIC_COMPLETE
DONE
```

---

# 54. BOOT0

fetch:

```text
0x00000000
```

---

# 55. BOOT1

fetch:

```text
0x00000004
```

---

# 56. SPI_DIV

write divider

---

# 57. SPI_EN

enable XIP

---

# 58. XIP0

fetch:

```text
0x10000000
```

---

# 59. Expected XIP0

```text
0x200000B7
```

---

# 60. XIP1

fetch:

```text
0x10000004
```

---

# 61. Expected XIP1

```text
0x01200113
```

---

# 62. Why Two Words

proves:

```text
flash address increment
second miss
little-endian assembly
```

---

# 63. Timer Configuration

compare:

```text
3
```

prescale:

```text
0
```

for fast simulation

---

# 64. Why Simulation Values Differ From Firmware

simulation wants short runtime

real firmware example uses millisecond divider

---

# 65. Real Timer Example

50 MHz:

```text
PRESCALE=49999
COMPARE=999
```

approximately 1-second periodic event

---

# 66. Wait IRQ

sequencer waits for:

```text
cpu_ext_irq
```

---

# 67. PLIC Claim

claim must return:

```text
2
```

---

# 68. Clear Timer First

W1C:

```text
Timer STATUS=1
```

---

# 69. Toggle GPIO

read old GPIO

then:

```text
GPIO ^= 1
```

---

# 70. Complete PLIC

write ID2

---

# 71. Done

all stages must complete

---

# 72. Self-Checking Testbench

file:

```text
tb/tb_lab19_full_soc.sv
```

---

# 73. Testbench Flash Model

file:

```text
tb/spi_flash_model.sv
```

---

# 74. Flash Contents

first words:

```text
0x200000B7
0x01200113
0x0020A023
0x0000A183
```

---

# 75. XIP Endianness

stored byte order follows little-endian RV32 word layout

---

# 76. Expected Level-A Final

```text
bootrom_seen = 1
jumped_to_xip = 1
xip_word0_seen = 1
xip_word1_seen = 1
interrupt_seen = 1
gpio_toggled = 1
done = 1
failed = 0
```

---

# 77. GPIO Final

bit0:

```text
1
```

---

# 78. XIP Miss Count

at least:

```text
2
```

---

# 79. Expected Signature

```text
PASS: Lab 19 Full SoC Boot from SPI Flash completed.
```

---

# 80. Directory Structure

```text
lab19_full_soc_boot_spi_flash/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB19_TH.md
├── rtl/
├── tb/
├── config/
├── firmware/
├── integration/
├── docs/
├── scripts/
├── reports/
└── build/
```

---

# 81. Step 1 — Environment

```bash
make check-env
```

required:

```text
python3
verilator
```

---

# 82. Step 2 — File Manifest

```bash
make check-manifest
```

ensures package is complete

---

# 83. Step 3 — Contract Check

```bash
make check-contract
```

checks:

```text
memory map
XIP path
Timer wiring
PLIC claim
clear-before-complete
GPIO toggle
```

---

# 84. Step 4 — Lint

```bash
make lint
```

---

# 85. Step 5 — Simulation

```bash
make sim
```

---

# 86. Step 6 — Parse Simulation

```bash
make check-sim
```

---

# 87. Step 7 — Yosys

optional:

```bash
make yosys
```

---

# 88. Step 8 — Report

```bash
make report
```

---

# 89. One Command

```bash
make all
```

---

# 90. Reports

```text
reports/
├── 00_environment.log
├── 01_manifest.txt
├── 02_contract.txt
├── 03_lint.log
├── 04_sim_build.log
├── 04_sim.log
├── 05_sim_check.txt
├── 06_yosys.log
└── LAB19_REPORT.md
```

---

# 91. Level-B CPU Preflight

with actual repo:

```bash
make \
  REPO_ROOT=/path/to/synpnr_osoc1_cpu \
  check-repo
```

---

# 92. Expected Repository Files

checks original:

```text
cpu_sv_package
decoder
ctrl
ALU
SAU
LAU
reg_file
branch/PC logic
osoc1_cpu_core
```

---

# 93. Real CPU Integration Guide

```text
integration/FULL_CPU_INTEGRATION.md
```

---

# 94. CPU Reset

preserve:

```text
PC=0x00000000
```

---

# 95. CPU Instruction Adapter

PC addresses:

```text
0x00000000 region -> Boot ROM
0x10000000 region -> XIP
```

---

# 96. Instruction Stall

XIP miss:

```text
imem_stall=1
```

---

# 97. Data Stall

SRAM wait:

```text
dmem_stall=1
```

---

# 98. CPU Stall

```text
imem_stall | dmem_stall
```

---

# 99. CSR/Trap Stall Rule

during either stall:

```text
trap=0
mret=0
CSR write=0
```

---

# 100. Real Boot Software Tasks

```text
initialize stack
disable interrupt
configure SPI
verify Flash
initialize RAM data
configure mtvec
configure PLIC
configure Timer
enable interrupts
jump XIP
```

---

# 101. `.data`

initialized variables reside in SRAM

but initial bytes live in Flash image

boot code must copy them

---

# 102. `.bss`

must be zeroed in SRAM

---

# 103. Stack

should point into SRAM

not XIP

---

# 104. Why Writable Data Cannot Stay in XIP

external Flash baseline is read-only in this Lab

---

# 105. XIP Linker

provided under:

```text
firmware/xip/linker.ld
```

---

# 106. XIP Text

```text
.text
.rodata
```

in XIP

---

# 107. RAM Data

```text
.data
.bss
stack
```

in SRAM

---

# 108. Firmware Main

provided:

```text
firmware/xip/main.c
```

---

# 109. Main Configures Timer

and PLIC

---

# 110. ISR Concept

Timer ISR:

```text
claim
clear Timer
toggle GPIO
complete
```

---

# 111. Full CPU Needs Lab 17

CSR support:

```text
mstatus
mie
mip
mtvec
mepc
mcause
mret
```

---

# 112. MCAUSE

external interrupt:

```text
0x8000000B
```

---

# 113. MEPC

for asynchronous interrupt:

```text
resume PC
```

---

# 114. MRET

returns to XIP firmware

---

# 115. Critical Full-CPU Proof

must observe:

```text
ROM PC
then XIP PC
then ISR mtvec PC
then return XIP PC
```

---

# 116. Recommended Wave Signals

```text
clk
reset
PC
instr
imem_stall
dmem_stall
cpu_stall
spi_cs
spi_sck
spi_mosi
spi_miso
timer_irq
plic_pending
cpu_ext_irq
trap_enter
mtvec
mepc
mcause
gpio
```

---

# 117. Debug — Never Leaves ROM

check:

```text
boot code
SPI MMIO write
jump target
```

---

# 118. Debug — XIP Stalls Forever

check:

```text
CS#
SCK
MOSI command
MISO response
ready FSM
divider
```

---

# 119. Debug — Wrong Instruction Word

check:

```text
24-bit address
byte order
little endian
MISO sampling edge
```

---

# 120. Debug — Timer IRQ Missing

check:

```text
Timer ENABLE
IRQ_EN
COUNT
COMPARE
STATUS
```

---

# 121. Debug — PLIC IRQ Missing

check:

```text
pending[2]
enable[2]
priority[2]
threshold
```

---

# 122. Debug — PLIC Claim Wrong

check simultaneous sources and priority

Timer ID must be:

```text
2
```

---

# 123. Debug — IRQ Repeats Forever

likely:

```text
Timer root cause not cleared before complete
```

---

# 124. Debug — CPU Traps During XIP Miss

bug

check:

```text
cpu_stall
trap_enter
```

trap must wait

---

# 125. Debug — MRET Returns Wrong

check:

```text
mepc save boundary
normal_next_pc
```

---

# 126. Debug — GPIO Not Toggle

check:

```text
ISR dispatch ID
GPIO DATA address
store path
```

---

# 127. Level-A Pass Criteria

```text
[ ] Boot ROM observed
[ ] SPI configured
[ ] XIP entered
[ ] 2 XIP words verified
[ ] serial miss behavior
[ ] Timer interrupt occurs
[ ] PLIC claim=2
[ ] Timer cleared before complete
[ ] GPIO toggled
[ ] PLIC completed
[ ] final PASS
```

---

# 128. Level-B Pass Criteria

```text
[ ] real RV32 core compiled
[ ] reset PC=0
[ ] actual boot ROM instructions execute
[ ] actual JAL/JALR moves PC to XIP
[ ] XIP stalls core
[ ] actual RV32 words execute
[ ] SRAM stack/data operate
[ ] Timer->PLIC->CPU trap operates
[ ] mtvec handler executes
[ ] GPIO store comes from ISR
[ ] mret resumes XIP program
```

---

# 129. Why Level A Is Still Valuable

it proves the fabric independently

this is not fake CPU verification

it is:

```text
integration isolation
```

---

# 130. Why Level B Is Mandatory Before Calling SoC CPU Complete

because only CPU can prove:

```text
ISA execution
architectural state
trap/mret semantics
```

---

# 131. Physical Design Impact

Lab 19 adds real top-level blocks:

```text
CPU core
SRAM macro
SPI controller
GPIO
Timer
PLIC
CSR logic
```

---

# 132. SPI Pad Requirement

```text
SPI_CS_N output
SPI_SCK  output
SPI_MOSI output
SPI_MISO input
```

---

# 133. GPIO Pads

map GPIO outputs/inputs via IHP IO cells

---

# 134. Clock

system:

```text
50 MHz baseline
```

---

# 135. SCK Is Output, Not Internal Clock Domain

keep SPI FSM synchronous to system clock

---

# 136. Physical SRAM

still use IHP hard macro

never behavioral model in physical synthesis

---

# 137. XIP Flash Is External

no Flash GDS macro inside chip

only controller and pads are on die

---

# 138. STA

must constrain:

```text
system clock
SPI output timing
MISO input timing
```

using actual selected Flash datasheet eventually

---

# 139. Production Flash Frequency

do not assume Lab divider is safe for chosen device

---

# 140. Package/Board

SPI traces need package/PCB review

---

# 141. Boot Reliability Future

add:

```text
Flash ID
image header
CRC
fallback
timeout
```

---

# 142. Secure Boot Future

add:

```text
signature verification
anti-rollback
key storage
```

---

# 143. XIP Performance Future

add:

```text
line cache
prefetch
fast-read
quad SPI
```

---

# 144. Interrupt Performance Future

measure:

```text
Timer event -> trap latency
ISR cycles
mret latency
```

---

# 145. SoC Bring-Up Milestone

after Level-B pass, O'SoC has:

```text
external code storage
internal SRAM
memory-mapped peripherals
timer interrupt
interrupt controller
machine trap
GPIO observable output
```

---

# 146. Freeze After Lab 19

freeze:

```text
reset vector 0x00000000
XIP entry 0x10000000
SRAM 0x20000000
GPIO 0x40000000
Timer 0x40001000
SPI 0x40002000
PLIC 0x40003000

Timer IRQ ID2

cpu_stall =
    dmem_stall |
    imem_stall
```

---

# 147. Recommended Next Step

next system milestone:

```text
Lab 20 — O'SoC 1.0 Full-Chip RTL-to-GDSII
```

including:

```text
CPU
IHP SRAM hard macro
pad ring
SPI pads
GPIO pads
PDN
placement
CTS
routing
signoff
```

---

# 148. Engineering Rule

> Boot is not proven merely because Flash data can be read.

Boot is proven when the processor can move from reset memory into the external
execution region under the real instruction-latency contract.

and:

> Full-SoC interrupt integration is not proven merely because an IRQ toggles.

It is proven only when the source is identified, the peripheral condition is
cleared, the controller is completed, architectural state is preserved, and
execution returns correctly.
