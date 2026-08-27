# ==============================================================================
# Core Timing Constraints (SDC)
# ==============================================================================
# Define the main clock (100MHz = 10ns period) on port 'clk_i'
create_clock -name core_clk -period 10.0 [get_ports clk_i]

# Set basic I/O delays to define the timing boundaries of the chip
set_input_delay 2.0 -clock core_clk [all_inputs]
set_output_delay 2.0 -clock core_clk [all_outputs]

set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]
set_max_fanout 40 [current_design]
