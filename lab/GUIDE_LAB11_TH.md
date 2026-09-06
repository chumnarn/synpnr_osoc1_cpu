# Lab 11 — O'SoC 1.0 System Bus
## Deep Step-by-Step Ready-to-Run Guide

**Target:** low-cost RV32I bare-metal SoC for Industrial Automation  
**Bus:** 32-bit address, 32-bit data, 4-bit byte strobes, single master


# 1. เป้าหมาย

สร้าง interconnect กลางระหว่าง CPU กับ ROM, SRAM, GPIO, TIMER, SPI, PLIC และ DEBUG โดย freeze address map และ bus contract ก่อนสร้าง peripheral จริง

# 2. ทำไมต้องมี Bus

point-to-point wiring ทำให้ decode กระจัดกระจาย เพิ่ม peripheral ยาก และ verification ยาก; bus ทำให้ทุก peripheral ใช้ protocol เดียวกัน

# 3. Architecture

```text
CPU/master
  | valid addr wdata wstrb
  v
O'SoC System Bus
  +-- ROM
  +-- SRAM
  +-- GPIO
  +-- TIMER
  +-- SPI
  +-- PLIC
  +-- DEBUG
```

# 4. Master Interface

request = `m_valid_i,m_addr_i,m_wdata_i,m_wstrb_i`; response = `m_rdata_o,m_ready_o,m_error_o`.

# 5. Read/Write Semantics

`m_wstrb_i==0` คือ read; non-zero คือ write. จึงต้องมี `m_valid_i` เพื่อแยก read transaction ออกจาก no transaction.

# 6. Byte Strobs

0001/0010/0100/1000 เลือก byte lane และ 1111 คือ word write; รองรับแนวคิด SB/SH/SW ใน RV32I.

# 7. Address Map

ROM 0x0000_0000/64KiB, SRAM 0x2000_0000/64KiB, peripherals เริ่ม 0x4000_0000 แบบ 4KiB windows.

# 8. Package

`osoc_bus_pkg.sv` รวม base/mask, slave enum และ `hit()` เพื่อมี source of truth เดียว.

# 9. Decode

ใช้ power-of-two mask decode; region ต้อง aligned และไม่ overlap.

# 10. Unmapped Access

ตอบ `ready=1,error=1,rdata=DEAD_BEEF` เพื่อไม่ให้ master hang และทำ debug deterministic.

# 11. ROM Protection

write ไป ROM ต้อง error ทันที; read ยัง forward ไป ROM slave.

# 12. Slave Contract

ทุก slave ใช้ valid/addr/wdata/wstrb และตอบ rdata/ready/error เหมือนกัน ทำให้แทน stub ด้วย peripheral จริงได้ง่าย.

# 13. Stub Strategy

Lab 11 ใช้ `osoc_bus_slave_stub` เพื่อพิสูจน์ interconnect โดยไม่ปน bug จาก SRAM/GPIO/TIMER implementation.

# 14. Step 1 Environment

รัน `make check-env`; ต้องมี python3 และ Verilator.

# 15. Step 2 Address Map

รัน `make check-map`; script ตรวจ alignment และ overlap.

# 16. Step 3 Contract

รัน `make check-contract`; ตรวจ valid/ready/error/strobes/sentinel.

# 17. Step 4 Lint

รัน `make lint`; top คือ `osoc_bus_demo_top`.

# 18. Step 5 Simulation

รัน `make sim`; test ทุก region, SRAM/GPIO write, ROM write error และ bad-address error.

# 19. Expected Simulation

ต้องจบด้วย `PASS: Lab 11 system bus decode/error/handshake tests completed.`

# 20. Optional Yosys

รัน `make yosys`; เป็น parser/hierarchy/check probe เท่านั้น. Flow ASIC จริงภายหลังใช้ LibreLane/Slang.

# 21. Full Run

`make all` สร้าง reports และ LAB11_REPORT.md.

# 22. CPU Integration

CPU ปัจจุบันมี `pc_o/instr_i` และ `dmem_*`; instruction side จะต่อ ROM โดยตรงก่อน ส่วน data sideต้องมี `osoc_cpu_bus_adapter`.

# 23. Why Adapter

อย่าแก้ CPU core ให้ผูกกับ bus; adapter รักษา CPU reusable และ isolate stall/read-valid semantics.

# 24. Read-valid Problem

`dmem_we_o==0` อย่างเดียวบอกไม่ได้ว่าเป็น read หรือ no transaction; Lab 12 ต้องหา/load-request signal จริงจาก LSU หรือเพิ่ม explicit request interface.

# 25. Wait States

`ready` มีไว้รองรับ synchronous SRAM/slow peripheral; master ต้องรอจน ready. Single-cycle CPU อาจต้อง stall controller.

# 26. Timing

combinational bus path = address decode + slave + response mux. ที่ 50MHz มักง่ายกว่า แต่เมื่อ SoC โตอาจต้อง pipeline/register.

# 27. Power

payload broadcast ไป slaves แต่ valid มีเฉพาะ selected slave; future low-power versionเพิ่ม local gating/clock gating ได้.

# 28. No Tri-state

internal ASIC bus ใช้ mux ไม่ใช้ tri-state เพื่อ synthesis/STA/PnR ที่ชัดเจน.

# 29. Software View

GPIO example: `#define GPIO_OUT (*(volatile uint32_t*)0x40000000)`; memory map จึงเป็น hardware/software contract.

# 30. Future GPIO Map

DATA_OUT +0x00, DATA_IN +0x04, DIR +0x08, SET +0x0C, CLR +0x10.

# 31. Future TIMER Map

COUNTER +0x00, COMPARE +0x04, CONTROL +0x08, STATUS +0x0C.

# 32. Future SPI Map

CTRL +0x00, STATUS +0x04, TXDATA +0x08, RXDATA +0x0C, CLKDIV +0x10.

# 33. Future PLIC

pending/enable/priority/claim-complete จะอยู่ใน 4KiB PLIC window.

# 34. Debug

JTAG TAP เป็น serial physical interface แต่ debug control/status สามารถมี MMIO window แยก.

# 35. Misalignment

Lab 11 ยังไม่ reject misaligned accesses; wordควร addr[1:0]=00, halfword addr[0]=0. จะเพิ่มใน CPU adapter/LSU policy ภายหลัง.

# 36. Assertions

advanced extension ควร assert onehot0 slave-valid, no-hit->ready&error, ROM write->error.

# 37. Synthesis Expectation

logicส่วนใหญ่เป็น comparators, AND/OR และ response mux; area ควรเล็กกว่า CPU/SRAM มาก.

# 38. Troubleshooting overlap

ถ้า check-map fail ให้แก้ address map ก่อน ไม่ใช้ decode priority เพื่อซ่อน overlap.

# 39. Troubleshooting hang

ถ้า selected slaveไม่ ready CPU จะรอ; stubตอบทันทีแต่ peripheralจริงอาจหลาย cycle.

# 40. Troubleshooting multiple valid

ต้องเป็น zero-or-one slave valid ต่อ transaction; ถ้ามากกว่าหนึ่งแสดง decode overlap/logic bug.

# 41. Pass Criteria

```text
[ ] map aligned/non-overlap
[ ] lint PASS
[ ] reads 7 regions PASS
[ ] SRAM/GPIO writes PASS
[ ] ROM write rejected
[ ] bad address returns ready+error+DEAD_BEEF
[ ] report generated
```

# 42. Deliverables

RTL 4 files, address_map.yaml, self-checking TB, check scripts, logs และ LAB11_REPORT.md.

# 43. Freeze

freeze master/slave contract, base addresses, byte-strobe meaning, ROM read-only policy และ error semantics.

# 44. Next Lab

Lab 12 — SRAM and Instruction Memory Integration: ROM/SRAMจริง, CPU adapter, wait-state/stall, firmware image.

# 45. Engineering Rule

Bus protocol ที่ดีต้องแยก no transaction ออกจาก read transaction และ bad address ต้อง fail deterministically แทนการ hang แบบไร้ข้อมูล.
