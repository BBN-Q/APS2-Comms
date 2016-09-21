#### tcp2axi FIFO in tcp_demux ####
#grey coded counter synchronizers in  get a max_delay -datapath only
#here launch clock for the wr_ptr is tcp clock and for rd_ptr, axi clock
set tcp2axi_wrclk [get_clocks -of_objects [get_ports clk_tcp]]
set tcp2axi_rdclk [get_clocks -of_objects [get_ports clk]]
set_max_delay -from [get_cells tcp_demux_inst/tcp2axi_fifo_inst/wr_ptr_gray_reg_reg[*]] -to [get_cells tcp_demux_inst/tcp2axi_fifo_inst/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $tcp2axi_wrclk]
set_max_delay -from [get_cells tcp_demux_inst/tcp2axi_fifo_inst/rd_ptr_gray_reg_reg[*]] -to [get_cells tcp_demux_inst/tcp2axi_fifo_inst/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $tcp2axi_rdclk]

#### axi2tcp FIFO in tcp_mux ####
#grey coded counters synchronizers get a max_delay -datapath only
#here launch clock for the wr_ptr is axi clock and for rd_ptr, tcp clock
set axi2tcp_wrclk [get_clocks -of_objects [get_ports clk]]
set axi2tcp_rdclk [get_clocks -of_objects [get_ports clk_tcp]]
set_max_delay -from [get_cells tcp_mux_inst/axi2tcp_fifo_inst/wr_ptr_gray_reg_reg[*]] -to [get_cells tcp_mux_inst/axi2tcp_fifo_inst/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $axi2tcp_wrclk]
set_max_delay -from [get_cells tcp_mux_inst/axi2tcp_fifo_inst/rd_ptr_gray_reg_reg[*]] -to [get_cells tcp_mux_inst/axi2tcp_fifo_inst/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $axi2tcp_rdclk]
