## Data inputs - Push buttons

set_property PACKAGE_PIN D19 [get_ports d0]
set_property IOSTANDARD LVCMOS33 [get_ports d0]

set_property PACKAGE_PIN D20 [get_ports d1]
set_property IOSTANDARD LVCMOS33 [get_ports d1]

set_property PACKAGE_PIN L20 [get_ports d2]
set_property IOSTANDARD LVCMOS33 [get_ports d2]

set_property PACKAGE_PIN L19 [get_ports d3]
set_property IOSTANDARD LVCMOS33 [get_ports d3]


## Selection - Slide switches

set_property PACKAGE_PIN M20 [get_ports {s[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[0]}]

set_property PACKAGE_PIN M19 [get_ports {s[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[1]}]


## Output - LED0

set_property PACKAGE_PIN R14 [get_ports y]
set_property IOSTANDARD LVCMOS33 [get_ports y]