# F_DIR=0 B->A 
set_property PACKAGE_PIN T9 [get_ports F_DIR[0]]
set_property IOSTANDARD LVCMOS33 [get_ports F_DIR[0]]

set_property PACKAGE_PIN Y12 [get_ports rs232_uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_uart_rxd]

#  F_DIR=1 A->B 
set_property PACKAGE_PIN U10 [get_ports F_DIR[1]]
set_property IOSTANDARD LVCMOS33 [get_ports F_DIR[1]]

set_property PACKAGE_PIN T5 [get_ports rs232_uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports rs232_uart_txd]