set PROJ_NAME "Prj"
puts $PROJ_NAME
set PROJ_PORT "xc7z020clg400-2"

set scripts_info [info script]
puts $scripts_info

set normalize_scripts_info [file normalize $scripts_info]
puts $normalize_scripts_info

set SCRIPT_DIR [file dirname $normalize_scripts_info]
puts $SCRIPT_DIR

set ROOT_DIR [file dirname $SCRIPT_DIR]
puts $ROOT_DIR

set PROJ_DIR [file join $ROOT_DIR $PROJ_NAME]
puts "PROJ_DIR is $PROJ_DIR " 
 
set status [file exists $PROJ_DIR]
puts $status
if {!$status} {
    file mkdir $PROJ_DIR
    set status [file exists $PROJ_DIR] 
    puts $status
}

create_project $PROJ_NAME $PROJ_DIR -part $PROJ_PORT -force

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

puts "current project: [current_project]"
puts "project dir:[get_property DIRECTORY [current_project]]"
puts "project part:[get_property PART [current_project]]"
