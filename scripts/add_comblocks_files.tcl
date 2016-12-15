# helper scripts to patch CombBlock modules and add to current project

set APS2_COMMS_SCRIPT_PATH [file normalize [info script]]
set APS2_COMMS_REPO_PATH [file dirname $APS2_COMMS_SCRIPT_PATH]/../

set cur_dir [pwd]

# patch the Com5402 module for UDP broadcast issue and add DHCP module
cd $APS2_COMMS_REPO_PATH/deps/ComBlock/5402
file copy -force com5402.vhd com5402.backup
# on Windows look for Github git
if { $tcl_platform(platform) == "windows"} {
	set git_cmd [glob ~/AppData/Local/GitHub/PortableGit*/cmd/git.exe]
} else {
	set git_cmd git
}
# ignore whitespace warnings - seems a little dangerous
exec -ignorestderr $git_cmd apply --directory=deps/ComBlock/5402 com5402_dhcp.patch
file copy -force com5402.backup com5402.vhd
cd $cur_dir

add_files -norecurse \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/arp_cache2.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/arp.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/bram_dp2.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/com5402_dhcp.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/com5402pkg.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/dhcp_client.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/igmp_query.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/igmp_report.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/packet_parsing.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/ping.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/tcp_rxbufndemux2.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/tcp_server.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/tcp_txbuf.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/tcp_tx.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/timer_4us.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/udp_rx.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/udp_tx.vhd \
	$APS2_COMMS_REPO_PATH/deps/ComBlock/5402/whois2.vhd


update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
