# set ASYNC_REG property for status registers
set_property ASYNC_REG TRUE [get_cells -regexp {rx_sync_reg_[1234]_reg\[[01]\]}]

# set ASYNC_REG property for all registers in the FIFO's grey code synchronizer chain
set_property ASYNC_REG TRUE [get_cells -regexp {(?:r|t)x_fifo/(?:wr|rd)_ptr_gray_sync[12]_reg_reg\[\d+\]}]

# set ASYNC_REG on the status synchronizers on the rx FIFO
set_property ASYNC_REG TRUE [get_cells -regexp {rx_fifo/(?:overflow|bad_frame|good_frame)_sync[1234]_reg_reg}]

# set ASYNC_REG on the FIFO's resets
set_property ASYNC_REG TRUE [get_cells -regexp {(?:r|t)x_fifo/(?:in|out)put_rst_sync[123]_reg_reg}]

# set false path for FIFO's reset synchronizers
# reset pins
set_false_path -to [get_pins -regexp {(?:r|t)x_fifo/(?:in|out)put_rst_sync[123]_reg_reg/PRE}]
# data pins
set_false_path -to [get_pins -regexp {(?:r|t)x_fifo/(?:in|out)put_rst_sync2_reg_reg/D}]
