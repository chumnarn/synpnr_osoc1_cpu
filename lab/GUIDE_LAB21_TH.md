# Lab 21 — Full SoC Simulation
## Deep Step-by-Step Ready-to-Run Guide
### O'SoC 1.0 End-to-End Functional Regression

คู่มือนี้รวม Boot ROM, SPI Flash/XIP, SRAM, GPIO, Timer, PLIC, CSR/Trap และ
MRET เข้า regression เดียว

---

# 1. วัตถุประสงค์ของ Lab 21

Lab 21 เป็น system-level dynamic verification lab

เป้าหมายไม่ใช่แค่:

```text
module simulation
```

แต่ต้องพิสูจน์:

```text
boot
memory hierarchy
wait-state
external Flash
interrupt
trap
ISR
return
```

ใน regression เดียว

---

# 2. ตำแหน่งของ Lab ใน O'SoC roadmap

ลำดับก่อนหน้า:

```text
Lab 12 Memory
Lab 13 GPIO
Lab 14 Wait-state
Lab 15 Timer
Lab 16 PLIC
Lab 17 CSR/Trap
Lab 18 SPI XIP
Lab 19 Full SoC Boot
Lab 20 RTL-to-GDSII
```

Lab 21 รวม functional proof ให้เป็น regression ที่ทำซ้ำได้

---

# 3. ทำไมต้องมี Full-SoC simulation หลังมี physical flow

physical flowตรวจว่า layoutสร้างได้

ไม่ได้พิสูจน์ว่า:

```text
firmware boots
interrupt sequenceถูก
CSR stateถูก
GPIOถูก toggleจาก ISR
MRETกลับถูก PC
```

ดังนั้น functional simulationยังจำเป็น

---

# 4. Verification levels

Labแบ่งเป็น:

```text
Smoke
Full-SoC
Real-CPU extension
```

---

# 5. Smoke simulation

Smokeเน้น:
- reset
- PC activity
- no unknown PC
- basic module connectivity

รัน:

```bash
make smoke
```

---

# 6. Full-SoC simulation

รัน:

```bash
make full
```

ต้องพิสูจน์ entire boot + interrupt loop

---

# 7. Real CPU extension

standalone packageใช้ reference CPUเพื่อ runnable regression

production proofต้อง swapเป็น:

```text
osoc1_cpu_core_wait
```

ตาม:

```text
integration/REAL_CPU_SWAP.md
```

---

# 8. Reference CPU model คืออะไร

`osoc21_ref_cpu` เป็น small RV32I execution modelใน RTL

รองรับ subsetที่ firmwareใช้:
- LUI
- AUIPC
- ADDI/XORI/ORI/ANDI
- ADD/SUB/XOR/OR/AND
- LW/SW
- JAL/JALR
- BEQ/BNE
- CSR instructions
- MRET

มันมีไว้ verification isolation

---

# 9. Reference CPU ไม่ใช่ production CPU

PASS ด้วย reference modelหมายถึง:

```text
SoC architecture + peripheral + memory + interrupt contract
```

ผ่าน

แต่ยังไม่แทน real CPU regression

---

# 10. Reset vector

freeze:

```text
0x00000000
```

---

# 11. Boot ROM

Boot ROM contains:

```text
LUI x1,0x10000
JALR x0,0(x1)
```

ทำให้ CPU jumpไป:

```text
0x10000000
```

---

# 12. Trap vector placement

ISRอยู่ใน Boot ROMที่:

```text
0x00000100
```

XIP firmwareเขียน:

```text
mtvec=0x100
```

---

# 13. XIP firmware

XIP code:
1. set mtvec
2. enable MEIE
3. enable global MIE
4. configure Timer
5. loop

interrupt handlerอยู่ใน internal ROM

---

# 14. เหตุผลที่ ISR อยู่ internal ROM

ทำให้ trap entryไม่ต้องพึ่ง XIP latencyทันที

และช่วย debug:
- trap correctness
- Flash-independent handler

---

# 15. Instruction memory architecture

```text
PC < 0x1000 -> Boot ROM
0x10000000..0x10ffffff -> XIP
```

---

# 16. Instruction wait-state

XIP miss:

```text
imem_ready=0
imem_stall=1
```

CPU hold architectural progressจน instructionมา

---

# 17. Data wait-state

SRAM modelใช้ one-cycle registered response

ดังนั้น:

```text
dmem_stall
```

ถูก exerciseจริง

---

# 18. Combined CPU stall

```text
cpu_stall =
    imem_stall |
    dmem_stall
```

เป็น architecture freezeจาก Labs 14/18

---

# 19. Precise interrupt

external interruptต้องไม่ถูก takeระหว่าง:
- instruction fetch wait
- data access wait

reference CPUรับ interruptเฉพาะ execution boundary

---

# 20. Boot sequence

```text
Reset
PC=0
Boot ROM
JALR
PC=0x10000000
```

---

# 21. First XIP fetch

first instruction at XIP:
- cache miss
- CS# low
- command 0x03
- 24-bit address
- 4 data bytes
- ready

---

# 22. SPI mode

```text
Mode 0
CPOL=0
CPHA=0
MSB first
```

---

# 23. Flash image format

`xip_flash.hex` เป็น byte-per-line

CPU RV32 wordsถูกแปลง little-endianลง Flash

---

# 24. Why byte-level model

เพื่อทดสอบ:
- serial byte order
- address
- word assembly
ไม่ใช่ shortcut 32-bit memory read

---

# 25. XIP hit/miss counters

debug outputs:

```text
dbg_xip_hits
dbg_xip_misses
```

full test require:

```text
misses >= 2
```

---

# 26. Timer programming

firmwareตั้ง:

```text
COMPARE=3
PRESCALE=0
CONTROL=7
```

เพื่อ simulationเร็ว

---

# 27. CONTROL=7

bits:

```text
ENABLE=1
PERIODIC=1
IRQ_EN=1
```

---

# 28. Timer event

เมื่อ compare:
```text
irq_pending=1
timer_irq=1
```

---

# 29. PLIC source map

```text
1 GPIO
2 Timer
3 SPI
```

Timer source2

---

# 30. PLIC default policy

reference simulation sets:

```text
priority Timer=5
enable Timer=1
threshold=0
```

---

# 31. Target IRQ

when Timer eligible:

```text
cpu_ext_irq=1
```

---

# 32. CSR enable chain

trap eligibleต้องมี:

```text
cpu_ext_irq
mie.MEIE
mstatus.MIE
```

---

# 33. MCAUSE

machine external:

```text
0x8000000B
```

---

# 34. Trap entry

reference CPU:
- save MEPC
- save cause
- MPIE<-MIE
- MIE<-0
- PC<-mtvec

---

# 35. ISR first action

ISR clears Timer pending:

```text
sw 1,TIMER_STATUS
```

ก่อน PLIC complete

---

# 36. Why clear peripheral first

Timer IRQเป็น level-sensitive

completeก่อน clearอาจ re-pendทันที

---

# 37. PLIC claim

ISR reads:

```text
0x4000310C
```

expected ID2

---

# 38. GPIO toggle

ISR:
```text
read GPIO
XORI bit0
write GPIO
```

expected final:

```text
GPIO0=1
```

---

# 39. PLIC complete

ISR writes claimed IDกลับ claim/complete

---

# 40. MRET

encoding:

```text
0x30200073
```

must restore PC to MEPC

---

# 41. Return-to-XIP proof

testbench requires:
- trap observed
- MRET count >0
- PC laterอยู่ XIP region

---

# 42. Full test pass signature

```text
PASS: Lab 21 Full SoC simulation completed.
```

---

# 43. Watchdog

full simulation จำกัด:

```text
20000 cycles
```

หากไม่ถึง pass conditionจะ fail

---

# 44. Environment

```bash
make check-env
```

required:
```text
python3
verilator
make
```

---

# 45. Firmware image check

```bash
make check-images
```

ตรวจ:
- Boot JALR
- MRET at mtvec
- Flash non-empty
- first XIP words

---

# 46. Contract check

```bash
make check-contract
```

ตรวจว่า architecture filesมี:
- Boot ROM
- XIP
- SRAM
- GPIO
- Timer
- PLIC
- MRET
- stalls
- full TB assertions

---

# 47. Lint

```bash
make lint
```

---

# 48. Smoke build

```bash
make smoke
```

สร้าง Verilator binaryแยกจาก full test

---

# 49. Full build

```bash
make full
```

---

# 50. Parse full log

```bash
make check-full
```

extract:
- cycles
- GPIO
- XIP hits/misses
- trap/mret counts
- mcause/mepc

---

# 51. Report

```bash
make report
```

output:

```text
reports/LAB21_REPORT.md
```

---

# 52. One-command regression

```bash
make all
```

---

# 53. Expected report files

```text
00_environment.log
01_images.txt
02_contract.txt
03_lint.log
04_smoke_build.log
04_smoke.log
05_full_build.log
05_full.log
06_full_check.txt
LAB21_REPORT.md
```

---

# 54. Waveform FST

```bash
make wave
```

output:

```text
waves/lab21_full_soc.fst
```

---

# 55. Waveform VCD

```bash
make wave-vcd
```

---

# 56. Why FST preferred

FST usuallyเล็กกว่า VCDสำหรับ long SoC waveforms

---

# 57. Recommended signal list

ดู:

```text
config/signal_watchlist.txt
```

---

# 58. XIP waveform correlation

ดู:
```text
PC
imem_stall
CS#
SCK
MOSI
MISO
```

ต้องเห็น stallสัมพันธ์กับ serial transaction

---

# 59. Timer waveform correlation

```text
timer_irq
plic_pending[2]
cpu_ext_irq
```

---

# 60. Trap waveform correlation

```text
trap_enter
pc
mepc
mcause
MIE
MEIE
```

---

# 61. Return waveform

หลัง MRET:
```text
PCกลับ XIP
MIE restore
GPIO0=1
```

---

# 62. Debug: PC stuck at zero

ตรวจ:
- reset release
- bootrom loaded
- FETCH ready

---

# 63. Debug: jump target wrong

ตรวจ encoding:
```text
LUI x1,0x10000
JALR x0,0(x1)
```

---

# 64. Debug: XIP hangs

ตรวจ:
- CS#
- SCK
- MOSI command
- flash state
- byte_done
- XIP FSM

---

# 65. Debug: XIP word wrong

ตรวจ:
- address offset
- little-endian byte assembly
- MISO sample edge

---

# 66. Debug: SRAM wait never ends

ตรวจ:
- pending_q
- valid held
- ready pulse
- CPU DWAIT state

---

# 67. Debug: Timer never fires

ตรวจ:
- control
- compare
- prescale
- count
- irq_pending

---

# 68. Debug: PLIC no target

ตรวจ:
- pending2
- enable2
- priority2
- threshold

---

# 69. Debug: no trap

ตรวจ:
- cpu_ext_irq
- MIE
- MEIE
- CPU state
- stall

---

# 70. Debug: trap loops

root causeมักเป็น Timer pendingยัง high

---

# 71. Debug: wrong MCAUSE

external interruptต้อง:

```text
0x8000000B
```

---

# 72. Debug: MRET wrong PC

ตรวจ saved MEPC และ interrupt boundary

---

# 73. Unknown/X checks

Smokeตรวจ PC unknown

สามารถเพิ่ม assertionsสำหรับ:
- bus address
- GPIO
- CSR
- state machines

---

# 74. Why not use only waveform inspection

waveformเหมาะ debug

regressionต้อง self-checking

---

# 75. Why not use only final GPIO

GPIO toggleอย่างเดียวไม่พิสูจน์:
- XIPจริง
- trap cause
- MRET
- PLIC ownership

---

# 76. Scoreboard philosophy

Labใช้ milestone checks:
- entered XIP
- trap count
- MRET count
- final GPIO
- XIP misses
- mcause

---

# 77. Functional coverage future

เพิ่ม:
- all PLIC priorities
- threshold cases
- simultaneous IRQ
- SRAM byte strobes
- branch paths
- XIP cache hits

---

# 78. Assertions future

เพิ่ม SVA:
```text
stall -> stable PC
trap -> mcause valid
MRET -> next PC=mepc
claim -> in_service
```

---

# 79. Randomization future

สามารถ randomize:
- SRAM response delay
- SPI divider
- interrupt timing
- reset release timing

---

# 80. Why random wait-state matters

ช่วยจับ assumptionว่า ready always fixed latency

---

# 81. Real CPU swap

```bash
make REPO_ROOT=/path/... real-cpu-preflight
```

---

# 82. Real CPU source prerequisite

ตรวจ canonical repo source filesก่อน

---

# 83. Simulation contract to preserve

real CPUต้องมี instruction/data handshakeหรือ adapterที่ให้ semanticsเท่ากัน

---

# 84. Real CPU interrupt path

ต้องใช้ Lab17 CSR/trapจริง

reference CPUผ่านไม่แทน real CPU CSR implementation

---

# 85. Real CPU boot proof

ต้องเห็น PC sequenceจริง:
```text
0x00000000
0x10000000
0x00000100
กลับ 0x1000....
```

---

# 86. Real CPU RF proof

ควรเพิ่ม monitor register writesโดยเฉพาะ:
- stack
- temp regs
- CSR result

---

# 87. Real CPU SRAM proof

ควรให้ firmwareใช้:
- stack
- .data/.bss
ไม่ใช่เพียง MMIO

---

# 88. Real CPU XIP performance

reference modelทำ one-instruction-at-a-time

real CPUอาจมี fetch behaviorต่าง ต้อง verify request hold semantics

---

# 89. Real CPU trap precision

interruptระหว่าง data stallต้องไม่ commit half instruction

---

# 90. Post-layout GLS relation

Lab21เป็น RTL full-SoC simulation

Lab20 signoffสามารถเพิ่ม:
```text
gate-level functional simulation
```

แต่ GLSไม่แทน STA/LVS/DRC

---

# 91. SDF relation

optional SDF simulationอาจใช้ตรวจ timing behavior

OpenROAD STAยังเป็น timing authorityหลัก

---

# 92. Regression before physical rerun

ทุก RTL changeควร:
```text
make all
```
ก่อน LibreLane full flow

---

# 93. Regression after ECO

หลัง functional ECO:
- rerun Lab21
- rerun synthesis/Formal/GLSตาม scope
- rerun impacted physical stages

---

# 94. Versioned firmware images

เก็บ:
- source assembly
- generated hex
- checksum
ใน releaseเดียวกัน

---

# 95. Current handcrafted image

Labมีทั้ง:
```text
bootrom.S
bootrom.hex
main.S
xip_flash.hex
```

ทำให้ไม่บังคับ RISC-V toolchainเพื่อรัน baseline

---

# 96. Why include source and prebuilt image

sourceช่วยเรียน

prebuilt imageทำ regression reproducibleแม้ toolchainไม่มี

---

# 97. Optional rebuild with toolchain

เมื่อมี:
```text
riscv64-unknown-elf-gcc
objcopy
```

สามารถเพิ่ม make target rebuild firmware

---

# 98. Address map freeze

```text
Boot  0x00000000
XIP   0x10000000
SRAM  0x20000000
GPIO  0x40000000
Timer 0x40001000
SPI   0x40002000
PLIC  0x40003000
```

---

# 99. IRQ IDs freeze

```text
GPIO=1
Timer=2
SPI=3
```

---

# 100. CSR freeze

```text
mstatus.MIE bit3
mie.MEIE bit11
mip.MEIP bit11
mtvec
mepc
mcause
MRET
```

---

# 101. Machine external cause freeze

```text
11
0x8000000B
```

---

# 102. Simulation timing unit

clock:
```text
20 ns
50 MHz
```

---

# 103. Fast Timer values are simulation-only

Compare=3/Prescale=0มีไว้ shorten regression

firmware productค่าอื่นได้

---

# 104. SPI Flash model is idealized

ไม่ได้ model:
- tCL/tCH
- setup/hold board delays
- power-up time
- command busy

---

# 105. Hardware validation later

ต้องใช้ actual Flash datasheetและ board constraints

---

# 106. Simulation pass is not silicon pass

Lab21พิสูจน์ functional modelภายใต้ assumptions

---

# 107. Smoke pass criteria

```text
reset releases
PC advances
PC no X
```

---

# 108. Full pass criteria

```text
entered XIP
>=2 XIP misses
trap >=1
MRET >=1
mcause correct
GPIO0=1
return to XIP
```

---

# 109. Real CPU pass criteria

ทุก full criteriaต้องผ่านโดยไม่มี `osoc21_ref_cpu`ใน DUT

---

# 110. Recommended command sequence

```bash
make clean
make check-env
make check-images
make check-contract
make lint
make smoke
make full
make check-full
make report
make wave
```

---

# 111. Artifacts to archive

```text
reports/LAB21_REPORT.md
reports/05_full.log
waves/lab21_full_soc.fst
firmware images
RTL revision
testbench revision
```

---

# 112. CI integration

CIขั้นต่ำ:

```bash
make check-images
make check-contract
make lint
make full
make check-full
```

---

# 113. Failure policy

หาก full test fail:
- เก็บ log
- เก็บ waveform
- fix root cause
- rerun full test

ห้ามเปลี่ยน expected valueเพื่อให้ testผ่านโดยไม่มี architectural decision

---

# 114. Next Lab

หลัง Lab21เหมาะต่อด้วย:
```text
Lab22 Post-Layout Gate-Level / SDF Simulation
```
หรือ:
```text
Lab22 DFT/Scan/MBIST
```

---

# 115. Engineering rule

> A full-SoC simulation is useful only when it proves architectural milestones,
not merely that the simulator ran for N cycles.

และ:

> The production CPU must eventually pass the same end-to-end regression that
the reference integration model passes.
