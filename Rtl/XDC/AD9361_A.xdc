#################################################################
## AD9361 SPI
#################################################################

set_property PACKAGE_PIN T10 [get_ports o_fmc_spi_clk]
set_property PACKAGE_PIN P18 [get_ports o_fmc_spi_cs_n]
set_property PACKAGE_PIN P15 [get_ports o_fmc_spi_mosi]
set_property PACKAGE_PIN T12 [get_ports i_fmc_spi_miso]

set_property IOSTANDARD LVCMOS25 [get_ports {o_fmc_spi_clk o_fmc_spi_cs_n o_fmc_spi_mosi i_fmc_spi_miso}]


#################################################################
## AD9361 Control GPIO
#################################################################

set_property PACKAGE_PIN T11 [get_ports o_gpio_resetb]
set_property IOSTANDARD LVCMOS25 [get_ports o_gpio_resetb]

set_property PACKAGE_PIN P16 [get_ports o_gpio_txnrx]
set_property IOSTANDARD LVCMOS25 [get_ports o_gpio_txnrx]

set_property PACKAGE_PIN N17 [get_ports o_gpio_enable]
set_property IOSTANDARD LVCMOS25 [get_ports o_gpio_enable]

set_property PACKAGE_PIN U13 [get_ports o_gpio_en_agc]
set_property IOSTANDARD LVCMOS25 [get_ports o_gpio_en_agc]

set_property PACKAGE_PIN V12 [get_ports {o_gpio_ctl[0]}]
set_property PACKAGE_PIN V13 [get_ports {o_gpio_ctl[1]}]
set_property PACKAGE_PIN W13 [get_ports {o_gpio_ctl[2]}]
set_property PACKAGE_PIN U12 [get_ports {o_gpio_ctl[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {o_gpio_ctl[0] o_gpio_ctl[1] o_gpio_ctl[2] o_gpio_ctl[3]}]


#################################################################
## AD9361 RX LVDS Interface
#################################################################

# RX CLK
set_property PACKAGE_PIN V16 [get_ports i_rx_clk_in_p]
# set_property PACKAGE_PIN <RX_CLK_N_PIN> [get_ports i_rx_clk_in_n]
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_AD9361_Top/u_axi_ad9361/i_dev_if/i_clk/clk_ibuf_s]
# RX FRAME
set_property PACKAGE_PIN T16 [get_ports i_rx_frame_in_p]
# set_property PACKAGE_PIN <RX_FRAME_N_PIN> [get_ports i_rx_frame_in_n]

# RX DATA[5:0]
set_property PACKAGE_PIN Y18 [get_ports {i_rx_data_in_p[0]}]
# set_property PACKAGE_PIN <RX_D0_N_PIN> [get_ports {i_rx_data_in_n[0]}]

set_property PACKAGE_PIN T20 [get_ports {i_rx_data_in_p[1]}]
# set_property PACKAGE_PIN <RX_D1_N_PIN> [get_ports {i_rx_data_in_n[1]}]

set_property PACKAGE_PIN U18 [get_ports {i_rx_data_in_p[2]}]
# set_property PACKAGE_PIN <RX_D2_N_PIN> [get_ports {i_rx_data_in_n[2]}]

set_property PACKAGE_PIN N20 [get_ports {i_rx_data_in_p[3]}]
# set_property PACKAGE_PIN <RX_D3_N_PIN> [get_ports {i_rx_data_in_n[3]}]

set_property PACKAGE_PIN V20 [get_ports {i_rx_data_in_p[4]}]
# set_property PACKAGE_PIN <RX_D4_N_PIN> [get_ports {i_rx_data_in_n[4]}]

set_property PACKAGE_PIN T17 [get_ports {i_rx_data_in_p[5]}]
# set_property PACKAGE_PIN <RX_D5_N_PIN> [get_ports {i_rx_data_in_n[5]}]

# RX LVDS electrical
set_property IOSTANDARD LVDS_25 [get_ports i_rx_clk_in_p]
set_property IOSTANDARD LVDS_25 [get_ports i_rx_clk_in_n]
set_property DIFF_TERM TRUE     [get_ports i_rx_clk_in_p]
set_property DIFF_TERM TRUE     [get_ports i_rx_clk_in_n]

set_property IOSTANDARD LVDS_25 [get_ports i_rx_frame_in_p]
set_property IOSTANDARD LVDS_25 [get_ports i_rx_frame_in_n]
set_property DIFF_TERM TRUE     [get_ports i_rx_frame_in_p]
set_property DIFF_TERM TRUE     [get_ports i_rx_frame_in_n]

set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[0] i_rx_data_in_n[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[1] i_rx_data_in_n[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[2] i_rx_data_in_n[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[3] i_rx_data_in_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[4] i_rx_data_in_n[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {i_rx_data_in_p[5] i_rx_data_in_n[5]}]

set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[0] i_rx_data_in_n[0]}]
set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[1] i_rx_data_in_n[1]}]
set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[2] i_rx_data_in_n[2]}]
set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[3] i_rx_data_in_n[3]}]
set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[4] i_rx_data_in_n[4]}]
set_property DIFF_TERM TRUE [get_ports {i_rx_data_in_p[5] i_rx_data_in_n[5]}]

# AD9361 RX interface clock
create_clock -name ad9361_rx_clk -period 6.250 [get_ports i_rx_clk_in_p]


#################################################################
## AD9361 TX LVDS Interface
#################################################################

# TX CLK
set_property PACKAGE_PIN R16 [get_ports o_tx_clk_out_p]
# set_property PACKAGE_PIN <TX_CLK_N_PIN> [get_ports o_tx_clk_out_n]

# TX FRAME
set_property PACKAGE_PIN N18 [get_ports o_tx_frame_out_p]
# set_property PACKAGE_PIN <TX_FRAME_N_PIN> [get_ports o_tx_frame_out_n]

# TX DATA[5:0]
set_property PACKAGE_PIN Y16 [get_ports {o_tx_data_out_p[0]}]
# set_property PACKAGE_PIN <TX_D0_N_PIN> [get_ports {o_tx_data_out_n[0]}]

set_property PACKAGE_PIN P14 [get_ports {o_tx_data_out_p[1]}]
# set_property PACKAGE_PIN <TX_D1_N_PIN> [get_ports {o_tx_data_out_n[1]}]

set_property PACKAGE_PIN U14 [get_ports {o_tx_data_out_p[2]}]
# set_property PACKAGE_PIN <TX_D2_N_PIN> [get_ports {o_tx_data_out_n[2]}]

set_property PACKAGE_PIN T14 [get_ports {o_tx_data_out_p[3]}]
# set_property PACKAGE_PIN <TX_D3_N_PIN> [get_ports {o_tx_data_out_n[3]}]

set_property PACKAGE_PIN W14 [get_ports {o_tx_data_out_p[4]}]
# set_property PACKAGE_PIN <TX_D4_N_PIN> [get_ports {o_tx_data_out_n[4]}]

set_property PACKAGE_PIN V15 [get_ports {o_tx_data_out_p[5]}]
# set_property PACKAGE_PIN <TX_D5_N_PIN> [get_ports {o_tx_data_out_n[5]}]

# TX LVDS electrical
set_property IOSTANDARD LVDS_25 [get_ports o_tx_clk_out_p]
set_property IOSTANDARD LVDS_25 [get_ports o_tx_clk_out_n]

set_property IOSTANDARD LVDS_25 [get_ports o_tx_frame_out_p]
set_property IOSTANDARD LVDS_25 [get_ports o_tx_frame_out_n]

set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[0] o_tx_data_out_n[0]}]
set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[1] o_tx_data_out_n[1]}]
set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[2] o_tx_data_out_n[2]}]
set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[3] o_tx_data_out_n[3]}]
set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[4] o_tx_data_out_n[4]}]
set_property IOSTANDARD LVDS_25 [get_ports {o_tx_data_out_p[5] o_tx_data_out_n[5]}]