create_clock -period  25.0000 [get_ports {CLK40_IN}]
create_clock -period  30.3030 [get_ports {CLK33_IN}]
create_clock -name CLK80 -period 12.5 [get_nets CLK80]
create_clock -name CLK66 -period 15.1515 [get_nets CLK66]
