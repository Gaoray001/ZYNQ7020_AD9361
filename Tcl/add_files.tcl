set SCRIPT_DIR [file dirname [file normalize [info script]]]
puts " add_file path : $SCRIPT_DIR"
set ROOT_DIR   [file dirname $SCRIPT_DIR]
puts "root_dir path:$ROOT_DIR"
set RTL_DIR    [file join $ROOT_DIR "Rtl"]
puts "rtl_dir path:$RTL_DIR"

set HDL_DIR  [file join $RTL_DIR "HDL"]
puts "hdl_dir path:$HDL_DIR"

# set AD9361_DIR [file join $HDL_DIR "AD9361"]
# puts "ad9361_path :$AD9361_DIR"

# 检查工程是否打开
set current_prj [current_project -quiet]
puts $current_prj

set status [llength $current_prj]
# puts "$status"

if {$status == 0} {
    error "NO vivado prj is open.please open_project first"
}

set status [file exists $HDL_DIR]
# puts $status
if { $status == 0 } {
    error " HDL dir does not exists:$HDL_DIR"
}

# 检查RTL目录是否存在
## 递归收集逻辑
proc find_verilog_files {dir} {
    # 创建空列表，用于装文件 注意python[]列表 python中是字典  tcl是列表 
    set result {}

    # 使用glob命令将dir目录下所有东西都抓出来
    set all_item [glob -nocomplain -directory $dir *]
    
    # 遍历抓出来的结果
    foreach item $all_item {
        
        # 判断文件是否是目录文件夹，如果是目录则存放于isdir变量中 isdirectory 是关键字吗？
        set isdir [file isdirectory $item] 
        # puts $isdir 

        if { $isdir == 1} {
            # 如果是目录文件夹，让函数再调用一次自己，进入$item里面抓一次
            set sub_result [find_verilog_files $item]
            # puts $sub_result
            # 如果再目录文件夹中找到了东西
            if { [llength $sub_result] >0 } {
                # 如果找到了东西，就使用concat将 sub_result 和 result 捆在一起
                set result [concat $result $sub_result]
            }
        } else {
            set ext [file extension $item]
            if {$ext eq ".v" || $ext eq ".sv"} {
                lappend result [file normalize $item]
            }
        }
    }
    return $result
}

set rtl_files [find_verilog_files $HDL_DIR]

# 打印收集到的文件
puts "find rtl files: [llength $rtl_files]"
foreach f $rtl_files {
    puts "$f"
}

add_files $rtl_files