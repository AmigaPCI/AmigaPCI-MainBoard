create_clock -period  25.0000 [get_ports {CLK40_IN}]
create_clock -period  30.3030 [get_ports {CLK33_IN}]

#set_max_delay  -from [get_ports {CLK33_IN}]  -to [get_ports {FRAME_OUTn}] 4.00 
#set_output_delay  -clock [get_clocks {CLK33_IN}] -add_delay 8.00 [get_ports {FRAMEn}]