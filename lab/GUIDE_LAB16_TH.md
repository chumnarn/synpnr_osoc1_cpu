# Lab 16 — PLIC / Interrupt Controller
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 Single-Target PLIC-Lite

**Base:** `0x4000_3000`  
**Interrupt sources:** 8 IDs  
**Active sources:** GPIO=1, Timer=2, SPI=3  
**Priority width:** 3 bits  
**Targets:** 1 CPU context  
**Gateway:** level-sensitive  
**Arbitration:** highest priority, lower source ID wins tie  
**Interface:** O'SoC valid/ready/error

---

# 1. เป้าหมาย

Lab 13 สร้าง:

```text
GPIO irq
```

Lab 15 สร้าง:

```text
Timer irq
```

และ future SPI จะมี:

```text
SPI irq
```

CPU ไม่ควรรับสัญญาณเหล่านี้แบบ OR ตรง ๆ เพราะ software ต้องรู้:

```text
ใคร interrupt
ใครสำคัญกว่า
ใคร enable อยู่
source ไหนกำลัง service
```

ดังนั้นต้องมี:

```text
PLIC / Interrupt Controller
```

---

# 2. Architecture

```text
 GPIO IRQ ----+
              |
Timer IRQ ----+--> Gateway/Pending
              |         |
 SPI IRQ -----+         v
                    Priority
                       |
                    Enable
                       |
                       v
                    Arbiter
                       |
                   Threshold
                       |
                       v
                 CPU EXT IRQ
                       |
                       v
                 Claim/Complete
```

---

# 3. Why Not Just OR IRQs

แบบ:

```systemverilog
cpu_irq = gpio_irq | timer_irq | spi_irq;
```

บอก CPU ได้เพียง:

```text
somebody interrupted
```

แต่ไม่บอกว่า:

```text
source ID
priority
masking
service ownership
```

---

# 4. Source IDs

Lab freeze:

```text
ID0 NONE / reserved
ID1 GPIO
ID2 TIMER
ID3 SPI
ID4 UART future
ID5 DMA future
ID6 DEBUG future
ID7 USER future
```

---

# 5. Why ID0 Is Reserved

ตามแนว PLIC:

```text
claim = 0
```

means:

```text
no interrupt available
```

ดังนั้น source0ห้ามใช้เป็น interrupt จริง

---

# 6. Priority

แต่ละ source มี priority:

```text
0..7
```

3-bit

---

# 7. Priority 0

Lab policy:

```text
priority=0
```

means:

```text
never deliver
```

แม้:

```text
pending=1
enable=1
```

---

# 8. Enable

ENABLE เป็น bit mask

example:

```text
bit1 GPIO
bit2 Timer
bit3 SPI
```

---

# 9. Pending

PENDING แสดงว่า interrupt gateway ได้ latch source event แล้ว

---

# 10. Threshold

interrupt eligible เมื่อ:

```text
priority > threshold
```

not:

```text
priority >= threshold
```

---

# 11. Example Threshold

```text
threshold=3
```

จะ block:

```text
priority 0
1
2
3
```

และ allow:

```text
4
5
6
7
```

---

# 12. Arbitration

eligible sourcesหลายตัว:

```text
highest priority wins
```

---

# 13. Tie Break

ถ้า priorityเท่ากัน:

```text
lower source ID wins
```

ทำให้ deterministic

---

# 14. Claim

CPU/software reads:

```text
CLAIM
```

PLIC returns:

```text
highest-priority eligible source ID
```

---

# 15. Claim Side Effect

claim:

```text
pending[id] = 0
in_service[id] = 1
```

---

# 16. Complete

software writes:

```text
source ID
```

back to same CLAIM/COMPLETE register

PLIC:

```text
in_service[id] = 0
```

---

# 17. Correct Software Sequence

```text
claim
service peripheral
clear peripheral pending
complete
```

---

# 18. Why Peripheral Must Be Cleared Before Complete

Timer/GPIO IRQ sourceเป็น level-like:

```text
local_pending && local_irq_enable
```

ถ้า software complete PLIC ก่อน clear peripheral:

```text
source stays high
```

แล้ว PLICจะ:

```text
pend again
```

---

# 19. This Is Correct Behavior

re-pend prevents losing a still-active interrupt condition

---

# 20. Level-Sensitive Gateway

Lab uses:

```text
if irq_source high
and not in_service
    pending = 1
```

---

# 21. Why Not Edge-Detect Inside PLIC

current peripherals already latch their own event status

their IRQ outputs behave like levels

PLIC should preserve this contract

---

# 22. Register Map Overview

```text
0x40003000 + 4*ID    PRIORITY[ID]

0x40003100           PENDING
0x40003104           ENABLE
0x40003108           THRESHOLD
0x4000310C           CLAIM/COMPLETE
0x40003110           IN_SERVICE
0x40003114           ID
```

---

# 23. Priority Register 0

```text
offset 0x000
```

is hard-wired:

```text
0
```

write returns:

```text
error=1
```

---

# 24. GPIO Priority

```text
offset 0x004
```

---

# 25. Timer Priority

```text
offset 0x008
```

---

# 26. SPI Priority

```text
offset 0x00C
```

---

# 27. PENDING

offset:

```text
0x100
```

read-only bit vector

---

# 28. ENABLE

offset:

```text
0x104
```

RW bit vector

bit0 forced zero

---

# 29. THRESHOLD

offset:

```text
0x108
```

only low priority-width bits matter

---

# 30. CLAIM/COMPLETE

offset:

```text
0x10C
```

read:

```text
claim
```

write:

```text
complete
```

---

# 31. IN_SERVICE

offset:

```text
0x110
```

Lab debug register

not required for minimal software operation

แต่ usefulในการเรียน/ตรวจสอบ state

---

# 32. ID

offset:

```text
0x114
```

value:

```text
0x504C4943
```

ASCII:

```text
PLIC
```

---

# 33. Eligibility Equation

source `i` eligible iff:

```text
pending[i]
&&
enable[i]
&&
!in_service[i]
&&
priority[i] > threshold
```

---

# 34. Target IRQ

```text
cpu_ext_irq_o = any eligible source
```

---

# 35. Claim ID 0

ถ้าไม่มี eligible source:

```text
CLAIM read = 0
```

---

# 36. Single Target

Labใช้:

```text
one CPU context
```

ยังไม่มี:

```text
multiple harts
M-mode + S-mode contexts
```

---

# 37. Why PLIC-Lite

full standard PLIC can have:

```text
many sources
many targets
large sparse address map
per-context enables
multiple thresholds
```

ไม่จำเป็นสำหรับ O'SoC training baseline

---

# 38. Lab Goal

เราต้องเรียน:

```text
priority
pending
enable
threshold
claim
complete
```

ก่อน scale architecture

---

# 39. System Bus Integration

PLIC อยู่ใน Lab-11 map:

```text
0x40003000-0x40003FFF
```

---

# 40. Integration Top

file:

```text
rtl/osoc_bus_with_plic_top.sv
```

---

# 41. Interrupt Source Vector

```text
irq_sources[0]=0
irq_sources[1]=gpio_irq
irq_sources[2]=timer_irq
irq_sources[3]=spi_irq
irq_sources[7:4]=0
```

---

# 42. Step 1 — Environment

```bash
make check-env
```

---

# 43. Step 2 — Source Map

```bash
make check-sources
```

validates:

```text
ID uniqueness
range
source0 reserved
```

---

# 44. Step 3 — Register Map

```bash
make check-map
```

checks:

```text
alignment
duplicates
priority/register collision
4-KiB window
```

---

# 45. Step 4 — RTL Contract

```bash
make check-contract
```

checks presence of:

```text
priority
pending
enable
threshold
claim
complete
in-service
level gateway
source0 rule
```

---

# 46. Step 5 — Firmware Header

```bash
make check-header
```

---

# 47. Step 6 — Lint

```bash
make lint
```

---

# 48. Step 7 — Simulation

```bash
make sim
```

---

# 49. Test — ID

read:

```text
0x40003114
```

expected:

```text
0x504C4943
```

---

# 50. Reset State

expected:

```text
pending=0
enable=0
threshold=0
in_service=0
priority[*]=0
```

---

# 51. Source0 Test

read priority0:

```text
0
```

write priority0:

```text
error=1
```

---

# 52. Configure Priorities

Lab test:

```text
GPIO  priority=2
Timer priority=5
SPI   priority=3
```

---

# 53. Enable Sources

ENABLE:

```text
bits 1,2,3
```

hex:

```text
0x0000000E
```

---

# 54. Timer Interrupt Test

drive:

```text
timer_irq=1
```

then:

```text
pending[2]=1
cpu_ext_irq=1
```

---

# 55. Timer Claim

read:

```text
CLAIM
```

expected:

```text
2
```

---

# 56. Timer In-Service

after claim:

```text
pending[2]=0
in_service[2]=1
```

---

# 57. No Early Re-pend

timer sourceยัง high

แต่:

```text
in_service[2]=1
```

ดังนั้น PLICไม่ re-pendทันที

---

# 58. Clear Peripheral

testbench lowers:

```text
timer_irq=0
```

representing:

```text
software cleared TIMER.STATUS
```

---

# 59. Complete Timer

write:

```text
2
```

to CLAIM/COMPLETE

expected:

```text
in_service[2]=0
```

---

# 60. Empty Claim

no source:

```text
CLAIM=0
```

---

# 61. Simultaneous Interrupts

drive simultaneously:

```text
GPIO
Timer
SPI
```

---

# 62. Expected First Winner

priorities:

```text
Timer=5
SPI=3
GPIO=2
```

claim:

```text
2
```

---

# 63. Second Winner

after completing Timer:

```text
SPI
```

claim:

```text
3
```

---

# 64. Third Winner

then:

```text
GPIO
```

claim:

```text
1
```

---

# 65. This Proves Arbitration

not merely interrupt detection

---

# 66. Threshold Test

set:

```text
threshold=3
```

---

# 67. GPIO Priority2

blocked

---

# 68. SPI Priority3

also blocked

because rule is:

```text
priority > threshold
```

---

# 69. Timer Priority5

still eligible

---

# 70. Latched Pending Under Threshold

GPIO/SPI events can remain pending even when threshold blocks delivery

---

# 71. Lower Threshold

set:

```text
threshold=0
```

previous pending sources become eligible

---

# 72. Why This Matters

masking/delivery policy does not erase event state

---

# 73. Priority Zero Test

set:

```text
GPIO priority=0
```

drive GPIO IRQ

expected:

```text
pending=1
cpu_ext_irq=0
```

---

# 74. Restore Priority

set GPIO priority back to:

```text
2
```

latched pending becomes claimable

---

# 75. Tie Break Test

set:

```text
GPIO priority=4
SPI priority=4
```

both pending

---

# 76. Expected Tie Winner

lower ID:

```text
GPIO ID1
```

wins before:

```text
SPI ID3
```

---

# 77. Level Re-pend Test

Timer high

claim Timer

then complete Timer without lowering source

---

# 78. Expected

after complete:

```text
timer source remains high
```

next cycle:

```text
pending[2]=1 again
```

---

# 79. Why This Is Critical

software must clear peripheral condition

not merely PLIC state

---

# 80. Invalid Register

read:

```text
0x40003118
```

expected:

```text
error=1
```

---

# 81. Misaligned Register

read:

```text
0x40003102
```

expected:

```text
error=1
```

---

# 82. Write to ID

expected:

```text
error=1
```

---

# 83. Write to PENDING

expected:

```text
error=1
```

---

# 84. Expected End

```text
PASS: Lab 16 PLIC / Interrupt Controller integration completed.
```

---

# 85. Check Simulation

```bash
make check-sim
```

---

# 86. Optional Yosys

```bash
make yosys
```

---

# 87. Report

```bash
make report
```

output:

```text
reports/LAB16_REPORT.md
```

---

# 88. One Command

```bash
make all
```

---

# 89. Firmware Header

file:

```text
firmware/include/osoc_plic.h
```

---

# 90. PLIC Init

example:

```c
OSOC_PLIC_ENABLE = 0;
OSOC_PLIC_THRESHOLD = 0;

osoc_plic_set_priority(OSOC_IRQ_GPIO,2);
osoc_plic_set_priority(OSOC_IRQ_TIMER,5);
osoc_plic_set_priority(OSOC_IRQ_SPI,3);

osoc_plic_enable(OSOC_IRQ_GPIO);
osoc_plic_enable(OSOC_IRQ_TIMER);
osoc_plic_enable(OSOC_IRQ_SPI);
```

---

# 91. ISR Skeleton

future CPU handler:

```c
uint32_t id = osoc_plic_claim();

switch(id) {
case OSOC_IRQ_GPIO:
    gpio_service();
    break;

case OSOC_IRQ_TIMER:
    timer_service();
    break;

case OSOC_IRQ_SPI:
    spi_service();
    break;
}

osoc_plic_complete(id);
```

---

# 92. Critical Ordering

inside source handler:

```text
clear peripheral
before
PLIC complete
```

for level-sensitive sources

---

# 93. Timer Example

correct:

```text
claim Timer
clear TIMER.STATUS
complete Timer
```

---

# 94. Wrong Timer Sequence

```text
claim
complete
clear TIMER.STATUS
```

can produce immediate re-pend

---

# 95. GPIO Example

same principle:

```text
claim GPIO
read GPIO IRQ_STATUS
clear W1C event
complete GPIO
```

---

# 96. SPI Example

clear underlying SPI cause:

```text
RX pending
TX pending
error pending
```

before complete

---

# 97. CPU External IRQ

PLIC output:

```text
cpu_ext_irq_o
```

---

# 98. Lab Does Not Directly Modify CPU

CPU trap architecture remains next stage

---

# 99. Required CPU Features Next

```text
external irq input
mstatus.MIE
mie.MEIE
mip.MEIP
mtvec
mepc
mcause
trap PC redirection
mret
```

---

# 100. Precise Interrupt Rule

CPU should take interrupt:

```text
between committed instructions
```

---

# 101. Interaction with Wait State

if CPU from Lab 14 is stalled on SRAM:

```text
current instruction not committed
```

PLIC IRQ may assert

CPU trap controller should wait for safe architectural boundary

---

# 102. Why Pending Latches Matter

PLIC/peripheral holds interrupt until CPU can service it

---

# 103. Priority Width

3 bits:

```text
0..7
```

---

# 104. Scaling Priority

future can change:

```text
PRIORITY_WIDTH
```

but software-visible mask must remain consistent

---

# 105. Scaling Sources

module parameter:

```text
NUM_SOURCES
```

baseline 8

---

# 106. Current RTL Assumption

the implementation is optimized for:

```text
NUM_SOURCES <= 32
```

because ENABLE/PENDING are one 32-bit register

---

# 107. More Than 32 Sources

requires multiple words:

```text
PENDING0
PENDING1
ENABLE0
ENABLE1
```

and new software layout

---

# 108. Multi-Hart Expansion

requires:

```text
enable per context
threshold per context
claim/complete per context
target IRQ per context
```

---

# 109. Why Not Add It Now

would obscure core concept and increase verification matrix

---

# 110. PLIC vs CLINT

PLIC handles:

```text
external interrupt sources
```

not necessarily:

```text
machine timer interrupt
software interrupt
```

---

# 111. O'SoC Teaching Choice

Lab routes Timer peripheral through PLIC for unified interrupt-controller
training

a future RISC-V-compliant architecture may instead implement CLINT/ACLINT-style
timer/software interrupts depending platform requirements

---

# 112. Why Mention This

do not confuse:

```text
our SoC teaching map
```

with:

```text
mandatory universal RISC-V platform architecture
```

---

# 113. Claim Is a Side-Effecting Read

ordinary debug tools that read all registers can accidentally claim interrupt

document this carefully

---

# 114. In-Service Debug Register

Lab exposes:

```text
IN_SERVICE
```

to make claim/complete state visible

---

# 115. Production Choice

production PLIC could omit this software-visible debug register

---

# 116. Bus Timing

PLIC register access:

```text
same-cycle ready
```

write/claim state update occurs on clock edge

---

# 117. CPU Adapter Compatibility

Lab 14 adapter automatically handles PLIC

same-cycle ready means no added wait cycle

---

# 118. Critical Timing Path

possible:

```text
pending/enable/priority
 -> arbitration loop
 -> claim ID
 -> target_irq
```

---

# 119. Scaling Concern

linear arbitration loop becomes longer as NUM_SOURCES grows

---

# 120. Future Optimization

large PLIC can use:

```text
priority tree
hierarchical arbitration
registered stages
```

---

# 121. 8-Source Baseline

linear comparator loop is appropriate

---

# 122. Area

main structures:

```text
8 priority registers
8 pending bits
8 enable bits
8 in-service bits
threshold register
priority comparators
encoder/mux
```

small compared with CPU/SRAM

---

# 123. Interrupt Storm

if source remains permanently high and software completes repeatedly:

```text
PLIC will repeatedly deliver it
```

this is correct signal behavior

---

# 124. Software Must Fix Root Cause

interrupt handler must clear or mask failing peripheral

---

# 125. Starvation

high-priority source that continually re-pends can starve lower priorities

---

# 126. Mitigation

software/system policy:

```text
clear cause
rate limit
adjust priority
temporarily mask
```

---

# 127. Priority Inversion

PLIC priority determines interrupt service order, not task scheduler priority

software design still matters

---

# 128. Safety/Critical Systems

interrupt priorities should be reviewed against:

```text
deadline
latency budget
fault response
actuator safety
```

---

# 129. Pass Criteria — Source Mapping

```text
[ ] ID0 reserved
[ ] GPIO=1
[ ] Timer=2
[ ] SPI=3
```

---

# 130. Pass Criteria — Priority

```text
[ ] priorities writable
[ ] priority0 source never delivered
[ ] highest priority wins
[ ] tie lower ID wins
```

---

# 131. Pass Criteria — Enable

```text
[ ] disabled source not delivered
[ ] enable bit works independently
```

---

# 132. Pass Criteria — Threshold

```text
[ ] priority <= threshold blocked
[ ] priority > threshold delivered
[ ] pending retained while blocked
```

---

# 133. Pass Criteria — Claim

```text
[ ] correct ID returned
[ ] pending clears on claim
[ ] in-service sets
```

---

# 134. Pass Criteria — Complete

```text
[ ] valid in-service ID completes
[ ] in-service clears
[ ] still-active level source re-pends
```

---

# 135. Pass Criteria — Error Handling

```text
[ ] source0 priority write errors
[ ] invalid register errors
[ ] misaligned access errors
[ ] PENDING write errors
[ ] ID write errors
```

---

# 136. Reports

```text
reports/
├── 00_environment.log
├── 01_source_map.txt
├── 02_register_map.txt
├── 03_rtl_contract.txt
├── 04_header.txt
├── 05_lint.log
├── 06_sim_build.log
├── 06_sim.log
├── 07_sim_check.txt
├── 08_yosys_probe.log
└── LAB16_REPORT.md
```

---

# 137. Recommended Sequence

```bash
make clean
make check-env
make check-sources
make check-map
make check-contract
make check-header
make lint
make sim
make check-sim
make yosys
make report
```

---

# 138. Freeze After Lab 16

freeze:

```text
PLIC base = 0x40003000

ID1 GPIO
ID2 TIMER
ID3 SPI

priority width = 3
source0 reserved
priority0 disables delivery

enable bitmask semantics
threshold semantics

claim read side effect
complete write semantics
level-sensitive re-pend
lower-ID tie break
```

---

# 139. Next Lab

recommended:

```text
Lab 17 — CPU External Interrupt + CSR/Trap Integration
```

architecture:

```text
GPIO ----+
Timer ---+--> PLIC --> cpu_ext_irq
SPI -----+               |
                         v
                    CPU CSR/Trap
                         |
                         v
                       mtvec
                         |
                         v
                        ISR
```

---

# 140. Engineering Rule

> PLIC does not clear the peripheral's root interrupt condition.

It only arbitrates and tracks delivery.

and:

> Claim/complete correctness depends on a clear ownership sequence: claim the
source, service and clear the peripheral, then complete the source.
