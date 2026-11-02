## Input data - BTN0

set_property PACKAGE_PIN D19 [get_ports d]
set_property IOSTANDARD LVCMOS33 [get_ports d]


## Selection - SW0 / SW1

set_property PACKAGE_PIN M20 [get_ports {s[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[0]}]

set_property PACKAGE_PIN M19 [get_ports {s[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[1]}]


## Outputs - LED0..LED3

set_property PACKAGE_PIN R14 [get_ports y0]
set_property IOSTANDARD LVCMOS33 [get_ports y0]

set_property PACKAGE_PIN P14 [get_ports y1]
set_property IOSTANDARD LVCMOS33 [get_ports y1]

set_property PACKAGE_PIN N16 [get_ports y2]
set_property IOSTANDARD LVCMOS33 [get_ports y2]

set_property PACKAGE_PIN M14 [get_ports y3]
set_property IOSTANDARD LVCMOS33 [get_ports y3]