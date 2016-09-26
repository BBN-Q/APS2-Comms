-- Simple wrapper of the eth_mac_1g_fifo
-- with helper attributes for Vivado to infer interfaces

library ieee;
use ieee.std_logic_1164.all;

entity eth_mac_1g_fifo_wrapper is
	generic (
		ENABLE_PADDING     : natural := 1;
		MIN_FRAME_LENGTH   : natural := 64;
		TX_FIFO_ADDR_WIDTH : natural := 12;
		RX_FIFO_ADDR_WIDTH : natural := 12
	);
	port (
		rx_clk    : in std_logic;
		rx_rst    : in std_logic;
		tx_clk    : in std_logic;
		tx_rst    : in std_logic;
		logic_clk : in std_logic;
		logic_rst : in std_logic;

		tx_axis_tdata  : in std_logic_vector(7 downto 0);
		tx_axis_tvalid : in std_logic;
		tx_axis_tready : out std_logic;
		tx_axis_tlast  : in std_logic;
		tx_axis_tuser  : in std_logic;

		rx_axis_tdata  : out std_logic_vector(7 downto 0);
		rx_axis_tvalid : out std_logic;
		rx_axis_tready : in std_logic;
		rx_axis_tlast  : out std_logic;
		rx_axis_tuser  : out std_logic;

		gmii_rxd   : in std_logic_vector(7 downto 0);
		gmii_rx_dv : in std_logic;
		gmii_rx_er : in std_logic;
		gmii_txd   : out std_logic_vector(7 downto 0);
		gmii_tx_en : out std_logic;
		gmii_tx_er : out std_logic;

		tx_fifo_overflow   : out std_logic;
		tx_fifo_bad_frame  : out std_logic;
		tx_fifo_good_frame : out std_logic;
		rx_error_bad_frame : out std_logic;
		rx_error_bad_fcs   : out std_logic;
		rx_fifo_overflow   : out std_logic;
		rx_fifo_bad_frame  : out std_logic;
		rx_fifo_good_frame : out std_logic;

		ifg_delay : in std_logic_vector(7 downto 0)
	);
end entity;

architecture arch of eth_mac_1g_fifo_wrapper is

	-- some helper attributes for Vivado to infer interfaces
	attribute X_INTERFACE_INFO : string;
	attribute X_INTERFACE_INFO of gmii_txd   : signal is "xilinx.com:interface:gmii:1.0 gmii TXD";
	attribute X_INTERFACE_INFO of gmii_tx_en : signal is "xilinx.com:interface:gmii:1.0 gmii TX_EN";
	attribute X_INTERFACE_INFO of gmii_tx_er : signal is "xilinx.com:interface:gmii:1.0 gmii TX_ER";
	attribute X_INTERFACE_INFO of gmii_rxd   : signal is "xilinx.com:interface:gmii:1.0 gmii RXD";
	attribute X_INTERFACE_INFO of gmii_rx_dv : signal is "xilinx.com:interface:gmii:1.0 gmii RX_DV";
	attribute X_INTERFACE_INFO of gmii_rx_er : signal is "xilinx.com:interface:gmii:1.0 gmii RX_ER";
	attribute X_INTERFACE_INFO of tx_clk     : signal is "xilinx.com:interface:gmii:1.0 gmii GTX_CLK";
  attribute X_INTERFACE_INFO of rx_clk     : signal is "xilinx.com:interface:gmii:1.0 gmii RX_CLK";

	attribute X_INTERFACE_PARAMETER : string;
	attribute X_INTERFACE_PARAMETER of rx_rst    : signal is "POLARITY ACTIVE_HIGH";
	attribute X_INTERFACE_PARAMETER of tx_rst    : signal is "POLARITY ACTIVE_HIGH";
	attribute X_INTERFACE_PARAMETER of logic_rst : signal is "POLARITY ACTIVE_HIGH";

	attribute X_INTERFACE_PARAMETER of logic_clk : signal is
		"ASSOCIATED_BUSIF rx_axis:tx_axis, ASSOCIATED_RESET logic_rst, FREQ_HZ 125000000";


	component eth_mac_1g_fifo
		generic (
			ENABLE_PADDING     : natural := 1;
			MIN_FRAME_LENGTH   : natural := 64;
			TX_FIFO_ADDR_WIDTH : natural := 12;
			RX_FIFO_ADDR_WIDTH : natural := 12
		);
		port (
			rx_clk    : in std_logic;
			rx_rst    : in std_logic;
			tx_clk    : in std_logic;
			tx_rst    : in std_logic;
			logic_clk : in std_logic;
			logic_rst : in std_logic;

			tx_axis_tdata  : in std_logic_vector(7 downto 0);
			tx_axis_tvalid : in std_logic;
			tx_axis_tready : out std_logic;
			tx_axis_tlast  : in std_logic;
			tx_axis_tuser  : in std_logic;

			rx_axis_tdata  : out std_logic_vector(7 downto 0);
			rx_axis_tvalid : out std_logic;
			rx_axis_tready : in std_logic;
			rx_axis_tlast  : out std_logic;
			rx_axis_tuser  : out std_logic;

			gmii_rxd   : in std_logic_vector(7 downto 0);
			gmii_rx_dv : in std_logic;
			gmii_rx_er : in std_logic;
			gmii_txd   : out std_logic_vector(7 downto 0);
			gmii_tx_en : out std_logic;
			gmii_tx_er : out std_logic;

			tx_fifo_overflow   : out std_logic;
			tx_fifo_bad_frame  : out std_logic;
			tx_fifo_good_frame : out std_logic;
			rx_error_bad_frame : out std_logic;
			rx_error_bad_fcs   : out std_logic;
			rx_fifo_overflow   : out std_logic;
			rx_fifo_bad_frame  : out std_logic;
			rx_fifo_good_frame : out std_logic;

			ifg_delay : in std_logic_vector(7 downto 0)
		);
	end component;

begin

	eth_mac_1g_fifo_inst : eth_mac_1g_fifo
	generic map (
		ENABLE_PADDING     => ENABLE_PADDING,
		MIN_FRAME_LENGTH   => MIN_FRAME_LENGTH,
		TX_FIFO_ADDR_WIDTH => TX_FIFO_ADDR_WIDTH,
		RX_FIFO_ADDR_WIDTH => RX_FIFO_ADDR_WIDTH
	)
	port map (
		rx_clk             => rx_clk,
		rx_rst             => rx_rst,
		tx_clk             => tx_clk,
		tx_rst             => tx_rst,
		logic_clk          => logic_clk,
		logic_rst          => logic_rst,
		tx_axis_tdata      => tx_axis_tdata,
		tx_axis_tvalid     => tx_axis_tvalid,
		tx_axis_tready     => tx_axis_tready,
		tx_axis_tlast      => tx_axis_tlast,
		tx_axis_tuser      => tx_axis_tuser,
		rx_axis_tdata      => rx_axis_tdata,
		rx_axis_tvalid     => rx_axis_tvalid,
		rx_axis_tready     => rx_axis_tready,
		rx_axis_tlast      => rx_axis_tlast,
		rx_axis_tuser      => rx_axis_tuser,
		gmii_rxd           => gmii_rxd,
		gmii_rx_dv         => gmii_rx_dv,
		gmii_rx_er         => gmii_rx_er,
		gmii_txd           => gmii_txd,
		gmii_tx_en         => gmii_tx_en,
		gmii_tx_er         => gmii_tx_er,
		tx_fifo_overflow   => tx_fifo_overflow,
		tx_fifo_bad_frame  => tx_fifo_bad_frame,
		tx_fifo_good_frame => tx_fifo_good_frame,
		rx_error_bad_frame => rx_error_bad_frame,
		rx_error_bad_fcs   => rx_error_bad_fcs,
		rx_fifo_overflow   => rx_fifo_overflow,
		rx_fifo_bad_frame  => rx_fifo_bad_frame,
		rx_fifo_good_frame => rx_fifo_good_frame,
		ifg_delay          => ifg_delay
	);



end architecture;
