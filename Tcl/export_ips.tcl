
# ./export_ips.tcl
set scripts_info [info script]
puts $scripts_info

# D:/ZYNQ7020_AD9361/Tcl/export_ips.tcl
set normalize_scripts_info [file normalize $scripts_info]
puts $normalize_scripts_info 

# D:/ZYNQ7020_AD9361/Tcl
set SCRIPT_DIR [file dirname $normalize_scripts_info]
puts $SCRIPT_DIR

# D:/ZYNQ7020_AD9361
set ROOT_DIR [file dirname $SCRIPT_DIR]
puts $ROOT_DIR

# D:/ZYNQ7020_AD9361/Rtl
set RTL_DIR [file join $ROOT_DIR "Rtl"]
puts $RTL_DIR

# D:/ZYNQ7020_AD9361/Rtl/IPS
set IPS_DIR [file join $RTL_DIR "TCL_IPS"]
puts $IPS_DIR

if { ![file exists $IPS_DIR] } {
    file mkdir $IPS_DIR
    if { ![file exists $IPS_DIR] } {
        error "Failed to create directory: $IPS_DIR"
    }
}


#### 遍历列表 添加IPS文件
# 创建ips列表 
set ips_tcl_list [get_ips]

# 遍历ips_tcl_list列表，获取每个ip的名字，并将其写入到IPS_DIR目录下的${ip}.tcl文件中
foreach ip $ips_tcl_list {

    set outfile [file join $IPS_DIR "${ip}.tcl"]

    puts "export ips tcl : $ip to $outfile"

    write_ip_tcl -force [get_ips $ip] $outfile
}



