# Lab 15 — Timer + Interrupt
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 Memory-Mapped Timer and Interrupt Source

**Base address:** `0x4000_1000`  
**Clock baseline:** 50 MHz  
**Modes:** one-shot / periodic  
**Counter:** 32-bit  
**Prescaler:** 32-bit programmable  
**Interrupt:** latched pending + IRQ enable + W1C clear  
**Next stage:** PLIC / CPU trap integration

---

# 1. เป้าหมาย

Lab 15 เพิ่ม hardware timer ที่ CPU/software สามารถใช้สำหรับ:

```text
periodic scheduler tick
timeouts
software delays
watchdog building block
sampling interval
control-loop timing
industrial periodic task
```

และสร้าง interrupt source:

```text
timer_irq_o
```

สำหรับต่อ PLIC ใน Lab ถัดไป

---

# 2. สิ่งที่ Lab นี้พิสูจน์

```text
bus register access
counter operation
prescaler
compare event
one-shot mode
periodic mode
interrupt pending
interrupt enable
W1C clear
firmware register contract
```

---

# 3. สิ่งที่ Lab นี้ยังไม่พิสูจน์

ยังไม่ claim:

```text
CPU trap entry
mcause
mepc
mtvec
mstatus
mie/mip
mret
PLIC priority/claim/complete
```

ดังนั้นคำว่า interrupt ใน Lab นี้หมายถึง:

```text
peripheral interrupt source generation
```

---

# 4. Architecture

```text
O'SoC System Bus
       |
       v
+------------------+
|    osoc_timer    |
|                  |
| CONTROL          |
| COUNT            |
| COMPARE          |
| PRESCALE         |
| STATUS           |
+--------+---------+
         |
         v
   irq_pending
         |
      IRQ_EN
         |
         v
      timer_irq
         |
         v
    future PLIC
```

---

# 5. Address

```text
0x4000_1000 - 0x4000_1FFF
```

---

# 6. Register Map

```text
0x00 CONTROL
0x04 COUNT
0x08 COMPARE
0x0C PRESCALE
0x10 STATUS
0x14 ID
```

---

# 7. CONTROL

bits:

```text
bit0 ENABLE
bit1 PERIODIC
bit2 IRQ_EN
```

---

# 8. ENABLE

```text
0 = counter stopped
1 = counter active
```

---

# 9. PERIODIC

```text
0 = one-shot
1 = periodic
```

---

# 10. IRQ_EN

```text
0 = pending may exist but irq_o is low
1 = pending drives irq_o high
```

---

# 11. COUNT

current timer count

software can read/write it

---

# 12. COMPARE

terminal value used to generate timer event

---

# 13. PRESCALE

timer tick every:

```text
PRESCALE + 1
```

system clocks

---

# 14. Example at 50 MHz

system clock:

```text
20 ns
```

if:

```text
PRESCALE = 49,999
```

then:

```text
50,000 clocks
×
20 ns
=
1 ms
```

---

# 15. 1-Second Period Example

with 1-ms tick:

```text
COMPARE = 999
```

approximately one event per second in this baseline counting convention

---

# 16. STATUS

bit0:

```text
IRQ_PENDING
```

---

# 17. W1C

STATUS is:

```text
Read / Write-1-to-Clear
```

software clears:

```c
TIMER_STATUS = 1;
```

---

# 18. Why Pending Is Latched

interrupt pulse may otherwise be missed

latched status remains until software acknowledges it

---

# 19. ID

```text
0x54494D45
```

ASCII:

```text
TIME
```

---

# 20. One-Shot Mode

configuration:

```text
ENABLE=1
PERIODIC=0
IRQ_EN=1
```

at compare:

```text
pending=1
enable=0
```

timer stops automatically

---

# 21. Periodic Mode

configuration:

```text
ENABLE=1
PERIODIC=1
IRQ_EN=1
```

at compare:

```text
pending=1
count=0
enable remains 1
```

next period begins automatically

---

# 22. Prescaler Counter

internal:

```text
prescale_count
```

increments every system clock while enabled

---

# 23. Tick Condition

```text
prescale_count >= prescale
```

---

# 24. Why `>=` Instead of `==`

software may change PRESCALE dynamically

using `>=` prevents a stale internal count from getting stuck above a newly
smaller prescale value

---

# 25. Compare Event

on timer tick:

```text
count >= compare
```

triggers event

---

# 26. Why `>=`

software can lower COMPARE below current COUNT

timer should still terminate rather than never matching equality

---

# 27. Reset Values

```text
ENABLE=0
PERIODIC=0
IRQ_EN=0
COUNT=0
COMPARE=0xFFFFFFFF
PRESCALE=0
STATUS=0
```

---

# 28. Safe Reset

timer does not run or interrupt after reset until software configures it

---

# 29. Bus Protocol

same O'SoC contract:

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

# 30. Latency

Timer register accesses are same-cycle:

```text
ready=valid
```

writes commit on clock edge

---

# 31. Mixed-Latency SoC

CPU bus adapter from Lab 14 can handle:

```text
Timer: same-cycle
SRAM: one-cycle
SPI: variable
```

without timer-specific logic

---

# 32. Integration Top

file:

```text
rtl/osoc_bus_with_timer_top.sv
```

replaces TIMER stub with real:

```text
osoc_timer
```

other peripherals remain stubs

---

# 33. Why Isolate Timer First

failure locality remains clear:

```text
timer logic
or
bus-to-timer integration
```

---

# 34. Directory

```text
lab15_timer_interrupt/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB15_TH.md
├── rtl/
├── tb/
├── config/
├── firmware/
├── docs/
├── scripts/
├── reports/
└── build/
```

---

# 35. Step 1 — Environment

```bash
make check-env
```

---

# 36. Step 2 — Register Map

```bash
make check-map
```

checks:

```text
unique offsets
4-byte alignment
4-KiB aperture
```

---

# 37. Step 3 — RTL Contract

```bash
make check-contract
```

checks:

```text
one-shot
periodic
prescale
W1C
IRQ gate
ID
```

---

# 38. Step 4 — Header Contract

```bash
make check-header
```

ensures firmware macros match RTL

---

# 39. Step 5 — Lint

```bash
make lint
```

---

# 40. Step 6 — Simulation

```bash
make sim
```

---

# 41. Test 1 — ID

read:

```text
0x40001014
```

expected:

```text
0x54494D45
```

---

# 42. Test 2 — Reset CONTROL

expected:

```text
0
```

---

# 43. Test 3 — Reset COUNT

expected:

```text
0
```

---

# 44. Test 4 — Reset COMPARE

expected:

```text
0xFFFFFFFF
```

---

# 45. Test 5 — One-Shot

configure:

```text
COUNT=0
COMPARE=3
PRESCALE=0
CONTROL=0b101
```

---

# 46. One-Shot Expected

after compare:

```text
STATUS.pending=1
irq_o=1
ENABLE auto-clears
```

---

# 47. One-Shot CONTROL After Event

expected:

```text
0b100
```

IRQ_EN remains set

ENABLE clears

---

# 48. W1C Clear

write:

```text
STATUS = 1
```

expected:

```text
pending=0
irq_o=0
```

---

# 49. Prescale Test

configure:

```text
PRESCALE=2
```

tick every:

```text
3 system clocks
```

---

# 50. Why Test Prescale

without it a timer tied to a 50-MHz clock is inconvenient for millisecond-level
software scheduling

---

# 51. Periodic Test

configure:

```text
COUNT=0
COMPARE=2
PRESCALE=0
CONTROL=0b111
```

---

# 52. First Periodic Event

expected:

```text
irq=1
pending=1
COUNT reset/restarts
ENABLE stays 1
```

---

# 53. Clear First Event

software W1C clears pending

timer continues

---

# 54. Second Periodic Event

must occur again

this proves timer actually repeats rather than acting as one-shot

---

# 55. Byte Write Test

write full compare:

```text
0x12345678
```

then byte-lane0:

```text
0xAA
```

expected:

```text
0x123456AA
```

---

# 56. Illegal Offset

read:

```text
0x40001018
```

expected:

```text
error=1
```

---

# 57. Misaligned Access

read:

```text
0x40001002
```

expected:

```text
error=1
```

---

# 58. Write to ID

must:

```text
error=1
```

---

# 59. Expected End

```text
PASS: Lab 15 Timer + Interrupt integration completed.
```

---

# 60. Step 7 — Check Simulation

```bash
make check-sim
```

---

# 61. Step 8 — Yosys

optional:

```bash
make yosys
```

---

# 62. Step 9 — Report

```bash
make report
```

---

# 63. One Command

```bash
make all
```

---

# 64. Firmware Header

```text
firmware/include/osoc_timer.h
```

---

# 65. Start One-Shot

```c
osoc_timer_start_oneshot(compare,prescale);
```

---

# 66. Start Periodic

```c
osoc_timer_start_periodic(compare,prescale);
```

---

# 67. Polling Example

file:

```text
firmware/examples/timer_polling.c
```

works before CPU interrupt system exists

---

# 68. Why Polling Example Matters

we can verify software-visible timer behavior before introducing PLIC/trap
complexity

---

# 69. Interrupt Skeleton

file:

```text
firmware/examples/timer_irq_skeleton.c
```

documents future ISR behavior

but intentionally does not pretend current CPU already has complete interrupt
entry support

---

# 70. Timer IRQ Signal

```text
timer_irq_o =
    irq_pending &&
    irq_enable
```

---

# 71. Pending Without IRQ Enable

possible:

```text
pending=1
IRQ_EN=0
irq_o=0
```

software can still poll STATUS

---

# 72. Why Separate Pending and Enable

standard interrupt-controller pattern:

```text
event state
```

is distinct from:

```text
whether it is allowed to signal an interrupt
```

---

# 73. Future PLIC Connection

```text
timer_irq_o
   |
   v
PLIC source N
```

---

# 74. Future CPU Path

```text
Timer
 -> PLIC
 -> CPU external interrupt
 -> trap controller
 -> mtvec
 -> ISR
```

---

# 75. PLIC Responsibility

PLIC later provides:

```text
priority
enable
pending aggregation
claim
complete
```

Timer should not duplicate these controller functions

---

# 76. Timer Responsibility

Timer owns:

```text
event generation
local pending state
local interrupt enable
```

---

# 77. Why Local STATUS Still Exists with PLIC

PLIC tells CPU which source fired

peripheral STATUS tells firmware what happened inside the peripheral

---

# 78. CPU Trap Gap

current O'SoC CPU work still needs complete machine-mode interrupt architecture

do not wire `timer_irq_o` into random CPU control signal

---

# 79. Precise Interrupt Requirement

interrupt should be taken between architectural instructions

not halfway through a stalled load/store

---

# 80. Interaction with Lab 14 Stall

when CPU is waiting on SRAM:

```text
stall=1
```

timer may continue counting

if timer IRQ occurs:

```text
pending latches
```

CPU can service it after current instruction becomes precise and interrupt logic
allows entry

---

# 81. Why Pending Latch Is Important Here

interrupt event is not lost while CPU is stalled or interrupts are temporarily
masked

---

# 82. Timer Clock Domain

same:

```text
system clock
```

no CDC inside timer

---

# 83. External RTC Is Different

for low-power real-time clock:

```text
32.768-kHz domain
```

would require CDC and a different architecture

---

# 84. This Is a System Timer

not a wall-clock RTC

appropriate for:

```text
scheduler
timeouts
control loops
periodic sampling
```

---

# 85. Counter Width

32-bit

at 1-ms ticks:

```text
~49.7 days
```

before 32-bit count wraps

but periodic compare normally reloads earlier

---

# 86. At Raw 50 MHz

32-bit wrap occurs much sooner

prescaler solves this

---

# 87. Why Not 64-bit Yet

32-bit keeps register interface and RTL small for workshop

future CLINT/mtime-style design can use 64-bit counter

---

# 88. 64-Bit Extension

future:

```text
COUNT_LO
COUNT_HI
COMPARE_LO
COMPARE_HI
```

requires atomic read/write policy

---

# 89. Timer Race — Clear and New Event Same Cycle

current baseline software write can clear pending on same clock as a compare event

the ordering in RTL should be reviewed for production semantics

---

# 90. Preferred Production Policy

often:

```text
new event wins over clear
```

to avoid losing an event

---

# 91. Why Lab Documents This

rare races in interrupt status registers can become difficult field bugs

---

# 92. Prescaler Write

writing PRESCALE resets internal phase counter

makes configuration deterministic

---

# 93. Enable Transition

changing enable state resets prescaler phase

avoids partial old divider state

---

# 94. COUNT Write While Enabled

allowed

software can retarget timer phase

---

# 95. COMPARE Write Below COUNT

because comparison uses:

```text
count >= compare
```

next timer tick generates event

---

# 96. Deterministic Error Policy

invalid register:

```text
ready=1
error=1
```

no deadlock

---

# 97. Register Access and Lab 14 Adapter

same-cycle ready means CPU memory-mapped timer access does not require extra
wait cycle beyond the combinational bus path

---

# 98. Timing Path to Watch

```text
CPU address
 -> bus decode
 -> timer register mux
 -> bus rdata
 -> CPU writeback
```

for loads from timer registers

---

# 99. Another Timing Path

```text
COUNT comparator
 -> compare event
 -> IRQ pending D
```

normally short

---

# 100. Synthesis Expectation

Timer maps to:

```text
32-bit count adder
32-bit prescaler adder
comparators
configuration flops
small mux/decode
```

---

# 101. Area Optimization

if prescaler does not need 32 bits:

```text
reduce width
```

but 32-bit baseline keeps software flexible

---

# 102. Power

raw counter toggling every system clock can consume power

prescaler still has a counter that toggles

future low-power design may use:

```text
slower clock
clock gating
low-power timer domain
```

---

# 103. Do Not RTL-Gate Clock

same principle as Lab 14

use supported integrated clock-gating methodology if needed later

---

# 104. Industrial Automation Use

Timer can drive software timing for:

```text
PLC-like scan interval
sensor polling
relay timeout
debounce interval
communication timeout
heartbeat
```

---

# 105. But Safety Timing Needs More

safety-critical control needs:

```text
independent watchdog
fail-safe outputs
clock monitoring
fault diagnostics
```

not just one software timer

---

# 106. Pass Criteria — Registers

```text
[ ] ID
[ ] reset values
[ ] CONTROL
[ ] COUNT
[ ] COMPARE
[ ] PRESCALE
[ ] STATUS
```

---

# 107. Pass Criteria — One-Shot

```text
[ ] count advances
[ ] compare detected
[ ] pending set
[ ] irq_o asserted
[ ] enable auto-clears
[ ] W1C clear works
```

---

# 108. Pass Criteria — Periodic

```text
[ ] first event
[ ] clear pending
[ ] timer stays enabled
[ ] second event occurs
```

---

# 109. Pass Criteria — Prescaler

```text
[ ] no early event
[ ] event delayed by divider
```

---

# 110. Pass Criteria — Errors

```text
[ ] illegal offset error
[ ] misaligned error
[ ] write-to-ID error
```

---

# 111. Pass Criteria — Software Contract

```text
[ ] header offsets match RTL
[ ] CONTROL masks match RTL
[ ] polling example exists
[ ] IRQ skeleton exists
```

---

# 112. Reports

```text
reports/
├── 00_environment.log
├── 01_register_map.txt
├── 02_rtl_contract.txt
├── 03_header.txt
├── 04_lint.log
├── 05_sim_build.log
├── 05_sim.log
├── 06_sim_check.txt
├── 07_yosys_probe.log
└── LAB15_REPORT.md
```

---

# 113. Recommended Run Sequence

```bash
make clean
make check-env
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

# 114. Freeze after Lab 15

freeze:

```text
TIMER_BASE = 0x40001000
CONTROL offsets/bits
COUNT semantics
COMPARE semantics
PRESCALE+1 semantics
STATUS W1C
one-shot behavior
periodic behavior
timer_irq_o polarity
```

---

# 115. Next Lab

natural next step:

```text
Lab 16 — PLIC / Interrupt Controller
```

connect:

```text
GPIO irq
Timer irq
future SPI irq
```

into one prioritized interrupt architecture

---

# 116. Engineering Rule

> Interrupt generation and interrupt handling are different layers.

A peripheral is complete when it can produce a deterministic pending event and
IRQ signal.

A CPU interrupt subsystem is complete only after priority, masking, precise trap
entry, CSR state, and return-from-interrupt are also verified.
