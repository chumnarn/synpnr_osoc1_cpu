# egs.sdc - Constraints for the demo design

# Create a 100MHz clock (10ns period)
create_clock -name core_clk -period 10.0 [get_ports clk]

# Constrain the inputs relative to the clock
set_input_delay  -clock core_clk 2.0 [get_ports {a b sel rst_n}]

# Constrain the outputs relative to the clock
set_output_delay -clock core_clk 2.0 [get_ports out_sync]
