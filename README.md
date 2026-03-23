

### 目录树

```yaml
ZYNQ7020_AD9361/
├─ Doc/  # 笔记等随笔
│    
│
├─ Rtl/
│   ├─ HDL         
│   │	└─ *.v # FIR 主模块（可综合）
│   ├─ IP         
│   │	└─ *.xcix # ip核
│   ├─ CUSTOM_IP/         
│	│	└─ AXI_Lite_AD9361_Ctrl/  # Testbench（可直接跑仿真
│	│		├─ ip_repo/
│	│		│	└─ AXI_Lite_AD9361_Ctrl_0_1.0/
│	│		│		└─ component.xml
│	│		└─ managed_ip_project/
│   ├─ SIM /        
│	│	├─ *.v  # Testbench（可直接跑仿真
│	│	└─ *.sv  # Testbench（可直接跑仿真）
│	└─ XDC/
│		└─ *.xdc  # 约束文件
│
├─ Src/
│   └─ /*.c # zynq的硬件代码 
│
├─ Tcl/
│   ├─ /00_setup.tcl  
│   ├─ /01_create_empty_project.tcl  # vivado先运行此脚本创建空白工程
│   ├─ /02_import_sources.tcl  	     # vivado运行此脚本导入文件
│   └─ /*.tcl # 添加源码 
└─  others

```



 