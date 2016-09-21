#extract clocks
set rx_clk [get_clocks -of_objects [get_ports rx_clk]]
set tx_clk [get_clocks -of_objects [get_ports tx_clk]]
set logic_clk [get_clocks -of_objects [get_ports logic_clk]]

# frame status synchronizer from rx clock to logic clock datapath
set_max_delay -from [get_cells -regexp {rx_sync_reg_1_reg\[[12]\]}] -to [get_cells -regexp {rx_sync_reg_2_reg\[[12]\]}] -datapath_only [get_property -min PERIOD $rx_clk]

# FIFO from rx clock to logic clock datapath
# wr_ptr is synced from input -> output clock
set_max_delay -from [get_cells rx_fifo/wr_ptr_gray_reg_reg[*]] -to [get_cells rx_fifo/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $rx_clk]
# rd_ptr is synced from output -> input clock
set_max_delay -from [get_cells rx_fifo/rd_ptr_gray_reg_reg[*]] -to [get_cells rx_fifo/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $logic_clk]

# FIFO from logic to tx clock datapath
# wr_ptr is synced from input -> output clock
set_max_delay -from [get_cells tx_fifo/wr_ptr_gray_reg_reg[*]] -to [get_cells tx_fifo/wr_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $logic_clk]
# rd_ptr is synced from output -> input clock
set_max_delay -from [get_cells tx_fifo/rd_ptr_gray_reg_reg[*]] -to [get_cells tx_fifo/rd_ptr_gray_sync1_reg_reg[*]] -datapath_only [get_property -min PERIOD $tx_clk]
