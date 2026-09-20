# Teaching target: verify the selected Liberty time unit is ns before use.
create_clock -name clk -period 10 [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_input_delay -clock clk -max 1.0 [get_ports {rst_n en}]
set_input_delay -clock clk -min 0.1 [get_ports {rst_n en}]
set_output_delay -clock clk -max 1.0 [get_ports {count*}]
set_output_delay -clock clk -min 0.1 [get_ports {count*}]
# Before acceptance add realistic input transition and output capacitance,
# using the library's units. rst_n is SYNCHRONOUS: do not false-path it.
