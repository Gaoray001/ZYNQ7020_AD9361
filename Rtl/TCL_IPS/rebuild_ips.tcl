puts "Rebuilding IPs..."

puts "Creating AD_CLK_PLL"
source ./ip_tcl/AD_CLK_PLL.tcl

puts "Creating cmpy_16X16"
source ./ip_tcl/cmpy_16X16.tcl

puts "Creating complexMult_IPCore"
source ./ip_tcl/complexMult_IPCore.tcl

puts "Creating DDS_16X16"
source ./ip_tcl/DDS_16X16.tcl

puts "Creating DIV_ATT"
source ./ip_tcl/DIV_ATT.tcl

puts "Creating div_calfreq"
source ./ip_tcl/div_calfreq.tcl

puts "Creating div_idendFreq"
source ./ip_tcl/div_idendFreq.tcl

puts "Creating FIFO_Data_Sync"
source ./ip_tcl/FIFO_Data_Sync.tcl

puts "Creating g_clock_mmcm"
source ./ip_tcl/g_clock_mmcm.tcl

puts "Creating ila_128Xbit"
source ./ip_tcl/ila_128Xbit.tcl

puts "Creating ila_64Xbit"
source ./ip_tcl/ila_64Xbit.tcl

puts "Creating Rx_ReSample_FIR_F2"
source ./ip_tcl/Rx_ReSample_FIR_F2.tcl

puts "Creating Rx_ReSample_FIR_F4_L1"
source ./ip_tcl/Rx_ReSample_FIR_F4_L1.tcl

puts "Creating Rx_ReSample_FIR_F4_L2"
source ./ip_tcl/Rx_ReSample_FIR_F4_L2.tcl

puts "Creating Rx_ReSample_FIR_F5"
source ./ip_tcl/Rx_ReSample_FIR_F5.tcl

puts "Creating Tx_ReSample_FIR_F2"
source ./ip_tcl/Tx_ReSample_FIR_F2.tcl

puts "Creating Tx_ReSample_FIR_F4_L1"
source ./ip_tcl/Tx_ReSample_FIR_F4_L1.tcl

puts "Creating Tx_ReSample_FIR_F4_L2"
source ./ip_tcl/Tx_ReSample_FIR_F4_L2.tcl

puts "Creating Tx_ReSample_FIR_F5"
source ./ip_tcl/Tx_ReSample_FIR_F5.tcl

puts "Creating vio_0"
source ./ip_tcl/vio_0.tcl

puts "Creating xfft_IPCore"
source ./ip_tcl/xfft_IPCore.tcl

puts "Generating targets..."

generate_target all [get_ips AD_CLK_PLL]
generate_target all [get_ips cmpy_16X16]
generate_target all [get_ips complexMult_IPCore]
generate_target all [get_ips DDS_16X16]
generate_target all [get_ips DIV_ATT]
generate_target all [get_ips div_calfreq]
generate_target all [get_ips div_idendFreq]
generate_target all [get_ips FIFO_Data_Sync]
generate_target all [get_ips g_clock_mmcm]
generate_target all [get_ips ila_128Xbit]
generate_target all [get_ips ila_64Xbit]
generate_target all [get_ips Rx_ReSample_FIR_F2]
generate_target all [get_ips Rx_ReSample_FIR_F4_L1]
generate_target all [get_ips Rx_ReSample_FIR_F4_L2]
generate_target all [get_ips Rx_ReSample_FIR_F5]
generate_target all [get_ips Tx_ReSample_FIR_F2]
generate_target all [get_ips Tx_ReSample_FIR_F4_L1]
generate_target all [get_ips Tx_ReSample_FIR_F4_L2]
generate_target all [get_ips Tx_ReSample_FIR_F5]
generate_target all [get_ips vio_0]
generate_target all [get_ips xfft_IPCore]