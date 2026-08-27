sta [~/vlsi_projects/yosys_osoc1_cpu_core/work] history
    10  get_object_name [get_clocks *]
    11  report_clock_properties
    12  check_timing
    13  help *check*
    14  help *check*timing*
    15  help *check*
    16  check_timing -verbose
    17  check_setup
    18  check_setup -verbose
    19  check_setup -unconstrained_endpoints -verbose
    20  remove_clock core_clk
    21  help *remove*
    22  check_setup -verbose -unconstrained_endpoints
    23  report_timing
    24  report_check
    25  report_checks
    26  report_checks -path_delay max -format full
    27  report_checks -path_delay min -format full
    28  report_checks -path_delay max -fields {input_pins nets cap slew delay} -digits 4
    foreach port [all_inputs] {
    puts "Input port: [get_name $port]"
}

sta [~/vlsi_projects/yosys_osoc1_cpu_core/work] foreach port [all_inputs] {
    set dir [get_property $port direction]
    puts "Port [get_name $port] is of type: $dir"
}

foreach port [all_inputs] {
    set p_name [get_name $port]
    set p_dir  [get_property $port direction]
    puts "Input: $p_name is configured as: $p_dir"
}

# To get the direction:
get_property [get_ports {a[0]}] direction

# To get the capacitance:
get_property [get_ports {a[0]}] capacitance




