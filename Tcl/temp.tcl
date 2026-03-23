# get_ips
# report_ip_status
# upgrade_ip [get_ips]
# generate_targe all [get_ips]
# export_ips_user_files -of_objects [get_ips] -no_script -no_script  -sync -force


get_ports i_rx_frame_in_p

get_nets -of_objects [get_ports i_rx_frame_in_p]

get_pins -of_objects [get_nets -of_objects [get_ports i_rx_frame_in_p]]

get_cells -of_objects [get_nets -of_objects [get_ports i_rx_frame_in_p]]