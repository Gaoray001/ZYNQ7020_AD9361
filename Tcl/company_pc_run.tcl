# =========================================================
# Vivado Project Mode 实现脚本
# 用途：
#   1) 只跑布局布线
#   2) 跑布局布线并生成 bit
# 使用方法：
#   vivado -mode tcl
#   source run_impl.tcl
# =========================================================

# -----------------------------
# 线程与并行配置
# -----------------------------
set_param general.maxThreads 20
set jobs_num 20

# -----------------------------
# 功能开关
# 1 = 启用
# 0 = 不启用
# -----------------------------
set RUN_IMPL_ONLY 0        ;# 只跑到 route_design
set RUN_IMPL_AND_BIT 1     ;# 跑到 write_bitstream

# -----------------------------
# 可选：先重置实现运行
# 如果你想每次都从头开始，就改成 1
# 如果想尽量复用之前结果，就保持 0
# -----------------------------
set RESET_IMPL_RUN 1

# -----------------------------
# 检查开关配置是否合法
# 只能二选一
# -----------------------------
if {($RUN_IMPL_ONLY + $RUN_IMPL_AND_BIT) != 1} {
    puts "ERROR: RUN_IMPL_ONLY 和 RUN_IMPL_AND_BIT 必须二选一。"
    error "Invalid switch setting."
}

# -----------------------------
# 可选重置
# -----------------------------
if {$RESET_IMPL_RUN} {
    puts "INFO: reset_run impl_1"
    reset_run impl_1
}

# -----------------------------
# 运行实现
# -----------------------------
if {$RUN_IMPL_ONLY} {
    puts "INFO: 启动 impl_1，仅运行到 route_design ..."
    launch_runs impl_1 -to_step route_design -jobs $jobs_num
    wait_on_run impl_1
    puts "INFO: impl_1 已完成到 route_design"
}

if {$RUN_IMPL_AND_BIT} {
    puts "INFO: 启动 impl_1，运行到 write_bitstream ..."
    launch_runs impl_1 -to_step write_bitstream -jobs $jobs_num
    wait_on_run impl_1
    puts "INFO: impl_1 已完成，bitstream 已生成"
}

# -----------------------------
# 打印最终状态
# -----------------------------
puts "INFO: 当前 impl_1 状态："
puts [get_property STATUS [get_runs impl_1]]