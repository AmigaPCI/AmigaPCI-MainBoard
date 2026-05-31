# Define the external clock input (assuming this is a 40 MHz input clock)
create_clock -period  25.0000 [get_ports {CLK40_IN}]
create_clock -period 139.6648 [get_ports {CLK7}]
create_clock -period 279.3296 [get_ports {C1}]
create_clock -period 279.3296 [get_ports {C3}]

