
#################################################################
## Top : Clock & Reset
#################################################################

# System clock
set_property PACKAGE_PIN K17 [get_ports g_clock_in]
set_property IOSTANDARD LVCMOS33 [get_ports g_clock_in]

create_clock -name g_clock_in -period 20.000 [get_ports g_clock_in]

