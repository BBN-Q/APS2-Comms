#MAC and IPv4 address are updated once so don't worry about CDC
set_false_path -through [get_pins aps2_comms_bd_inst/com5402_wrapper_0/mac_addr[*]]
set_false_path -through [get_pins aps2_comms_bd_inst/com5402_wrapper_0/IPv4_addr[*]]
