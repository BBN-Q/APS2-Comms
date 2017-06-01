# helper script to create build products and add verilog-axis and verilog-ethernet modules

set APS2_COMMS_SCRIPT_PATH [file normalize [info script]]
set APS2_COMMS_REPO_PATH [file dirname $APS2_COMMS_SCRIPT_PATH]/../

# on linux, expect python3k to be called "python3"
if { $tcl_platform(platform) == "unix"} {
	set python_cmd python3
} else {
	set python_cmd python
}

# create dependency outputs
set cur_dir [pwd]
cd $APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl
exec $python_cmd axis_mux.py --ports=3 --output=axis_mux_3.v
exec $python_cmd axis_arb_mux.py --ports=3 --output=axis_arb_mux_3.v
exec $python_cmd axis_demux.py --ports=2 --output=axis_demux_2.v

# patch demux because select is keyword in VHDL
set fp [open axis_demux_2.v r]
set demux [read $fp]
close $fp
regsub -all {select} $demux control demux
set fp [open axis_demux_2.v w]
puts -nonewline $fp $demux
close $fp

#import into project and then delete to avoid dirty submodule
import_files -norecurse -flat \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_demux_2.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_mux_3.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_arb_mux_3.v

file delete axis_demux_2.v axis_mux_3.v axis_arb_mux_3.v

cd $cur_dir

add_files -norecurse \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_adapter.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_srl_fifo.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_async_fifo.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_frame_fifo.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/axis_async_frame_fifo.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/arbiter.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-axis/rtl/priority_encoder.v

add_files -norecurse \
	$APS2_COMMS_REPO_PATH/deps/verilog-ethernet/rtl/eth_mac_1g_fifo.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-ethernet/rtl/eth_mac_1g.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-ethernet/rtl/eth_mac_1g_rx.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-ethernet/rtl/eth_mac_1g_tx.v \
	$APS2_COMMS_REPO_PATH/deps/verilog-ethernet/rtl/lfsr.v
