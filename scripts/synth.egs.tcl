#yosys -l my_synthesis.log
#yosys -l my_synthesis.log -c my_script.tcl
#yosys> tee -o timing_report.txt sta

#set env(MODULE) "rf_wb_mux"

# 1. Load the flattened Verilog file
# We reference the environment variable directly using the $::env syntax
read_verilog ../src_sv2v/egs.v

# 2. Set the top-level module
hierarchy -check -top egs

# 3. Behavioral to Structural conversion
proc

# 4. Aggressive Global Optimization (DO THIS HERE)
# This cleans up the massive $mux structures created by the case statement
opt -full

# 5. Bit-blasting
techmap
#select -count c:*
#select -list p:*

opt_clean

# 6. Logic Minimization and Mapping to Silicon
abc -liberty /home/rashid/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

opt_clean

# 6b. Sequential mapping to technology
dfflibmap -liberty /home/rashid/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 7. Final Cleanup (Standard sweep, not -full)
opt_clean

# 8. Report Area
stat -liberty /home/rashid/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 9. Write the clean, structural netlist
write_verilog -noattr -noexpr ../syn_netlist/egs.syn.sky130.vg


