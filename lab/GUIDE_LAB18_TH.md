# Lab 18 — SPI Flash / XIP
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC External Serial Flash and Execute-In-Place

**SPI MMIO base:** `0x4000_2000`  
**XIP window:** `0x1000_0000-0x10FF_FFFF`  
**SPI mode:** Mode 0  
**Read command:** `0x03`  
**Flash address:** 24-bit  
**Fetch unit:** 32-bit RV32 instruction word  
**Cache:** one aligned 32-bit word  
**CPU requirement:** instruction wait-state / stall support

---

# 1. เป้าหมายของ Lab

หลัง Lab 12 CPU มี internal instruction ROM

แต่ SoC จริงต้องการ firmware ที่:

```text
ใหญ่กว่า
update ได้
อยู่นอก die
ไม่กิน standard-cell area มาก
```

ทางเลือกทั่วไปคือ:

```text
external SPI NOR Flash
```

และ CPU execute code directly จาก Flash:

```text
XIP = Execute In Place
```

---

# 2. Core Architecture

```text
                  CPU PC
                    |
                    v
          Instruction Fetch Adapter
             /               \
            /                 \
       Boot ROM              XIP window
                              |
                              v
                      SPI XIP Controller
                              |
                    +---------+---------+
                    |                   |
                   CS#                 SCK
                    |                   |
                   MOSI               MISO
                    \                   /
                     \                 /
                       SPI NOR Flash
```

---

# 3. Why XIP Is Not Ordinary ROM

internal combinational ROM:

```text
address -> instruction
```

same cycle

SPI Flash:

```text
command
address
serial bits
data bytes
```

many clock cycles

---

# 4. The Architecture Problem

original O'SoC CPU instruction interface assumes:

```text
pc_o -> instr_i
```

without ready

therefore XIP cannot be connected directly

---

# 5. Lab 18 Rule

add:

```text
imem_stall
```

and combine with data-memory stall:

```text
cpu_stall =
    dmem_stall |
    imem_stall
```

---

# 6. Why Reuse Existing Stall Architecture

Lab 14 already defines architectural freeze:

```text
PC hold
RF write suppressed
```

Lab 17 extends that to:

```text
CSR write suppressed
trap entry suppressed
MRET suppressed
```

XIP uses the same freeze mechanism

---

# 7. XIP Address Window

Lab freezes:

```text
0x10000000 - 0x10FFFFFF
```

16 MiB

---

# 8. Why 16 MiB

24-bit serial Flash address:

```text
2^24 bytes
=
16 MiB
```

matches command `0x03` baseline cleanly

---

# 9. SPI MMIO Base

control/status register block remains:

```text
0x40002000
```

from earlier O'SoC memory map

---

# 10. Two Paths

SPI Flash subsystem has two independent logical interfaces:

```text
MMIO path
XIP path
```

---

# 11. MMIO Path

software uses:

```text
CONTROL
DIVIDER
STATUS
FLASH_ID
XIP_HITS
XIP_MISSES
ID
```

---

# 12. XIP Path

CPU/fetch adapter uses:

```text
valid
address
rdata
ready
error
```

---

# 13. Why Separate Them

CPU instruction fetch should not be modeled as register reads

XIP is a memory-like interface

---

# 14. Register Map

```text
0x00 CONTROL
0x04 DIVIDER
0x08 STATUS
0x0C FLASH_ID
0x10 XIP_HITS
0x14 XIP_MISSES
0x18 ID
```

---

# 15. CONTROL

bit0:

```text
XIP_EN
```

---

# 16. DIVIDER

controls SPI serial clock

Lab engine toggles SCK after programmable divider count

---

# 17. STATUS

baseline:

```text
bit0 controller present/ready
```

---

# 18. FLASH_ID

training constant:

```text
0x00EF4018
```

used only as a software-visible demo identifier

real hardware should issue JEDEC-ID command and report the actual attached Flash

---

# 19. XIP_HITS

counts one-word cache hits

---

# 20. XIP_MISSES

counts real serial Flash transactions

---

# 21. SPI ID

```text
0x53504958
```

ASCII:

```text
SPIX
```

---

# 22. SPI Mode

Lab uses:

```text
Mode 0
CPOL=0
CPHA=0
```

---

# 23. Mode 0 Timing

```text
SCK idle low
sample MISO on rising edge
change MOSI on falling edge
```

---

# 24. Bit Order

```text
MSB first
```

---

# 25. Flash Command

baseline read:

```text
0x03
```

---

# 26. Why 0x03

simple standard serial read concept

no dummy cycles required in baseline model

---

# 27. Future Fast Read

future enhancement:

```text
0x0B FAST READ
```

requires dummy byte/cycles

---

# 28. Future Quad SPI

future:

```text
1-1-4
1-4-4
QPI
```

needs multiple data I/O pins and more complex controller

---

# 29. XIP Miss Transaction

for address:

```text
0x10000004
```

Flash offset:

```text
0x000004
```

transaction:

```text
CS low

03
00
00
04

read byte4
read byte5
read byte6
read byte7

CS high
```

---

# 30. Little-Endian Assembly

Flash bytes:

```text
13 01 20 01
```

become RV32 word:

```text
0x01200113
```

---

# 31. Why Endianness Matters

SPI sends bytes serially

CPU consumes 32-bit little-endian instructions

controller must assemble correctly

---

# 32. SPI Byte Engine

file:

```text
rtl/osoc_spi_byte_engine.sv
```

handles exactly one 8-bit transfer

---

# 33. Byte Engine Inputs

```text
start
tx_byte
divider
```

---

# 34. Outputs

```text
busy
done
rx_byte
```

plus physical:

```text
SCK
MOSI
MISO
```

---

# 35. Why Byte Engine Is Separate

makes SPI timing independently reusable for:

```text
JEDEC ID
status register
page read
future SPI peripheral
```

---

# 36. XIP FSM

file:

```text
rtl/osoc_spi_xip.sv
```

states:

```text
IDLE
CMD
A2
A1
A0
D3
D2
D1
D0
DONE
```

---

# 37. CMD State

sends:

```text
0x03
```

---

# 38. A2/A1/A0

send 24-bit byte address

---

# 39. D3..D0

clock four data bytes from Flash

---

# 40. DONE

returns:

```text
ready=1
rdata=assembled word
```

---

# 41. Why Request Must Stay Valid

requester follows ready/valid contract:

```text
valid remains asserted
until ready
```

---

# 42. One-Word Cache

Lab includes:

```text
cache_valid
cache_addr
cache_data
```

---

# 43. Cache Hit

same aligned address:

```text
ready immediately
```

without serial transaction

---

# 44. Cache Miss

different word:

```text
launch SPI transaction
stall requester
```

---

# 45. Why Only One Word

keeps Lab architecture transparent

students can directly observe:

```text
miss
hit
replacement
```

---

# 46. Future Line Cache

production XIP often fetches:

```text
16
32
64-byte lines
```

to amortize command/address overhead

---

# 47. Future Prefetch

sequential instruction fetch can prefetch next line

important for performance

---

# 48. Baseline Performance

a 32-bit word requires:

```text
8 command bits
24 address bits
32 data bits
=
64 serial clock bits
```

ignoring CS/setup overhead

---

# 49. Performance Lesson

serial Flash XIP latency is fundamentally much larger than internal SRAM

---

# 50. Why Cache Is Essential

without cache:

```text
every instruction
=
full SPI command/address/data
```

extremely slow

---

# 51. Boot Flow

recommended:

```text
reset
PC=0
boot ROM
configure SPI
enable XIP
jump 0x10000000
```

---

# 52. Why Keep Boot ROM

if Flash/XIP configuration is broken:

```text
CPU still has deterministic reset code
```

---

# 53. Boot ROM Can Diagnose Flash

future boot code can:

```text
read JEDEC ID
verify image header
CRC
signature
fallback
```

---

# 54. Instruction Fetch Adapter

file:

```text
rtl/osoc_instruction_fetch_adapter.sv
```

---

# 55. Boot Region

```text
0x00000000-0x00000FFF
```

returns internal ROM data

no stall

---

# 56. XIP Region

```text
0x10000000-0x10FFFFFF
```

uses XIP controller

---

# 57. XIP Stall

```text
imem_stall =
    !xip_ready
```

while XIP request is active

---

# 58. Combined CPU Stall

integration:

```text
cpu_stall =
    dmem_stall |
    imem_stall
```

---

# 59. Why This Is Safe with Lab 17

while XIP miss stalls:

```text
no PC advance
no RF commit
no CSR commit
no trap entry
no MRET
```

---

# 60. Interrupt During XIP Miss

PLIC may assert:

```text
cpu_ext_irq=1
```

but trap entry waits until:

```text
imem_stall=0
```

and current instruction boundary is precise

---

# 61. Why This Is Important

otherwise CPU could trap with an instruction fetch only partially completed

---

# 62. MMIO vs XIP Concurrency

baseline Lab does not arbitrate concurrent manual SPI command traffic and XIP

MMIO only configures XIP

---

# 63. Production Controller

should define arbitration between:

```text
XIP
software command engine
DMA
program/erase
```

---

# 64. Flash Write/Erase

not implemented

---

# 65. Why Read-Only First

program/erase adds:

```text
WREN
page boundaries
busy polling
sector erase
power-fail behavior
```

and is a separate substantial Lab

---

# 66. Behavioral Flash

file:

```text
tb/spi_flash_model.sv
```

---

# 67. Model Contents

preloads RV32 words at Flash offsets:

```text
0x000000
0x000004
0x000008
0x00000C
```

---

# 68. First Word

bytes form:

```text
0x200000B7
```

---

# 69. Second Word

```text
0x01200113
```

---

# 70. Why Use Real RV32 Words

verifies:

```text
byte order
address increment
word assembly
```

not just arbitrary patterns

---

# 71. Self-Checking Testbench

file:

```text
tb/tb_spi_flash_xip.sv
```

---

# 72. Test 1 — SPI ID

expected:

```text
0x53504958
```

---

# 73. Test 2 — Default XIP Enable

expected:

```text
CONTROL=1
```

---

# 74. Test 3 — First Fetch

address:

```text
0x10000000
```

expected:

```text
0x200000B7
```

---

# 75. First Fetch Must Miss

test checks wait cycles are clearly non-zero

---

# 76. Test 4 — Same Address

fetch:

```text
0x10000000
```

again

must hit cache

---

# 77. Hit Timing

baseline test expects effectively immediate response

---

# 78. Test 5 — New Word

fetch:

```text
0x10000004
```

expected:

```text
0x01200113
```

and causes another miss

---

# 79. Counter Check

after sequence:

```text
hits=1
misses=2
```

---

# 80. Divider Test

write/read:

```text
DIVIDER=2
```

---

# 81. Disable XIP

set:

```text
CONTROL=0
```

---

# 82. Fetch While Disabled

must return:

```text
ready=1
error=1
```

not deadlock

---

# 83. Misaligned Fetch

address:

```text
0x10000002
```

must error

---

# 84. Out-of-Range Fetch

outside XIP window:

```text
error
```

---

# 85. Expected End

```text
PASS: Lab 18 SPI Flash / XIP integration completed.
```

---

# 86. Run Step 1

```bash
make check-env
```

---

# 87. Step 2

```bash
make check-contract
```

---

# 88. Step 3

```bash
make check-header
```

---

# 89. Step 4

```bash
make lint
```

---

# 90. Step 5

```bash
make sim
```

---

# 91. Step 6

```bash
make check-sim
```

---

# 92. Step 7

```bash
make yosys
```

optional

---

# 93. Step 8

```bash
make report
```

---

# 94. One Command

```bash
make all
```

---

# 95. Firmware Header

```text
firmware/include/osoc_spi_xip.h
```

---

# 96. Enable XIP

```c
osoc_spi_xip_enable(2);
```

---

# 97. Jump to XIP

example:

```text
firmware/examples/boot_to_xip.c
```

---

# 98. XIP Linker Script

```text
firmware/examples/xip_linker.ld
```

places:

```text
.text/.rodata in XIP
.data/.bss in SRAM
```

---

# 99. Why `.data` Needs Copy

initialized writable data cannot execute in place from read-only Flash

boot code must copy initial data image into SRAM before C runtime

---

# 100. Why `.bss` Is in SRAM

`.bss` must be zero-initialized writable memory

---

# 101. Production Bootloader Tasks

```text
stack init
.data copy
.bss clear
clock init
SPI init
flash verify
XIP enable
jump
```

---

# 102. FPGA/ASIC Simulation Note

this Lab uses behavioral Flash

real board testing needs a specific Flash part and its datasheet timing

---

# 103. SCK Frequency

do not guess maximum Flash SCK

set divider conservatively and verify against the actual selected device

---

# 104. Current Lab Divider

is a functional training value

not a production timing guarantee

---

# 105. SPI Pads

future full-chip:

```text
SPI_CS_N
SPI_SCK
SPI_MOSI
SPI_MISO
```

must map to IHP pads

---

# 106. Direction

```text
CS_N output
SCK output
MOSI output
MISO input
```

---

# 107. Package/Bond Plan Impact

adds four signal pads

plus board routing to Flash

---

# 108. Signal Integrity

high-speed SPI needs review of:

```text
trace length
return path
drive strength
slew
package parasitic
board termination if needed
```

---

# 109. Reset State

safe:

```text
CS_N high
SCK low
XIP controller idle
```

---

# 110. Flash Protection

production design may require:

```text
WP#
HOLD#/RESET#
```

depending part and mode

---

# 111. Quad SPI Future Pads

needs:

```text
IO0
IO1
IO2
IO3
CS#
SCK
```

---

# 112. XIP and Security

production boot may need:

```text
authenticated image
secure boot
anti-rollback
encryption
```

not implemented here

---

# 113. Why XIP Can Expose Code

external Flash contents are physically accessible on board/package interfaces

security architecture must consider this

---

# 114. Cache Coherency

read-only XIP avoids most coherency issues

---

# 115. If Flash Programming Is Added

cache must be invalidated after changing contents

---

# 116. Current Cache Invalidation

not software-exposed

reset or replacement updates entry

---

# 117. Recommended Future Register

```text
CACHE_INVALIDATE
```

---

# 118. Sequential Prefetch Future

when PC fetches address N:

```text
prefetch N+4
```

can hide latency for straight-line code

---

# 119. Branch Penalty

branch to uncached address creates new SPI miss

---

# 120. Performance Measurement

use:

```text
XIP_HITS
XIP_MISSES
```

to estimate code locality

---

# 121. Potential Instruction Cache Lab

natural extension:

```text
4-line direct-mapped cache
```

or:

```text
16-byte line buffer
```

---

# 122. XIP Error Policy

disabled/out-of-range/misaligned:

```text
ready=1
error=1
```

---

# 123. CPU Exception Future

instruction-side XIP error should eventually become:

```text
instruction access fault
```

---

# 124. Current CPU Lab

can expose/latch:

```text
imem_error
```

until full synchronous exception support is added

---

# 125. Interaction with PLIC

SPI XIP transfer itself does not need PLIC

---

# 126. SPI Peripheral IRQ Future

program/erase/RX/TX command mode may generate:

```text
SPI IRQ ID3
```

through PLIC

---

# 127. This Lab's SPI ID3

remains reserved conceptually for future software-command engine interrupt

---

# 128. Timing Path

MMIO path:

```text
CPU address
 -> SPI regs
 -> CPU
```

same-cycle

---

# 129. XIP Path

intentionally multi-cycle

not a normal STA single-cycle data path

---

# 130. Internal Byte Engine Timing

serial state machine is synchronous to system clock

---

# 131. Generated SCK

SCK is derived as an output signal from logic

it is not used as an internal ASIC clock domain

---

# 132. Why This Is Good

internal design remains one system clock domain

SPI SCK only leaves the chip

---

# 133. CDC on MISO?

MISO is sampled relative to generated SCK behavior but physically returns
asynchronous to system-clock edge due to external path delay

real timing closure requires board/package timing and input constraints

---

# 134. Training Model

behavioral Flash responds ideally to Mode-0 edges

---

# 135. STA Future

constrain:

```text
output delay SCK/MOSI/CS
input delay MISO relative to generated SPI timing
```

according to device datasheet

---

# 136. Pass Criteria — Serial Engine

```text
[ ] SCK idle low
[ ] MSB first
[ ] command 0x03
[ ] 24-bit address
[ ] four bytes received
```

---

# 137. Pass Criteria — XIP

```text
[ ] 0x10000000 fetch correct
[ ] first fetch miss
[ ] repeated fetch hit
[ ] new word miss
[ ] little-endian assembly correct
[ ] hit/miss counters correct
```

---

# 138. Pass Criteria — Errors

```text
[ ] disabled XIP errors
[ ] misaligned fetch errors
[ ] out-of-window errors
```

---

# 139. Pass Criteria — CPU Contract

```text
[ ] imem_stall generated
[ ] boot ROM path zero-wait
[ ] XIP path variable-wait
[ ] combined CPU stall documented
```

---

# 140. Freeze After Lab 18

```text
SPI MMIO base = 0x40002000
XIP base = 0x10000000
XIP size = 16 MiB

SPI mode0
MSB first
read command 0x03
24-bit Flash address

XIP miss stalls CPU
same-word cache hit can complete immediately
```

---

# 141. Recommended Next Lab

```text
Lab 19 — Full SoC Boot from SPI Flash
```

combine:

```text
Boot ROM
CPU
XIP
SRAM
GPIO
Timer
PLIC
CSR/Trap
```

and execute real firmware image from external Flash.

---

# 142. Engineering Rule

> External serial Flash is not a combinational instruction ROM.

and:

> Correct XIP design requires the processor's architectural commit logic to
tolerate variable instruction-fetch latency, not merely a working SPI pin-level
waveform.
