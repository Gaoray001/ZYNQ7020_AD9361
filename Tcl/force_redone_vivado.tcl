close_project

set scripts_info [info script]
puts $scripts_info
set normalize_scripts_info [file normalize $scripts_info]
puts $normalize_scripts_info 
set SCRIPT_DIR [file dirname $normalize_scripts_info]
puts $SCRIPT_DIR
set ROOT_DIR [file dirname $SCRIPT_DIR]
puts $ROOT_DIR

set Prj_DIR [file join $ROOT_DIR "Prj"]
puts $Prj_DIR

open_project $Prj_DIR/Prj.xpr

update_compile_order -fileset sources_1
catch {update_compile_order -fileset sim_1}
catch {update_compile_order -fileset constrs_1}
catch {reset_run synth_1}
catch {reset_run impl_1}


## 关闭并重新刷新
# close_project
# open_project C:/zynq7020_ad9361/Prj/Prj.xpr
# update_compile_order -fileset sources_1
# catch {update_compile_order -fileset sim_1}
# catch {update_compile_order -fileset constrs_1}
# catch {reset_run synth_1}
# catch {reset_run impl_1}