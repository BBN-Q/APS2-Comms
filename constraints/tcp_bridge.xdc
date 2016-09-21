#### tcp2axi FIFO in tcp_demux ####

# set ASYNC_REG property for all registers in the grey code synchronizer chain
set_property ASYNC_REG TRUE [get_cells -regexp {tcp_demux_inst/tcp2axi_fifo_inst/(wr|rd)_ptr_gray_sync[12]_reg_reg\[\d+\]}]

# ASYNC_REG property and false path to the reset synchronizer
set_property ASYNC_REG TRUE [get_cells -regexp {tcp_demux_inst/tcp2axi_fifo_inst/(input|output)_rst_sync[123]_reg_reg}]

set_false_path -through [get_ports rst] -to [get_cells -regexp {tcp_demux_inst/tcp2axi_fifo_inst/(input|output)_rst_sync[123]_reg_reg}]

set_false_path -to [get_pins tcp_demux_inst/tcp2axi_fifo_inst/output_rst_sync2_reg_reg/D]
set_false_path -to [get_pins tcp_demux_inst/tcp2axi_fifo_inst/input_rst_sync2_reg_reg/D]

#### axi2tcp FIFO in tcp_mux ####

# set ASYNC_REG property for all registers in the grey code synchronizer chain
set_property ASYNC_REG TRUE [get_cells -regexp {tcp_mux_inst/axi2tcp_fifo_inst/(wr|rd)_ptr_gray_sync[12]_reg_reg\[\d+\]}]

# ASYNC_REG property and false path to the reset synchronizer
set_property ASYNC_REG TRUE [get_cells -regexp {tcp_mux_inst/axi2tcp_fifo_inst/(input|output)_rst_sync[123]_reg_reg}]

set_false_path -through [get_ports rst] -to [get_cells -regexp {tcp_mux_inst/axi2tcp_fifo_inst/(input|output)_rst_sync[123]_reg_reg}]

set_false_path -to [get_pins tcp_mux_inst/axi2tcp_fifo_inst/output_rst_sync2_reg_reg/D]
set_false_path -to [get_pins tcp_mux_inst/axi2tcp_fifo_inst/input_rst_sync2_reg_reg/D]
