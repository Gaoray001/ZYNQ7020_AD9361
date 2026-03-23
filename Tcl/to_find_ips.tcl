set scripts_info [info script]
puts $scripts_info

set normalize_scripts_info [file normalize $scripts_info]
puts $normalize_scripts_info

set SCRIPT_DIR [file dirname $normalize_scripts_info]
puts $SCRIPT_DIR

set ROOT_DIR [file dirname $SCRIPT_DIR]
puts $ROOT_DIR

set RTL_DIR [file join $ROOT_DIR "Rtl"]
puts $RTL_DIR

set IP_DIR [file join $RTL_DIR "IP"]
puts $IP_DIR

set AD9361_IP_DIR [file join $IP_DIR "AD9361_IPS"]
puts $AD9361_IP_DIR


#### 遍历列表 添加文件


proc find_ips_files {dir} {
    # 创建空列表
    set result {}

    set all_item [glob -nocomplain -directory $dir *]

    foreach item $all_item {
        set is_dir [file isdirectory $item] 
        if {$is_dir==1} {
            set sub_result [find_ips_files $item]
            if { [llength $sub_result] >0} {
                set result [concat $result $sub_result]
            } 
        } else {
            set ext [file extension $item]
            if { $ext eq ".xcix"} {
                lappend result [file normalize $item]
            }
        }
    }
    return $result
}

set ips_files [find_ips_files $AD9361_IP_DIR]
foreach f $ips_files {
    puts "$f"
}
add_files $ips_files

