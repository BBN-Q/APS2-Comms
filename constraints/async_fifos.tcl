#find the axis_async_fifos in the BD
set async_fifos [get_cells -hier -filter {(NAME =~ aps2_comms_bd_inst/*) && (ORIG_REF_NAME == axis_async_fifo || REF_NAME == axis_async_fifo || ORIG_REF_NAME == axis_async_frame_fifo || REF_NAME == axis_async_frame_fifo)}]

foreach fifo $async_fifos {
	# ASYNC_REG property on the reset synchronizer flip-flops
	set reset_ffs [get_cells -hier -regexp {.*/(in|out)put_rst_sync[123]_reg_reg} -filter "PARENT == $fifo"]
	set_property ASYNC_REG TRUE $reset_ffs

	# false path to reset pins on the reset synchronizer flip-flops
	set_false_path -to [get_pins -of_objects $reset_ffs -filter {IS_PRESET || IS_RESET}]

	# false path to the second stage reset synchronizer flip-flops data
	set_false_path -to [get_pins $fifo/input_rst_sync2_reg_reg/D]
	set_false_path -to [get_pins $fifo/output_rst_sync2_reg_reg/D]

	# max delayto 2ns to maximize metastability settle time
	set_max_delay -from [get_cells $fifo/input_rst_sync2_reg_reg] -to [get_cells $fifo/input_rst_sync3_reg_reg] 2
	set_max_delay -from [get_cells $fifo/output_rst_sync2_reg_reg] -to [get_cells $fifo/output_rst_sync3_reg_reg] 2

	# set ASYNC_REG property for all registers in the grey code synchronizer chain
	set_property ASYNC_REG TRUE [get_cells -hier -regexp {.*/(wr|rd)_ptr_gray_sync[12]_reg_reg\[\d+\]} -filter "PARENT == $fifo"]

	# extract write/read clocks from the grey code registers
	set read_clk [get_clocks -of_objects [get_pins $fifo/rd_ptr_reg_reg[0]/C]]
	set write_clk [get_clocks -of_objects [get_pins $fifo/wr_ptr_reg_reg[0]/C]]

	# rd_ptr_gray_sync is synchronized from the read clock to the write clock so
	# we use the read clock (launch clock) period to constrain the max_delay
	set_max_delay -from [get_cells $fifo/rd_ptr_gray_reg_reg[*]] -to [get_cells $fifo/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $read_clk]
	# similarly we uuse the write clock period to constrain the max_delay for the wr_ptr_gray_sync
	set_max_delay -from [get_cells $fifo/wr_ptr_gray_reg_reg[*]] -to [get_cells $fifo/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $write_clk]

	# for async_frame_fifos there are a few more status synchronization registers
	if {[string match [get_property ORIG_REF_NAME [get_cells $fifo]] axis_async_frame_fifo] || [string match [get_property REF_NAME [get_cells $fifo]] axis_async_frame_fifo]} {
		set status_sync_regs [get_cells -quiet -hier -regexp {.*/(?:overflow|bad_frame|good_frame)_sync[1234]_reg_reg} -filter "PARENT == $fifo"]
		foreach reg $status_sync_regs {
			set_property ASYNC_REG TRUE $reg
		}
	}
}

# eth_mac_1g_fifo synchronizes a few more FIFO status registers
set eth_mac_1g_fifo_inst [get_cells aps2_comms_bd_inst/eth_mac_1g_fifo_wrapper_0/U0/eth_mac_1g_fifo_inst]
set_property ASYNC_REG TRUE [get_cells -hier -regexp {.*/rx_sync_reg_[1234]_reg\[[01]\]} -filter "PARENT == $eth_mac_1g_fifo_inst"]

# TODO: not actually using this now
#set rx_clk [get_clocks -of_objects [get_cells $eth_mac_1g_fifo_inst/rx_sync_reg_1]]
#set_max_delay -from [get_cells -hier -regexp {.*/rx_sync_reg_1_reg\[[12]\]} -filter "PARENT == $eth_mac_1g_fifo_inst"] -to [get_cells -hier -regexp {.*/rx_sync_reg_2_reg\[[12]\]} -filter "PARENT == $eth_mac_1g_fifo_inst"] -datapath_only [get_property -min PERIOD $rx_clk]
