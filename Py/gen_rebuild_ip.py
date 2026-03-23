from pathlib import Path

ip_dir = Path("D:/ZYNQ7020_AD9361/Rtl/TCL_IPS/ip_tcl")
out_file = Path("D:/ZYNQ7020_AD9361/Rtl/TCL_IPS/rebuild_ips.tcl")

tcl_lines = []

tcl_lines.append("puts \"Rebuilding IPs...\"")
tcl_lines.append(f"set current_sript_dir  [file normalize [file dirname [info script]]]")
tcl_lines.append("")

for tcl_file in sorted(ip_dir.glob("*.tcl")):
    name = tcl_file.stem
    tcl_lines.append(f"puts \"Creating {name}\"")
    tcl_lines.append(f"source [file join $current_sript_dir/ip_tcl/{tcl_file.name}]")
    tcl_lines.append("")

tcl_lines.append("puts \"Generating targets...\"")
tcl_lines.append("")

for tcl_file in sorted(ip_dir.glob("*.tcl")):
    name = tcl_file.stem
    tcl_lines.append(f"generate_target all [get_ips {name}]")

out_file.write_text("\n".join(tcl_lines))

print("Generated rebuild_ips.tcl")
