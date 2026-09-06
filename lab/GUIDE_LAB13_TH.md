# Lab 13 — GPIO Peripheral
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 Memory-Mapped GPIO for Industrial Automation

**Previous Labs:** Lab 11 System Bus, Lab 12 SRAM Integration  
**Peripheral:** 16-bit General-Purpose Input/Output  
**Base address:** `0x4000_0000`  
**Bus:** O'SoC valid/ready/error  
**Register window:** 4 KiB  
**Input synchronization:** 2-FF  
**Interrupt:** rising/falling edge per GPIO, W1C status

---

# 1. เป้าหมายของ Lab 13

หลัง Lab 12 เรามี:

```text
System Bus
+
SRAM architecture
```

แต่ยังไม่มี peripheral ที่ software ใช้ควบคุม external world

Lab 13 เพิ่ม:

```text
GPIO
```

ซึ่งเป็น peripheral ที่สำคัญที่สุดสำหรับ:

```text
LED
relay
digital output
switch
limit switch
proximity sensor
industrial digital input
status signal
```

---

# 2. Architecture

```text
                  O'SoC System Bus
                         |
                         v
                  +-------------+
                  |  osoc_gpio  |
                  +------+------+------+
                         |      |
                  DATA/DIR      |
                         |      |
                         v      v
                    gpio_out   gpio_oe
                         |
                         +----------------> future I/O pads

external input
     |
     v
  gpio_in
     |
  2-FF sync
     |
     +------> DATA_IN
     |
     +------> edge detector
                 |
                 v
             IRQ_STATUS
                 |
              IRQ_EN
                 |
                 v
               irq_o
```

---

# 3. GPIO Width

baseline:

```text
16 GPIO bits
```

module parameter:

```systemverilog
parameter integer WIDTH = 16
```

สามารถปรับเป็น:

```text
8
16
24
32
```

ภายหลัง

---

# 4. Why 16 Bits

16 GPIOs พอสำหรับ workshop และ industrial example เช่น:

```text
8 digital outputs
8 digital inputs
```

หรือ:

```text
4 relays
4 LEDs
8 sensors
```

โดยไม่ทำ pad ring ใหญ่เกินไป

---

# 5. Memory-Mapped GPIO

software ไม่ต้องมี special I/O instruction

ใช้ normal memory access:

```c
*(volatile uint32_t *)0x40000000 = value;
```

CPU มอง GPIO registerเหมือน memory address

---

# 6. Base Address

```text
GPIO_BASE = 0x4000_0000
```

ตรงกับ address map ที่ freeze ใน Lab 11

---

# 7. Register Map

```text
0x40000000 DATA_OUT
0x40000004 DATA_IN
0x40000008 DIR
0x4000000C SET
0x40000010 CLR
0x40000014 TOGGLE
0x40000018 IRQ_EN
0x4000001C IRQ_RISE
0x40000020 IRQ_FALL
0x40000024 IRQ_STATUS
0x40000028 ID
```

---

# 8. DATA_OUT

offset:

```text
0x00
```

access:

```text
RW
```

stores output latch

---

# 9. DATA_IN

offset:

```text
0x04
```

access:

```text
RO
```

returns synchronized GPIO input values

---

# 10. DIR

offset:

```text
0x08
```

semantics:

```text
0 = input
1 = output
```

---

# 11. SET Register

offset:

```text
0x0C
```

write:

```text
1
```

sets corresponding output bit

example:

```c
GPIO_SET = 1 << 3;
```

sets GPIO3 without read-modify-write

---

# 12. CLR Register

offset:

```text
0x10
```

write-one clears matching bits

---

# 13. TOGGLE Register

offset:

```text
0x14
```

write-one toggles matching bits

useful for:

```text
LED blink
square-wave debug
software heartbeat
```

---

# 14. Why SET/CLR/TOGGLE Are Valuable

without atomic registers:

```c
reg = DATA_OUT;
reg |= mask;
DATA_OUT = reg;
```

can create race conditions if interrupt/service code accesses same register

atomic SET/CLR reduces this risk

---

# 15. IRQ_EN

offset:

```text
0x18
```

per-pin interrupt enable

---

# 16. IRQ_RISE

offset:

```text
0x1C
```

bit=1 enables rising-edge detection

---

# 17. IRQ_FALL

offset:

```text
0x20
```

bit=1 enables falling-edge detection

---

# 18. IRQ_STATUS

offset:

```text
0x24
```

latched event status

access:

```text
RW1C
```

meaning:

```text
Read   -> current pending status
Write1 -> clear selected pending bit
Write0 -> keep existing bit
```

---

# 19. ID Register

offset:

```text
0x28
```

returns:

```text
0x4750494F
```

ASCII:

```text
GPIO
```

ใช้ตรวจ software/hardware mapping

---

# 20. Why ID Register Helps

firmware can sanity-check:

```c
if (GPIO_ID != 0x4750494F)
    hardware_mismatch();
```

very useful during bring-up

---

# 21. Bus Interface

request:

```text
valid
addr
wdata
wstrb
```

response:

```text
rdata
ready
error
```

same as Lab 11/12

---

# 22. GPIO Latency

GPIO registers are standard flops

bus response baseline:

```text
same-cycle ready
```

writes commit on:

```text
posedge clk
```

---

# 23. Why Same-Cycle Read Is Fine Here

unlike SRAM macro:

```text
register read mux
```

is combinational and small

so no mandatory wait-state

---

# 24. Byte Strobes

GPIO supports:

```text
wstrb[3:0]
```

for RW registers

example:

```text
wstrb=0010
```

updates only byte1

---

# 25. Byte Write Example

DATA_OUT currently:

```text
0x00000050
```

write:

```text
wdata = 0x0000AA00
wstrb = 0010
```

result:

```text
0x0000AA50
```

---

# 26. GPIO Input Is Asynchronous

external switch/sensor signal is not synchronous to system clock

directly sampling it can cause:

```text
metastability
```

---

# 27. Two-Flop Synchronizer

Lab uses:

```text
gpio_in
   |
   v
sync_ff1
   |
   v
sync_ff2
```

DATA_IN uses:

```text
sync_ff2
```

---

# 28. Metastability Note

2-FF synchronization reduces metastability propagation probability

it does not mathematically eliminate metastability

but is standard for single-bit asynchronous control inputs

---

# 29. Multi-Bit Input Caveat

for independent GPIO bits:

```text
2-FF per bit
```

is appropriate

for coherent multi-bit buses:

```text
do not use independent synchronizers
```

use handshake/FIFO instead

---

# 30. Edge Detection

previous synchronized state:

```text
sync_prev
```

current:

```text
sync_ff2
```

rising event:

```text
~prev & current
```

falling event:

```text
prev & ~current
```

---

# 31. Rising Enable

edge event is masked by:

```text
IRQ_RISE
```

---

# 32. Falling Enable

fall event is masked by:

```text
IRQ_FALL
```

---

# 33. IRQ Status Latching

once an event happens:

```text
IRQ_STATUS bit remains 1
```

until software clears it

this prevents short pulses from being lost

---

# 34. IRQ Output

```text
irq_pending = irq_status & irq_en
```

then:

```text
irq_o = OR(all irq_pending bits)
```

---

# 35. Why Keep irq_pending Vector

later PLIC integration may want:

```text
per-source information
```

while `irq_o` is convenient combined signal

---

# 36. Direction Signals

peripheral outputs separate:

```text
gpio_out_o
gpio_oe_o
gpio_in_i
```

rather than internal tri-state

---

# 37. Why No `inout` Inside Core

modern ASIC synthesis/PnR prefers directional internal nets

tri-state exists only at I/O pad boundary

---

# 38. Future IHP Pad Mapping

full-chip wrapper later does:

```text
gpio_out_o -> pad c2p
gpio_oe_o  -> pad output enable
pad p2c    -> gpio_in_i
```

using bidirectional I/O pad cell

---

# 39. RTL File

main peripheral:

```text
rtl/osoc_gpio.sv
```

---

# 40. Integration Top

standalone integration:

```text
rtl/osoc_bus_with_gpio_top.sv
```

replaces only GPIO stub with real peripheral

other slaves remain stubs

---

# 41. Why Isolate GPIO First

if test fails, cause is likely:

```text
GPIO
or
bus-to-GPIO integration
```

not SRAM/CPU/PLIC complexity

---

# 42. Directory Structure

```text
lab13_gpio_peripheral/
├── Makefile
├── QUICKSTART.sh
├── README.md
├── GUIDE_LAB13_TH.md
│
├── rtl/
│   ├── osoc_bus_pkg.sv
│   ├── osoc_system_bus.sv
│   ├── osoc_bus_slave_stub.sv
│   ├── osoc_gpio.sv
│   └── osoc_bus_with_gpio_top.sv
│
├── tb/
│   └── tb_osoc_gpio.sv
│
├── config/
│   ├── address_map.yaml
│   └── gpio_registers.yaml
│
├── firmware/
│   ├── include/osoc_gpio.h
│   └── examples/
│       ├── gpio_blink.c
│       └── gpio_input_irq.c
│
├── docs/
│   └── REGISTER_MAP.md
│
├── scripts/
├── reports/
└── build/
```

---

# 43. Step 1 — Enter Lab

```bash
cd lab13_gpio_peripheral
```

---

# 44. Step 2 — Environment Check

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
```

---

# 45. Step 3 — Validate Register Map

```bash
make check-map
```

checks:

```text
aligned offsets
unique offsets
within 4-KiB window
```

---

# 46. Expected Map Report

```text
DATA_OUT    0x00
DATA_IN     0x04
DIR         0x08
SET         0x0C
CLR         0x10
TOGGLE      0x14
IRQ_EN      0x18
IRQ_RISE    0x1C
IRQ_FALL    0x20
IRQ_STATUS  0x24
ID          0x28
```

---

# 47. Step 4 — RTL Contract Check

```bash
make check-contract
```

checks:

```text
bus interface
register set
2-FF synchronizer
interrupt logic
W1C
ID value
```

---

# 48. Step 5 — Firmware Header Check

```bash
make check-header
```

checks:

```text
C register definitions
base address
helper functions
```

---

# 49. Step 6 — Lint

```bash
make lint
```

top:

```text
osoc_bus_with_gpio_top
```

---

# 50. Step 7 — Simulation

```bash
make sim
```

self-checking testbench exercises all key functionality

---

# 51. Test 1 — ID

read:

```text
0x40000028
```

must return:

```text
0x4750494F
```

---

# 52. Test 2 — Reset

after reset:

```text
DATA_OUT = 0
DIR = 0
IRQ_EN = 0
IRQ_STATUS = 0
```

---

# 53. Reset Direction Choice

default:

```text
DIR = 0
```

means:

```text
all GPIOs input
```

safer than driving unknown external hardware immediately after reset

---

# 54. Industrial Safety Rationale

for relay/actuator systems:

```text
reset should not unexpectedly energize outputs
```

input/high-impedance is conservative default

actual product may need board-level pull-downs/pull-ups and safety logic

---

# 55. Test 3 — DIR

write:

```text
0x000000FF
```

to DIR

result:

```text
GPIO[7:0] outputs
GPIO[15:8] inputs
```

---

# 56. Test 4 — DATA_OUT

write:

```text
0x55
```

verify:

```text
gpio_out_o = 0x0055
```

---

# 57. Test 5 — SET

DATA_OUT:

```text
0x55
```

SET:

```text
0x0A
```

result:

```text
0x5F
```

---

# 58. Test 6 — CLR

current:

```text
0x5F
```

CLR:

```text
0x03
```

result:

```text
0x5C
```

---

# 59. Test 7 — TOGGLE

current:

```text
0x5C
```

TOGGLE:

```text
0x0C
```

result:

```text
0x50
```

---

# 60. Test 8 — Byte Write

write only byte1:

```text
wdata=0x0000AA00
wstrb=0010
```

result:

```text
DATA_OUT=0xAA50
```

---

# 61. Test 9 — Input Synchronization

drive:

```text
gpio_in_i = 0x5A5A
```

wait several clocks

read DATA_IN

expected:

```text
0x5A5A
```

---

# 62. Why Wait 3 Clocks in Test

path:

```text
external
 -> sync_ff1
 -> sync_ff2
 -> bus read
```

test waits long enough to remove delta-cycle ambiguity

---

# 63. Test 10 — Rising IRQ

configure GPIO12:

```text
IRQ_EN   bit12 = 1
IRQ_RISE bit12 = 1
```

transition:

```text
0 -> 1
```

expected:

```text
IRQ_STATUS[12] = 1
irq_pending[12] = 1
irq_o = 1
```

---

# 64. Test 11 — W1C

write:

```text
1 << 12
```

to IRQ_STATUS

expected:

```text
bit12 clears
irq_o returns 0
```

---

# 65. Test 12 — Falling IRQ

GPIO13:

```text
IRQ_EN   bit13 = 1
IRQ_FALL bit13 = 1
```

transition:

```text
1 -> 0
```

must set status bit13

---

# 66. Test 13 — Illegal Offset

read:

```text
GPIO_BASE + 0x2C
```

must:

```text
error = 1
```

---

# 67. Test 14 — Misaligned Address

read:

```text
GPIO_BASE + 0x02
```

must:

```text
error=1
```

---

# 68. Test 15 — Write to RO ID

write:

```text
GPIO_ID
```

must return:

```text
error=1
```

---

# 69. Expected Simulation End

```text
PASS: Lab 13 GPIO peripheral integration test completed.
```

---

# 70. Step 8 — Check Simulation

```bash
make check-sim
```

---

# 71. Step 9 — Optional Yosys Probe

```bash
make yosys
```

checks:

```text
hierarchy
process conversion
logic checks
cell statistics
```

---

# 72. Step 10 — Report

```bash
make report
```

output:

```text
reports/LAB13_REPORT.md
```

---

# 73. One Command

```bash
make all
```

---

# 74. C Header

file:

```text
firmware/include/osoc_gpio.h
```

provides:

```c
OSOC_GPIO_DATA_OUT
OSOC_GPIO_DATA_IN
OSOC_GPIO_DIR
OSOC_GPIO_SET
OSOC_GPIO_CLR
OSOC_GPIO_TOGGLE
OSOC_GPIO_IRQ_EN
OSOC_GPIO_IRQ_RISE
OSOC_GPIO_IRQ_FALL
OSOC_GPIO_IRQ_STAT
OSOC_GPIO_ID
```

---

# 75. Why Use `volatile`

memory-mapped register accesses must use:

```c
volatile
```

otherwise compiler may optimize reads/writes away or reorder assumptions incorrectly

---

# 76. LED Blink Example

```c
const uint32_t led = 1u << 0;

osoc_gpio_set_output(led);

for (;;) {
    osoc_gpio_toggle(led);
    delay(...);
}
```

---

# 77. Industrial Relay Example

same architecture:

```text
GPIO0 -> pad -> transistor/driver -> relay
```

SoC pad must not directly drive industrial relay coil

external driver and isolation are required

---

# 78. Sensor Input Example

```text
24-V sensor
 -> industrial input conditioning
 -> level shifter/isolation
 -> IHP I/O pad
 -> gpio_in
```

never connect 24-V industrial signal directly to chip pad

---

# 79. Input Conditioning

real industrial input path may require:

```text
ESD
RC filter
Schmitt trigger
opto-isolation
digital isolator
level conversion
```

depending on system

---

# 80. Debounce

2-FF synchronizer does not debounce a mechanical switch

switch may generate:

```text
010101...
```

for milliseconds

---

# 81. Future Debounce Block

can add:

```text
counter-based stable filter
```

before edge detection

---

# 82. Glitch Filtering

industrial sensors can experience noise

future version may require:

```text
N-cycle stable filter
```

before IRQ edge detection

---

# 83. GPIO and PLIC

Lab 13 outputs:

```text
gpio_irq_o
gpio_irq_pending_o
```

future PLIC Lab connects:

```text
gpio_irq_o -> PLIC source
```

or selected individual sources depending architecture

---

# 84. Why Not Implement PLIC Here

separation of concerns

Lab 13 should prove GPIO event generation independently

---

# 85. GPIO and Pad Ring

current Lab is core-level peripheral

future full-chip integration must map to:

```text
sg13g2_IOPadInOut30mA
```

or appropriate IHP bidirectional pad variant

---

# 86. Bidirectional Pad Concept

internal signals:

```text
gpio_out
gpio_oe
gpio_in
```

pad behavior:

```text
if oe:
    drive pad from gpio_out
else:
    input/high-Z
```

---

# 87. Do Not Infer Tri-State in Core

keep tri-state at I/O pad level

this improves synthesis portability

---

# 88. Output Enable Polarity

IHP pad output-enable polarity must be verified from installed PDK Verilog/model

do not assume:

```text
1=drive
```

without checking cell interface

---

# 89. Full-Chip Pin Count Impact

16 bidirectional GPIOs add:

```text
16 signal pads
```

plus:

```text
clock
reset
SPI
JTAG
power pads
```

therefore full SoC die/pad ring must be resized/replanned

---

# 90. GPIO Register Design Review

`DATA_OUT` stores value regardless of DIR

therefore software can preload value then enable direction

useful sequence:

```text
write safe output value
then set DIR
```

---

# 91. Safe Output Enable Sequence

example:

```c
GPIO_DATA_OUT = SAFE_VALUE;
GPIO_DIR = OUTPUT_MASK;
```

prevents transient wrong output when switching pin from input to output

---

# 92. Atomic SET/CLR and ISR Safety

SET/CLR reduce lost-update races

important once interrupts are enabled

---

# 93. IRQ_STATUS W1C Race

hardware event and software clear can happen same clock

RTL expression is designed to combine:

```text
existing status
new events
clear mask
```

review this behavior carefully for production

---

# 94. Current W1C Policy

same-cycle clear has priority after event merge in the write expression

thus a software clear may clear a bit that also receives a same-cycle event

for stricter event retention, production version can give new events priority

---

# 95. Alternative Event-Priority Formula

possible future policy:

```text
(status & ~clear) | new_event
```

which guarantees a same-cycle new event remains pending

---

# 96. Why Mention This

interrupt status semantics must be explicit

otherwise rare race conditions become field failures

---

# 97. Recommended Production Change

for safety-critical or high-integrity applications:

```text
new event wins over clear
```

is often preferable

Lab baseline can be modified before final SoC freeze

---

# 98. Register Access Error Policy

invalid register:

```text
ready=1
error=1
```

same deterministic error philosophy as Lab 11

---

# 99. Write to RO Register

returns error

helps detect software bugs

---

# 100. Read from WO Register

Lab returns zero without error

this is a deliberate baseline policy

can be changed to error if desired

---

# 101. Why Read WO as Zero

some firmware/debugger tools probe registers generically

return-zero is often convenient

---

# 102. Byte Writes and WIDTH=16

although registers are 32-bit, only bits:

```text
15:0
```

affect GPIO hardware

upper bits read as zero

---

# 103. Reserved Upper Bits

software should write zero to unused upper bits

future wider GPIO version may assign them

---

# 104. Synthesis Expectations

GPIO maps mainly to:

```text
flip-flops
muxes
AND/OR/XOR
comparators
synchronizer flops
```

small compared with CPU/SRAM/pad ring

---

# 105. Timing Expectations

likely critical paths:

```text
bus address decode -> read mux
```

or:

```text
sync_ff2 -> edge logic -> status
```

at 50 MHz should be modest

---

# 106. CDC Consideration

external inputs are asynchronous CDC paths

the synchronizer first stage should not be treated as normal synchronous timing path

future chip-level SDC should mark appropriate async paths

---

# 107. SDC Strategy

at full-chip level:

```text
pad input -> synchronizer first stage
```

may require:

```text
set_false_path
```

or asynchronous input timing strategy depending methodology

do not constrain external asynchronous sensors as synchronous data unless actually synchronous

---

# 108. Synchronizer Attributes

production flow may add implementation attributes such as:

```text
ASYNC_REG
```

if supported by synthesis/PnR methodology

to encourage close placement of synchronizer flops

---

# 109. Why Not Hard-Code Tool-Specific Attribute Here

Lab keeps RTL portable

physical implementation Lab can add tool-specific constraints/attributes after flow validation

---

# 110. Firmware Build Note

provided C examples are source-level examples

they require the RISC-V toolchain and startup/linker files from future firmware Lab

---

# 111. GPIO Blink Does Not Require Interrupts

basic bring-up sequence:

```text
DIR
DATA_OUT/TOGGLE
```

is ideal first software test

---

# 112. GPIO Input Bring-Up

second test:

```text
read DATA_IN
```

connect switches/safe low-voltage test stimulus

---

# 113. GPIO IRQ Bring-Up

third test:

```text
enable edge
trigger input
read IRQ_STATUS
clear W1C
```

before connecting PLIC/CPU interrupt entry

---

# 114. Suggested Silicon Test Pattern

outputs:

```text
0x0001
0x0002
0x0004
...
0x8000
```

walking-one pattern verifies individual pads

---

# 115. Suggested Input Test Pattern

drive:

```text
0x0001
0x0002
...
0x8000
```

read DATA_IN and compare

---

# 116. Loopback Test

PCB can loop selected outputs to inputs

then software can automatically verify:

```text
pad out
package trace
pad in
GPIO logic
```

---

# 117. Pass Criteria — Register Function

```text
[ ] ID read PASS
[ ] reset values PASS
[ ] DIR PASS
[ ] DATA_OUT PASS
[ ] SET PASS
[ ] CLR PASS
[ ] TOGGLE PASS
[ ] byte write PASS
```

---

# 118. Pass Criteria — Input Function

```text
[ ] external input synchronizes
[ ] DATA_IN matches synchronized input
[ ] no direct unsynchronized DATA_IN path
```

---

# 119. Pass Criteria — Interrupt

```text
[ ] rising edge detected
[ ] falling edge detected
[ ] IRQ_EN masks status into irq_pending
[ ] irq_o asserts
[ ] W1C clears status
```

---

# 120. Pass Criteria — Error Handling

```text
[ ] illegal offset returns error
[ ] misaligned access returns error
[ ] write to ID returns error
```

---

# 121. Pass Criteria — Software Contract

```text
[ ] osoc_gpio.h matches RTL register map
[ ] volatile register definitions present
[ ] blink example present
[ ] input/IRQ example present
```

---

# 122. Generated Reports

```text
reports/
├── 00_environment.log
├── 01_register_map.txt
├── 02_rtl_contract.txt
├── 03_firmware_header.txt
├── 04_lint.log
├── 05_sim_build.log
├── 05_sim.log
├── 06_sim_check.txt
├── 07_yosys_probe.log
└── LAB13_REPORT.md
```

---

# 123. Recommended Run Sequence

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

# 124. One Command

```bash
make all
```

---

# 125. Integration with Lab 12 SRAM

current Lab package uses SRAM stub for isolation

next integrated SoC should instantiate:

```text
real osoc_sram_bus_slave
+
real osoc_gpio
```

simultaneously

---

# 126. Suggested SoC Hierarchy

```text
osoc1_soc
|
+-- u_cpu
+-- u_cpu_bus_adapter
+-- u_bus
|
+-- u_rom
+-- u_sram
+-- u_gpio
+-- u_timer
+-- u_spi
+-- u_plic
+-- u_debug
```

---

# 127. Still Missing CPU Adapter

GPIO works at bus master test level

CPU cannot yet safely issue wait-state transactions until CPU adapter/stall logic is completed

---

# 128. Practical Lab Ordering

recommended:

```text
Lab 11 System Bus
Lab 12 SRAM
Lab 13 GPIO
Lab 14 CPU Bus Adapter / Wait-State
Lab 15 Timer
Lab 16 PLIC
Lab 17 SPI
Lab 18 Firmware Execution
```

or move CPU adapter before GPIO depending course flow

---

# 129. Freeze after Lab 13

freeze:

```text
GPIO base address
register offsets
DIR polarity
SET/CLR/TOGGLE semantics
2-FF synchronization
IRQ edge semantics
W1C semantics
GPIO width baseline
```

---

# 130. Design Review Questions

1. ทำไม DATA_IN ต้องใช้ synchronizer?
2. ทำไม 2-FF synchronizer ไม่ใช่ debounce?
3. SET/CLR ดีกว่า read-modify-write อย่างไร?
4. DIR reset=0 มีประโยชน์ด้าน safety อย่างไร?
5. ทำไม core ไม่ควรใช้ inout?
6. W1C หมายความว่าอะไร?
7. rising/falling detection ใช้ state ใดเปรียบเทียบ?
8. ทำไม `volatile` สำคัญกับ memory-mapped I/O?
9. ทำไม output enable polarity ต้องตรวจจาก IHP pad model?
10. GPIO simulationผ่าน แต่ firmware header offsetผิด ถือว่า Lab ผ่านหรือไม่?

คำตอบข้อ 10:

```text
ไม่ผ่าน
```

---

# 131. Industrial Automation Design Note

GPIO peripheral เป็น digital logic low-voltage

มันไม่ได้แทน:

```text
industrial 24-V input stage
relay driver
galvanic isolation
surge protection
EMC filtering
```

เหล่านี้อยู่ระดับ board/package/system

---

# 132. Safety Rule

ห้ามต่อ:

```text
24 V
relay coil
motor
industrial sensor line
```

เข้าชิปโดยตรง

ต้องมี conditioning/driver circuitry

---

# 133. Transition ไป Full-Chip GPIO Pads

ขั้น physical ถัดไป:

```text
gpio_out_o
gpio_oe_o
gpio_in_i
```

ต้อง map เข้า:

```text
IHP bidirectional I/O pads
```

แล้ว update:

```text
pad ring
SDC
bond plan
package pinout
```

---

# 134. Engineering Rule

> GPIO ที่ดีไม่ใช่แค่ register ที่เปิด/ปิด LED

สำหรับ SoC จริงควรมี:

```text
safe reset state
atomic output operations
synchronized inputs
defined interrupt semantics
software-visible ID
deterministic bus errors
```

Lab 13 จึงวาง GPIO ให้พร้อมต่อไปสู่ O'SoC 1.0 จริง ไม่ใช่เพียง demo peripheral
