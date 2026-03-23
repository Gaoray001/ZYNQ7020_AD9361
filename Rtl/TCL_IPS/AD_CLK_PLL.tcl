##################################################################
# CHECK VIVADO VERSION
##################################################################

# set scripts_vivado_version 2018.3
# set current_vivado_version [version -short]

# if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
#   catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an updated script."}
#   return 1
# }

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source AD_CLK_PLL.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./Prj/Prj.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  create_project Prj Prj -part xc7z020clg400-2
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:clk_wiz:6.0 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP AD_CLK_PLL
##################################################################

set clk_wiz AD_CLK_PLL
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name $clk_wiz

set_property -dict { 
  CONFIG.CLKOUT2_USED {true}
  CONFIG.CLKOUT3_USED {true}
  CONFIG.CLKOUT4_USED {true}
  CONFIG.CLKOUT5_USED {true}
  CONFIG.NUM_OUT_CLKS {5}
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {48.000}
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {10.000}
  CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {200.000}
  CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {50.000}
  CONFIG.RESET_PORT {resetn}
  CONFIG.MMCM_DIVCLK_DIVIDE {1}
  CONFIG.MMCM_CLKFBOUT_MULT_F {12.000}
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000}
  CONFIG.MMCM_CLKOUT1_DIVIDE {25}
  CONFIG.MMCM_CLKOUT2_DIVIDE {120}
  CONFIG.MMCM_CLKOUT3_DIVIDE {6}
  CONFIG.MMCM_CLKOUT4_DIVIDE {24}
  CONFIG.RESET_TYPE {ACTIVE_LOW}
  CONFIG.CLKOUT1_JITTER {115.831}
  CONFIG.CLKOUT1_PHASE_ERROR {87.180}
  CONFIG.CLKOUT2_JITTER {133.812}
  CONFIG.CLKOUT2_PHASE_ERROR {87.180}
  CONFIG.CLKOUT3_JITTER {188.586}
  CONFIG.CLKOUT3_PHASE_ERROR {87.180}
  CONFIG.CLKOUT4_JITTER {102.086}
  CONFIG.CLKOUT4_PHASE_ERROR {87.180}
  CONFIG.CLKOUT5_JITTER {132.683}
  CONFIG.CLKOUT5_PHASE_ERROR {87.180}
} [get_ips $clk_wiz]

##################################################################

