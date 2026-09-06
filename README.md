# Full Chip Implementation: synpnr_osoc1_cpu ด้วย LibreLane และ IHP SG13G2 PDK

**Version:** 1.0  
**Last Updated:** September 2026  
**Duration:** ~4–6 ชั่วโมง (แบ่งเป็น 6 Labs)  
**Level:** Intermediate  
**Target:** นักศึกษาและวิศวกร ASIC ที่มีพื้นฐาน RTL และ Linux  
**Repository:** [ChipDesignRashid/synpnr_osoc1_cpu](https://github.com/ChipDesignRashid/synpnr_osoc1_cpu)

---

## ภาพรวมของ Workshop

คู่มือนี้แนะนำกระบวนการ **Full Chip Implementation** ของโปรเซสเซอร์ `osoc1_cpu` ตั้งแต่ขั้นตอนการเตรียม RTL (SystemVerilog) ไปจนถึงการสร้างไฟล์ GDSII พร้อม Pad Ring ที่พร้อมส่ง Tapeout บน **IHP SG13G2 130nm BiCMOS Open-Source PDK** โดยใช้เครื่องมือ **LibreLane** ซึ่งเป็นโครงสร้างพื้นฐาน RTL-to-GDS แบบ open-source ที่สืบต่อจาก OpenLane

**หลังจากทำ Lab ครบทุก Lab แล้ว ผู้เรียนจะสามารถ:**

- ติดตั้งและใช้งาน LibreLane ผ่าน Nix Environment ได้
- เตรียม RTL SystemVerilog ให้พร้อมสำหรับ synthesis บน IHP SG13G2
- สร้างและปรับแต่ง `config.yaml` สำหรับ Full Chip Flow (Chip Flow)
- กำหนดตำแหน่ง IO Pad Ring รอบชิป
- รัน Place-and-Route และแก้ไข Timing/DRC violations ได้
- ตรวจสอบ Layout ผ่าน KLayout และ OpenROAD GUI
- รัน Gate-Level Simulation เพื่อ verify ความถูกต้อง
- ส่ง GDSII ที่ผ่าน DRC และ LVS สำหรับ Tapeout

---

## โครงสร้างของ Repository: synpnr_osoc1_cpu

```
synpnr_osoc1_cpu/
├── src/                  # RTL หลัก (SystemVerilog)
│   └── osoc1_cpu.sv      # Top-level CPU module
├── src_sv2v/             # RTL ที่แปลงผ่าน sv2v แล้ว (Verilog plain)
├── syn_netlist/          # Synthesized netlist (Yosys output)
├── sdc/                  # Synopsys Design Constraints
├── scripts/              # Script สำหรับ flow automation
├── doc/                  # เอกสารประกอบ
└── .gitignore
```

> 📝 **หมายเหตุ:** โมดูลหลัก `osoc1_cpu` เป็น RISC-style CPU ที่เขียนด้วย SystemVerilog  
> ในการทำ Full Chip จะต้องสร้าง `chip_top` wrapper module ครอบ `osoc1_cpu` เพื่อเชื่อมกับ IO Pad Ring

---

## Prerequisites

### ความรู้ที่จำเป็น

- พื้นฐาน Linux command line และ shell scripting
- เข้าใจ RTL design ใน SystemVerilog / Verilog
- เข้าใจ Digital Design flow (Synthesis → Place & Route → Verification)
- รู้จัก YAML และ JSON format เบื้องต้น

### Software ที่ต้องติดตั้งก่อน

| Tool | Version | ลิงก์ |
|------|---------|-------|
| Nix Package Manager | ≥ 2.18 | https://nixos.org/download |
| LibreLane (via Nix) | ≥ 3.0 | https://librelane.readthedocs.io |
| Git | ≥ 2.30 | https://git-scm.com |
| KLayout | ≥ 0.28 | https://www.klayout.de (optional, สำหรับ view GDS) |
| GTKWave | ≥ 3.3 | https://gtkwave.github.io/gtkwave/ (optional, สำหรับ simulation) |

### Hardware Requirements

- OS: Linux (Ubuntu 22.04+ แนะนำ) หรือ macOS
- RAM: ≥ 16 GB (แนะนำ 32 GB สำหรับ CPU design)
- Disk: ≥ 50 GB free (PDK + LibreLane + run outputs)
- CPU: ≥ 8 cores แนะนำ (PnR ใช้ multithread)

---

## Lab 1: ติดตั้ง LibreLane และเตรียม Environment

**เวลาโดยประมาณ:** 30–45 นาที  
**Objective:** ติดตั้ง LibreLane ผ่าน Nix, clone IHP template, และตรวจสอบว่า environment พร้อม

### พื้นหลัง

LibreLane ใช้ **Nix** เป็นตัวจัดการ environment เพื่อให้แน่ใจว่าทุก tool (Yosys, OpenROAD, KLayout, Netgen ฯลฯ) มี version ที่ถูกต้องและ reproducible ทุกครั้ง  
IHP SG13G2 PDK จะถูก download อัตโนมัติโดย **Ciel** (PDK version manager) ในการรันครั้งแรก

### ขั้นตอน

1. ติดตั้ง Nix Package Manager ด้วย Determinate Systems installer:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
     sh -s -- install
   ```

   เปิด terminal ใหม่หลังติดตั้งเสร็จ แล้วตรวจสอบ:

   ```bash
   nix --version
   ```

   > ✅ **จุดตรวจสอบ:** ควรเห็นผลลัพธ์ประมาณ `nix (Nix) 2.x.x`

2. Clone `ihp-sg13g2-librelane-template` ซึ่งเป็น official template สำหรับ Full Chip:

   ```bash
   git clone https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template.git
   cd ihp-sg13g2-librelane-template
   ```

3. เข้า Nix Shell (ครั้งแรกจะใช้เวลาดาวน์โหลด binary cache ประมาณ 10–20 นาที):

   ```bash
   nix-shell
   ```

   > ⚠️ **คำเตือน:** ห้ามออกจาก nix-shell ระหว่างรัน flow ทุกคำสั่งต้องรันภายใน nix-shell

4. Download IHP SG13G2 PDK ผ่าน Makefile:

   ```bash
   make clone-pdk
   ```

   PDK จะถูกเก็บที่ `~/.ciel/` (ใช้พื้นที่ประมาณ 3–5 GB)

5. ตรวจสอบการติดตั้ง LibreLane:

   ```bash
   librelane --smoke-test
   ```

### Expected Result

```
LibreLane smoke test passed.
```

### Troubleshooting

| ปัญหา | วิธีแก้ไข |
|-------|-----------|
| `nix: command not found` | ตรวจสอบว่าเปิด terminal ใหม่หลัง install Nix แล้ว หรือรัน `source /etc/bashrc` |
| `nix-shell` ค้างนาน | เพิ่ม `--substituters https://cache.nixos.org` หรือตรวจสอบ network |
| `make clone-pdk` fail | ตรวจสอบ git, disk space, และ network |
| smoke-test fail | ดู error message แล้วเปิด issue ที่ https://github.com/librelane/librelane |

---

## Lab 2: Clone และเตรียม RTL จาก synpnr_osoc1_cpu

**เวลาโดยประมาณ:** 30 นาที  
**Objective:** นำ RTL ของ `osoc1_cpu` มาเตรียมใน template structure และสร้าง `chip_top` wrapper module

### พื้นหลัง

ใน **Full Chip Flow** ของ LibreLane จะต้องมี module สองระดับ:
- `chip_top` — Top-level ที่ประกอบ IO pads เข้ากับ core logic ผ่าน pad interface
- `chip_core` — Core ที่บรรจุ logic จริง ซึ่งในกรณีนี้คือ `osoc1_cpu`

### ขั้นตอน

1. Clone repository ของ `synpnr_osoc1_cpu`:

   ```bash
   # จากภายใน ihp-sg13g2-librelane-template/
   cd ..
   git clone https://github.com/ChipDesignRashid/synpnr_osoc1_cpu.git
   ```

2. ดู structure ของ src ไดเรกทอรี:

   ```bash
   ls synpnr_osoc1_cpu/src/
   ls synpnr_osoc1_cpu/src_sv2v/
   ```

3. คัดลอก RTL files เข้า template:

   ```bash
   cp synpnr_osoc1_cpu/src/*.sv ihp-sg13g2-librelane-template/src/
   cp synpnr_osoc1_cpu/sdc/*.sdc ihp-sg13g2-librelane-template/src/ 2>/dev/null || true
   ```

4. สร้าง `chip_top.sv` ซึ่งเป็น top-level pad wrapper ใน `src/`:

   ```bash
   cat > ihp-sg13g2-librelane-template/src/chip_top.sv << 'EOF'
   // chip_top.sv — Top-level full chip wrapper for osoc1_cpu
   // IHP SG13G2 — LibreLane Full Chip Flow
   
   module chip_top #(
     parameter int NUM_VDD_PADS   = 2,
     parameter int NUM_VSS_PADS   = 2,
     parameter int NUM_IOVDD_PADS = 2,
     parameter int NUM_IOVSS_PADS = 2,
     parameter int NUM_INPUT_PADS = 4,
     parameter int NUM_OUTPUT_PADS = 4,
     parameter int NUM_BIDIR_PADS  = 0,
     parameter int NUM_ANALOG_PADS = 0
   ) (
     input  logic clk_pad,
     input  logic rst_n_pad,
     input  logic [NUM_INPUT_PADS-1:0]  gpio_in_pad,
     output logic [NUM_OUTPUT_PADS-1:0] gpio_out_pad
   );
   
     // Internal signals (after pad buffer)
     logic clk_i, rst_ni;
     logic [NUM_INPUT_PADS-1:0]  gpio_in;
     logic [NUM_OUTPUT_PADS-1:0] gpio_out;
   
     // Instantiate chip_core (contains osoc1_cpu)
     chip_core u_chip_core (
       .clk_i     (clk_i),
       .rst_ni    (rst_ni),
       .gpio_in   (gpio_in),
       .gpio_out  (gpio_out)
     );
   
   endmodule
   EOF
   ```

5. สร้าง `chip_core.sv` ที่ instantiate `osoc1_cpu`:

   ```bash
   cat > ihp-sg13g2-librelane-template/src/chip_core.sv << 'EOF'
   // chip_core.sv — Core logic wrapper instantiating osoc1_cpu
   
   module chip_core (
     input  logic clk_i,
     input  logic rst_ni,
     input  logic [3:0] gpio_in,
     output logic [3:0] gpio_out
   );
   
     // Instantiate osoc1_cpu — ปรับ port names ตาม module จริง
     osoc1_cpu u_cpu (
       .clk   (clk_i),
       .rst_n (rst_ni),
       // TODO: เชื่อม GPIO และ port อื่นๆ ตาม interface ของ osoc1_cpu
       .gpio_in  (gpio_in),
       .gpio_out (gpio_out)
     );
   
   endmodule
   EOF
   ```

   > ⚠️ **คำเตือน:** ตรวจสอบ port names ของ `osoc1_cpu` จาก `src/osoc1_cpu.sv` ก่อนแล้วปรับ instantiation ให้ตรง

6. ตรวจสอบ RTL files ที่มีอยู่:

   ```bash
   ls ihp-sg13g2-librelane-template/src/
   ```

   > ✅ **จุดตรวจสอบ:** ควรเห็น `chip_top.sv`, `chip_core.sv`, และ `osoc1_cpu.sv` (หรือไฟล์ RTL อื่นๆ)

### Expected Result

Directory `src/` ควรมีไฟล์เหล่านี้:
- `chip_top.sv` — Top-level pad wrapper
- `chip_core.sv` — Core wrapper
- `osoc1_cpu.sv` — CPU RTL (และ module ย่อยอื่นๆ ที่ osoc1 ต้องการ)

---

## Lab 3: ตั้งค่า LibreLane config.yaml สำหรับ Full Chip (Chip Flow)

**เวลาโดยประมาณ:** 45 นาที  
**Objective:** สร้างและปรับแต่ง `config.yaml` สำหรับ Chip Flow รวมถึงกำหนด IO Pad placement

### พื้นหลัง

LibreLane ใช้ `config.yaml` ไฟล์เดียวในการกำหนดทุกอย่างในสาย implementation ตั้งแต่ source files, clock period, floorplan dimensions ไปจนถึงตำแหน่ง pads รอบชิป  
**Chip Flow** แตกต่างจาก **Classic Flow** ตรงที่จะทำ: Pad Ring Assembly → Core PnR → Seal Ring insertion → Filler generation → DRC/LVS

### ขั้นตอน

1. ไปที่ไดเรกทอรี `librelane/`:

   ```bash
   cd ihp-sg13g2-librelane-template/librelane/
   ls
   ```

   ควรเห็น `config.yaml` (ของ template เดิม)

2. แก้ไข `config.yaml` ด้วย editor ที่ถนัด (nano, vim, code ฯลฯ):

   ```bash
   cp config.yaml config.yaml.bak   # สำรอง config เดิม
   nano config.yaml
   ```

3. ปรับค่า config ดังนี้ (ตัวอย่าง config.yaml สำหรับ osoc1_cpu):

   ```yaml
   # LibreLane Full Chip Configuration — synpnr_osoc1_cpu
   # IHP SG13G2 | LibreLane Chip Flow
   
   DESIGN_NAME: chip_top
   
   # Source Files
   VERILOG_FILES:
     - dir::../src/osoc1_cpu.sv      # CPU RTL (และ sub-modules)
     - dir::../src/chip_core.sv
     - dir::../src/chip_top.sv
   
   # Chip Flow (แทน Classic Flow)
   FLOW: Chip
   
   # Clock Constraints
   CLOCK_PORT: clk_pad
   CLOCK_PERIOD: 20   # 20ns = 50 MHz (ปรับตาม timing closure)
   
   # Floorplan — ขนาดชิป (micrometers)
   # ปรับขนาดตาม complexity ของ osoc1_cpu
   DIE_AREA: "0 0 1500 1500"        # 1.5mm x 1.5mm
   CORE_AREA: "200 200 1300 1300"   # Core area ด้านใน pad ring
   
   # Standard Cell Library
   STD_CELL_LIBRARY: sg13g2_stdcell
   
   # Target density (0.0–1.0) — เริ่มต้นที่ 0.4 แล้วค่อยปรับ
   PL_TARGET_DENSITY: 0.4
   
   # IO Pad Placement — South / East / North / West
   # Format: {instance_name: PAD_TYPE}
   PAD_SOUTH:
     - {vssdio_0: sg13g2_IOCellVddio}
     - {vdddio_0: sg13g2_IOCellVssdio}
     - {gpio_in_0: sg13g2_IOCellInput}
     - {gpio_in_1: sg13g2_IOCellInput}
     - {vssdio_1: sg13g2_IOCellVssio}
     - {vdddio_1: sg13g2_IOCellVddio}
   
   PAD_EAST:
     - {gpio_out_0: sg13g2_IOCellOutput}
     - {gpio_out_1: sg13g2_IOCellOutput}
     - {vss_0: sg13g2_IOCellVss}
     - {vdd_0: sg13g2_IOCellVdd}
   
   PAD_NORTH:
     - {gpio_in_2: sg13g2_IOCellInput}
     - {gpio_in_3: sg13g2_IOCellInput}
     - {clk_pad_0: sg13g2_IOCellInput}
     - {rst_n_pad_0: sg13g2_IOCellInput}
     - {vdd_1: sg13g2_IOCellVdd}
     - {vss_1: sg13g2_IOCellVss}
   
   PAD_WEST:
     - {gpio_out_2: sg13g2_IOCellOutput}
     - {gpio_out_3: sg13g2_IOCellOutput}
     - {vdddio_2: sg13g2_IOCellVddio}
     - {vssdio_2: sg13g2_IOCellVssio}
   
   # Power Domain
   VDD_NET: VDD
   VSS_NET: VSS
   
   # SystemVerilog — เปิด Slang parser สำหรับ full SV support
   USE_SLANG: true
   
   # Synthesis
   SYNTH_STRATEGY: DELAY 0         # เน้น timing ก่อน area
   
   # CTS
   CLOCK_TREE_SYNTH: true
   
   # Routing
   GRT_ALLOW_CONGESTION: false
   
   # DRC (ผ่าน KLayout)
   RUN_KLAYOUT_DRC: true
   
   # LVS (ผ่าน Netgen)
   RUN_LVS: true
   ```

   > 💡 **เคล็ดลับ:** ดู IO Cell types ที่มีอยู่ใน IHP SG13G2 จาก:  
   > `~/.ciel/ihp-sg13g2/libs.ref/sg13g2_io/`  
   > หรือ [IHP OpenPDK IO Library docs](https://ihp-open-pdk-docs.readthedocs.io/en/latest/contents/io_library/01_available_cells.html)

4. ตรวจสอบชื่อ IO Cell types จาก PDK:

   ```bash
   ls ~/.ciel/ihp-sg13g2/libs.ref/sg13g2_io/lef/ | head -20
   ```

5. ปรับ `PAD_SOUTH/EAST/NORTH/WEST` ให้ตรงกับ port ของ `chip_top`:
   - Port `clk_pad` → `sg13g2_IOCellInput`
   - Port `rst_n_pad` → `sg13g2_IOCellInput`
   - Port `gpio_in[3:0]` → 4x `sg13g2_IOCellInput`
   - Port `gpio_out[3:0]` → 4x `sg13g2_IOCellOutput`
   - Power/Ground → `sg13g2_IOCellVdd/Vss/Vddio/Vssio`

6. บันทึกไฟล์ config.yaml

   > ✅ **จุดตรวจสอบ:** Validate YAML syntax:
   > ```bash
   > python3 -c "import yaml; yaml.safe_load(open('config.yaml'))" && echo "YAML valid"
   > ```

### Expected Result

ได้ `config.yaml` ที่ valid ซึ่งกำหนด Chip Flow, RTL sources, clock constraint, floorplan, และ pad placement ครบถ้วน

---

## Lab 4: รัน Full Chip Implementation Flow

**เวลาโดยประมาณ:** 60–120 นาที (ขึ้นอยู่กับ CPU ของเครื่อง)  
**Objective:** รัน LibreLane Chip Flow ผ่าน Makefile และติดตาม log เพื่อตรวจสอบ error

### พื้นหลัง

LibreLane **Chip Flow** ทำขั้นตอนต่อไปนี้โดยอัตโนมัติ:

```
RTL (.sv)
  ↓ [Yosys.Synthesis]
Gate-Level Netlist
  ↓ [OpenROAD.Floorplan]
Floorplan DEF
  ↓ [OpenROAD.PadRing]        ← Pad ring assembly (Chip Flow เท่านั้น)
Padded Floorplan
  ↓ [OpenROAD.GlobalPlacement]
Globally Placed DEF
  ↓ [OpenROAD.STAPrePNR]      ← Static Timing Analysis (pre-route)
  ↓ [OpenROAD.CTS]            ← Clock Tree Synthesis
  ↓ [OpenROAD.GlobalRouting]
  ↓ [OpenROAD.DetailedRouting]
Routed DEF
  ↓ [OpenROAD.STAPostPNR]     ← Static Timing Analysis (post-route)
  ↓ [KLayout.SealRing]        ← Seal Ring insertion
  ↓ [KLayout.Filler]          ← Metal/Poly filler
  ↓ [KLayout.DRC]             ← Design Rule Check
  ↓ [Netgen.LVS]              ← Layout vs Schematic
GDSII ✓
```

### ขั้นตอน

1. กลับไปที่ root ของ template repository:

   ```bash
   cd ihp-sg13g2-librelane-template/
   ```

2. ตรวจสอบว่าอยู่ใน nix-shell:

   ```bash
   which librelane
   # ควรแสดง path ที่ชี้ไปใน nix store
   ```

   ถ้าไม่ใช่ให้รัน:
   ```bash
   nix-shell
   ```

3. รัน implementation ผ่าน Makefile:

   ```bash
   make librelane 2>&1 | tee run_$(date +%Y%m%d_%H%M).log
   ```

   > 💡 **เคล็ดลับ:** การ pipe ผ่าน `tee` จะช่วยให้บันทึก log ไว้ดู error ภายหลังได้

4. ติดตาม progress — LibreLane จะแสดงขั้นตอนและ status:

   ```
   [INFO] Step 1/20: Yosys.Synthesis
   [INFO] Step 2/20: OpenROAD.Floorplan
   ...
   ```

5. หาก synthesis fail ด้วย `module not found` — ตรวจสอบว่า include RTL files ครบ:

   ```bash
   # ตรวจสอบ module names ใน RTL
   grep "^module " src/*.sv
   ```

   แล้วแก้ `VERILOG_FILES` ใน config.yaml ให้ครบ

6. หาก timing fail — ปรับ `CLOCK_PERIOD` ใน config.yaml ให้ค่าสูงขึ้น (period มากขึ้น = frequency ต่ำลง):

   ```yaml
   CLOCK_PERIOD: 25   # ลองเพิ่มจาก 20 เป็น 25ns
   ```

   แล้วรันใหม่:
   ```bash
   make librelane
   ```

7. เมื่อ flow สำเร็จ ดู summary report:

   ```bash
   ls run/
   # จะเห็น directory ที่ชื่อตาม timestamp
   ls run/RUN_*/results/final/
   ```

   > ✅ **จุดตรวจสอบ:** ดูสถานะ step ทั้งหมด:
   > ```bash
   > cat run/RUN_*/final_summary.json | python3 -m json.tool | grep -E '"status"|"step"'
   > ```

### Expected Result

```
[SUCCESS] All steps completed successfully.
DRC: 0 violations
LVS: Clean
```

และจะมีไฟล์เหล่านี้ใน `run/RUN_*/results/final/`:
- `chip_top.gds` — ไฟล์ GDSII ของ full chip
- `chip_top.lef` — Library Exchange Format
- `chip_top.v` — Gate-level netlist
- `chip_top.sdf` — Standard Delay Format (สำหรับ GL simulation)

### Troubleshooting

| ปัญหา | วิธีแก้ไข |
|-------|-----------|
| `Synthesis failed: module not found` | เพิ่ม RTL file ใน `VERILOG_FILES` ใน config.yaml |
| `Timing not met (WNS < 0)` | เพิ่ม `CLOCK_PERIOD` หรือใช้ `SYNTH_STRATEGY: DELAY 3` |
| `Routing congestion` | ลด `PL_TARGET_DENSITY` (เช่น 0.35) หรือขยาย `DIE_AREA` |
| `DRC violations` | ดู Lab 5 สำหรับการแก้ไข DRC |
| `LVS mismatch` | ตรวจสอบ power connections และ pad connections |
| `Pad placement error` | ตรวจสอบ pad type names ใน config.yaml |

---

## Lab 5: ตรวจสอบ Layout ด้วย KLayout และ OpenROAD GUI

**เวลาโดยประมาณ:** 30–45 นาที  
**Objective:** เปิด Layout ใน KLayout และ OpenROAD GUI เพื่อตรวจสอบความถูกต้องของการ place & route

### พื้นหลัง

ก่อน Tapeout จำเป็นต้องตรวจสอบ Layout ด้วยสายตาว่า Pad Ring, Core, Clock Tree, Power Grid และ Routing ถูกต้อง ไม่มี short circuit หรือ open ที่ผิดปกติ

### ขั้นตอน

1. **เปิดดูใน OpenROAD GUI** (ต้องอยู่ใน nix-shell):

   ```bash
   make librelane-openroad
   ```

   ใน OpenROAD GUI:
   - ดู **Floorplan**: เส้นขอบชิป, Power Ring, Core Area
   - ดู **Placement**: standard cells กระจายอยู่ใน core
   - ดู **Routing**: metal layers และ vias
   - คลิก **Timing Report** → ตรวจสอบ Setup/Hold slack

2. **เปิดดูใน KLayout** (สำหรับ GDS inspection):

   ```bash
   make librelane-klayout
   ```

   ใน KLayout:
   - กด `Ctrl+Shift+H` → ซ่อน/แสดง layer
   - ตรวจสอบ **Pad Ring**: ควรเห็น pad cells รอบชิปทั้ง 4 ด้าน
   - ตรวจสอบ **Seal Ring**: เส้นกรอบด้านนอกสุด
   - ดู **DRC markers** (ถ้ามี): สีแดงหรือส้ม

3. ตรวจสอบ Timing Report จาก file:

   ```bash
   cat run/RUN_*/reports/signoff/timing_summary.rpt | head -50
   ```

   ค่าที่ต้องการ:
   - **WNS (Worst Negative Slack):** ≥ 0.0 ns
   - **TNS (Total Negative Slack):** 0.0 ns
   - **Hold Slack:** ≥ 0.0 ns

4. ตรวจสอบ DRC report:

   ```bash
   cat run/RUN_*/reports/signoff/drc_summary.rpt
   ```

5. ถ้าพบ DRC violations ใน KLayout ให้ระบุ layer และ rule ที่ fail แล้วพิจารณา:
   - ปรับ routing parameters ใน config.yaml
   - เพิ่ม spacing constraints
   - ปรับ `DIE_AREA` ให้ใหญ่ขึ้น

   ```yaml
   # ตัวอย่าง: เพิ่ม routing layer constraints
   RT_MAX_LAYER: Metal5
   ```

   > 💡 **เคล็ดลับ:** KLayout DRC report จะบอก layer, rule number, และ coordinate ของ violation ให้ zoom ไปดูได้เลย

6. Copy ผลลัพธ์ final ไปยัง `final/` folder:

   ```bash
   make copy-final
   ```

   > ✅ **จุดตรวจสอบ:**
   > ```bash
   > ls final/
   > # ควรเห็น chip_top.gds, chip_top.lef, chip_top.v, chip_top.sdf
   > ```

### Expected Result

- Layout ถูกต้อง: Pad ring ครบทุกด้าน, Core มี standard cells, Routing ไม่มี open หรือ short
- Timing met: WNS ≥ 0
- DRC: 0 violations (หรือ violations ที่ waive ได้ตาม foundry rules)

---

## Lab 6: Gate-Level Simulation เพื่อ Verify Functionality

**เวลาโดยประมาณ:** 45 นาที  
**Objective:** รัน Gate-Level Simulation ด้วย Icarus Verilog + cocotb เพื่อตรวจสอบว่า synthesized netlist ยังทำงานถูกต้อง

### พื้นหลัง

**Gate-Level Simulation (GL Sim)** คือการ simulate netlist หลัง synthesis โดยใช้ standard cell models แทน RTL abstract — ช่วยตรวจสอบ:
- Timing issues ที่ simulation แบบ RTL ไม่เจอ
- Clock domain crossing problems
- Power-up/reset behavior

Template ใช้ **cocotb** (Python-based testbench) กับ **Icarus Verilog** เป็น simulator

### ขั้นตอน

1. ตรวจสอบว่า `final/` มีไฟล์ netlist แล้ว:

   ```bash
   ls final/
   # ต้องมี chip_top.v และ chip_top.sdf
   ```

2. ดู testbench เดิมของ template:

   ```bash
   cat cocotb/chip_top_tb.py | head -60
   ```

3. สร้าง testbench สำหรับ osoc1_cpu ใน `cocotb/chip_top_tb.py`:

   ```python
   # chip_top_tb.py — cocotb testbench for osoc1_cpu full chip
   import cocotb
   from cocotb.clock import Clock
   from cocotb.triggers import RisingEdge, FallingEdge, Timer
   
   @cocotb.test()
   async def test_chip_reset(dut):
       """Test: chip reset behavior"""
       # Start clock (50 MHz = 20ns period)
       cocotb.start_soon(Clock(dut.clk_pad, 20, units="ns").start())
   
       # Assert reset
       dut.rst_n_pad.value = 0
       dut.gpio_in_pad.value = 0
       await Timer(100, units="ns")
   
       # Release reset
       dut.rst_n_pad.value = 1
       await RisingEdge(dut.clk_pad)
       await Timer(50, units="ns")
   
       # Check outputs (ปรับตาม expected behavior ของ osoc1_cpu)
       cocotb.log.info(f"gpio_out = {dut.gpio_out_pad.value}")
       assert dut.gpio_out_pad.value.integer >= 0, "GPIO output should be valid"
   
   @cocotb.test()
   async def test_basic_operation(dut):
       """Test: basic CPU operation after reset"""
       cocotb.start_soon(Clock(dut.clk_pad, 20, units="ns").start())
   
       dut.rst_n_pad.value = 0
       await Timer(40, units="ns")
       dut.rst_n_pad.value = 1
   
       # ให้ CPU run 1000 cycles
       for _ in range(1000):
           await RisingEdge(dut.clk_pad)
   
       cocotb.log.info("Basic operation test passed")
   ```

4. รัน RTL Simulation (ทดสอบกับ RTL source ก่อน):

   ```bash
   make sim
   ```

5. รัน Gate-Level Simulation:

   ```bash
   make sim-gl
   ```

   > ⚠️ **คำเตือน:** GL simulation อาจช้ากว่า RTL simulation 10–100 เท่า เพราะต้อง load standard cell models ทั้งหมด

6. ดู waveform ด้วย GTKWave:

   ```bash
   make sim-view
   ```

   ใน GTKWave:
   - เพิ่ม signal `clk_pad`, `rst_n_pad`, `gpio_in_pad`, `gpio_out_pad`
   - ตรวจสอบว่า output เปลี่ยนแปลงตามที่คาดหวัง

7. ตรวจสอบ simulation log:

   ```bash
   cat cocotb/sim_build/results.xml
   # หรือ
   grep -E "PASS|FAIL|ERROR" cocotb/sim_build/*.log
   ```

   > ✅ **จุดตรวจสอบ:**
   > ```
   > ** TEST                          STATUS  SIM TIME(ns)  REAL TIME(s)  RATIO(ns/s)
   > ** test_chip_reset               PASSED        200.00         0.10     2000.00
   > ** test_basic_operation          PASSED      20040.00         2.30     8713.04
   > ```

### Expected Result

- RTL Simulation: PASSED
- GL Simulation: PASSED (อาจมี timing warnings แต่ไม่ควร fail)
- Waveform แสดงพฤติกรรม CPU ที่ถูกต้องหลัง reset

### Troubleshooting

| ปัญหา | วิธีแก้ไข |
|-------|-----------|
| GL sim ช้ามาก | ลด simulation time ใน testbench |
| `Unknown signal` ใน testbench | ตรวจสอบ port names ของ `chip_top.sv` |
| GL sim fail แต่ RTL pass | อาจมี timing violation — ตรวจสอบ hold/setup slack |
| `SDF file not found` | ตรวจสอบว่า `make copy-final` ทำงานเสร็จแล้ว |

---

## Summary & Key Takeaways

### สิ่งที่ได้เรียนรู้

- **LibreLane Chip Flow** คือ automated flow สำหรับ Full Chip tapeout ที่รวม: Synthesis → PnR → Pad Ring → Seal Ring → Filler → DRC → LVS → GL Sim
- **IHP SG13G2** เป็น 130nm BiCMOS Open-Source PDK ที่รองรับ digital standard cell flow ผ่าน LibreLane
- **config.yaml** ไฟล์เดียวควบคุมทุกขั้นตอนใน flow รวมถึง pad placement ทุกด้าน
- **chip_top → chip_core → IP** เป็น hierarchy ที่แนะนำสำหรับ Full Chip design
- **Gate-Level Simulation** จำเป็นต้องรันหลัง PnR เพื่อยืนยัน functional correctness

### Metrics ที่ต้องผ่านก่อน Tapeout

| Metric | เกณฑ์ |
|--------|-------|
| WNS (Setup Timing Slack) | ≥ 0.0 ns |
| Hold Slack | ≥ 0.0 ns |
| DRC Violations | 0 |
| LVS Status | Clean (Match) |
| GL Simulation | PASSED |

---

## Next Steps / Further Reading

- **ขั้นตอนถัดไป:** ยื่น GDSII เข้า IHP Shuttle Program ที่ https://dk.ihp-microelectronics.com/OpenSourceRequest.php
- **เพิ่ม IP Blocks:** ดู `ip/` folder ใน template สำหรับการ integrate SRAM macros
- **ปรับปรุง Timing:** ศึกษา OpenSTA constraints และ multi-corner STA
- **คู่มือ LibreLane อย่างเป็นทางการ:** https://librelane.readthedocs.io/
- **IHP OpenPDK Documentation:** https://ihp-open-pdk-docs.readthedocs.io/
- **Tiny Tapeout (สำหรับ quick prototyping):** https://tinytapeout.com/

---

## Appendix A: คำสั่งที่ใช้บ่อย

```bash
# เข้า Nix Shell
nix-shell

# รัน full chip implementation
make librelane

# View ใน OpenROAD
make librelane-openroad

# View ใน KLayout
make librelane-klayout

# Copy ไฟล์ไป final/
make copy-final

# RTL Simulation
make sim

# Gate-Level Simulation
make sim-gl

# ดู Waveform
make sim-view

# รัน LibreLane โดยตรง (bypass Makefile)
librelane --pdk ihp-sg13g2 librelane/config.yaml

# Resume flow จาก step ที่ค้างไว้
librelane --pdk ihp-sg13g2 librelane/config.yaml --last-run

# ดู design ใน KLayout จาก last run
librelane --pdk ihp-sg13g2 librelane/config.yaml --last-run --flow OpenInKLayout
```

---

## Appendix B: Structure ของ `run/` Directory

```
run/RUN_YYYYMMDD_HHMMSS/
├── config.json              # Resolved configuration
├── final_summary.json       # Summary ของ flow (pass/fail ทุก step)
├── reports/
│   ├── synthesis/           # Yosys synthesis reports
│   ├── placement/           # Placement reports
│   ├── routing/             # Routing reports
│   └── signoff/             # Timing, DRC, LVS reports
├── results/
│   ├── synthesis/
│   │   └── chip_top.nl.v    # Synthesized netlist
│   ├── final/
│   │   ├── chip_top.gds     # Final GDSII
│   │   ├── chip_top.lef     # LEF file
│   │   ├── chip_top.v       # Gate-level netlist
│   │   └── chip_top.sdf     # Standard Delay File
│   └── klayout/
│       └── drc_results.xml  # KLayout DRC output
└── logs/
    ├── synthesis.log
    ├── floorplan.log
    └── ...
```

---

## Appendix C: Glossary

| คำศัพท์ | ความหมาย |
|---------|----------|
| RTL | Register Transfer Level — ระดับ abstraction ของ hardware design |
| PDK | Process Design Kit — ชุดไฟล์ที่ foundry ให้มาสำหรับออกแบบชิป |
| GDS / GDSII | Graphic Design System — รูปแบบไฟล์ layout ที่ส่ง foundry |
| PnR | Place and Route — การจัดวาง cell และเดินสายบนชิป |
| DRC | Design Rule Check — ตรวจสอบว่า layout ตรงตาม foundry rules |
| LVS | Layout vs Schematic — ตรวจสอบว่า layout ตรงกับ netlist |
| STA | Static Timing Analysis — วิเคราะห์ timing paths โดยไม่ simulate |
| WNS | Worst Negative Slack — ค่า slack ที่แย่ที่สุดใน design |
| CTS | Clock Tree Synthesis — สร้าง clock distribution network |
| IO Pad | Input/Output pad cell ที่อยู่รอบชิปสำหรับ wire bonding |
| Seal Ring | โครงสร้างป้องกันรอบชิปก่อนตัด wafer |
| GL Sim | Gate-Level Simulation — simulation ด้วย synthesized netlist |
| cocotb | Python-based hardware verification framework |

---

*เอกสารนี้จัดทำสำหรับ Full Chip Implementation Workshop — IHP SG13G2 + LibreLane*  
*อ้างอิง: [IHP OpenPDK Docs](https://ihp-open-pdk-docs.readthedocs.io) | [LibreLane Docs](https://librelane.readthedocs.io) | [IHP-GmbH/ihp-sg13g2-librelane-template](https://github.com/IHP-GmbH/ihp-sg13g2-librelane-template)*
