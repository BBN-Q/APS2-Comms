-- Bridge to the CPLD-FPGA Interface
-- For now just wraps the ZRL ApsMsgProc but in the future will be our own solution
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpld_bridge_pkg.all;

entity CPLD_bridge is
	generic (
		BOARD_TYPE : std_logic_vector(7 downto 0) := x"00" -- x"00" for APS; x"01" for TDM
	);
	port (
		clk : in std_logic;
		rst : in std_logic;

		--RX and TX to TCP comms.
		rx_tdata  : in std_logic_vector(31 downto 0);
		rx_tvalid : in std_logic;
		rx_tready : out std_logic;
		rx_tlast  : in std_logic;

		tx_tdata  : out std_logic_vector(31 downto 0);
		tx_tvalid : out std_logic;
		tx_tready : in std_logic;
		tx_tlast  : out std_logic;

		-- Config Bus Connections
		cfg_clk   : in std_logic;	-- 100 MHZ clock from the Config CPLD
		cfgd      : inout std_logic_vector(15 downto 0);	-- Config Data bus from CPLD
		fpga_cmdl : out std_logic;	-- Command strobe from FPGA
		fpga_rdyl : out std_logic;	-- Ready Strobe from FPGA
		cfg_rdy   : in std_logic;	-- Ready to complete current transfer.	Connected to CFG_RDWR_B
		cfg_err   : in std_logic;	-- Error during current command.	Connecte to CFG_CSI_B
		cfg_act   : in std_logic;	-- Current transaction is complete
		stat_oel  : out std_logic -- Enable CPLD to drive status onto CFGD
	);
end entity;

architecture arch of CPLD_bridge is

	--ApsMsgProc signals
  signal msgproc_rx_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal msgproc_rx_tvalid, msgproc_rx_tready, msgproc_rx_tlast : std_logic := '0';
  signal msgproc_tx_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal msgproc_tx_tvalid, msgproc_tx_tready, msgproc_tx_tlast : std_logic := '0';

	--internal signal to work around Vivado not allowing functions on the left hand-side of a port-map
	signal tx_tdata_int : std_logic_vector(31 downto 0);
begin

--Adapt rx and tx streams from 32 to 8 bits for MsgProc with byte swapping
rx_axis_adapter_inst : axis_adapter
generic map (
  INPUT_DATA_WIDTH => 32,
  INPUT_KEEP_WIDTH => 4,
  OUTPUT_DATA_WIDTH => 8,
  OUTPUT_KEEP_WIDTH => 1
)
port map (
  clk => clk,
  rst => rst,

  input_axis_tdata  => byte_swap(rx_tdata),
  input_axis_tkeep  => (others => '1'),
  input_axis_tvalid => rx_tvalid,
  input_axis_tready => rx_tready,
  input_axis_tlast  => rx_tlast,
  input_axis_tuser  => '0',

  output_axis_tdata  => msgproc_rx_tdata,
  output_axis_tkeep  => open,
  output_axis_tvalid => msgproc_rx_tvalid,
  output_axis_tready => msgproc_rx_tready,
  output_axis_tlast  => msgproc_rx_tlast,
  output_axis_tuser  => open
);

tx_axis_adapter_inst : axis_adapter
generic map (
  INPUT_DATA_WIDTH => 8,
  INPUT_KEEP_WIDTH => 1,
  OUTPUT_DATA_WIDTH => 32,
  OUTPUT_KEEP_WIDTH => 4
)
port map (
  clk => clk,
  rst => rst,

  input_axis_tdata    => msgproc_tx_tdata,
  input_axis_tkeep(0) => msgproc_tx_tvalid,
  input_axis_tvalid   => msgproc_tx_tvalid,
  input_axis_tready   => msgproc_tx_tready,
  input_axis_tlast    => msgproc_tx_tlast,
  input_axis_tuser    => '0',

  output_axis_tdata => tx_tdata_int,
  output_axis_tkeep  => open,
  output_axis_tvalid => tx_tvalid,
  output_axis_tready => tx_tready,
  output_axis_tlast  => tx_tlast,
  output_axis_tuser  => open
);
tx_tdata <= byte_swap(tx_tdata_int);

--Instantiate wrapper around ZRL ApsMsgProc
apsmsgproc_wrapper_inst : entity work.ApsMsgProc_wrapper
generic map( BOARD_TYPE => BOARD_TYPE )
port map (
	clk => clk,
	rst => rst,

	--RX and TX to TCP comms.
	rx_tdata  => msgproc_rx_tdata,
	rx_tvalid => msgproc_rx_tvalid,
	rx_tready => msgproc_rx_tready,
	rx_tlast  => msgproc_rx_tlast,

	tx_tdata  => msgproc_tx_tdata,
	tx_tvalid => msgproc_tx_tvalid,
	tx_tready => msgproc_tx_tready,
	tx_tlast  => msgproc_tx_tlast,

	-- Config Bus Connections
	cfg_clk   => cfg_clk,
	cfgd      => cfgd,
	fpga_cmdl => fpga_cmdl,
	fpga_rdyl => fpga_rdyl,
	cfg_rdy   => cfg_rdy,
	cfg_err   => cfg_err,
	cfg_act   => cfg_act,
	stat_oel  => stat_oel
);


end architecture;
