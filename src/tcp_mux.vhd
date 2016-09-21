-- Mux streams going to tcp tx: memory write/read response, CPLD tx
-- Cross to the tcp clock
-- Adapt to 8bit wide data path
-- Byte-swaping as necessary

-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tcp_bridge_pkg.all;

entity tcp_mux is
  port (
		clk     : in std_logic;
		rst     : in std_logic;
		clk_tcp : in std_logic;
    rst_tcp : in std_logic;

		--memory write/read streams
    memory_tx_write_resp_tdata  : in std_logic_vector(31 downto 0);
    memory_tx_write_resp_tvalid : in std_logic;
    memory_tx_write_resp_tlast  : in std_logic;
    memory_tx_write_resp_tready : out std_logic;

    memory_tx_read_resp_tdata  : in std_logic_vector(31 downto 0);
    memory_tx_read_resp_tvalid : in std_logic;
    memory_tx_read_resp_tlast  : in std_logic;
    memory_tx_read_resp_tready : out std_logic;

		--CPLD tx stream
		cpld_tx_tdata	 : in std_logic_vector(31 downto 0);
		cpld_tx_tvalid : in std_logic;
		cpld_tx_tready : out std_logic;
		cpld_tx_tlast	 : in std_logic;

		--TCP tx stream
		tcp_tx_tdata  : out std_logic_vector(7 downto 0);
		tcp_tx_tvalid : out std_logic;
		tcp_tx_tready : in std_logic
  );
end entity;

architecture arch of tcp_mux is

signal muxed_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal muxed_tvalid, muxed_tlast, muxed_tready : std_logic := '0';

signal muxed_tcp_clk_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal muxed_tcp_clk_tvalid, muxed_tcp_clk_tlast, muxed_tcp_clk_tready : std_logic := '0';


begin

--Mux together all the streams
mux_inst : axis_arb_mux_3
	generic map (
		DATA_WIDTH => 32,
		ARB_TYPE   => "ROUND_ROBIN",
		LSB_PRIORITY => "HIGH"
	)
	port map (
		clk => clk,
		rst => rst,

		input_0_axis_tdata   => memory_tx_read_resp_tdata,
		input_0_axis_tvalid  => memory_tx_read_resp_tvalid,
		input_0_axis_tready  => memory_tx_read_resp_tready,
		input_0_axis_tlast   => memory_tx_read_resp_tlast,
		input_0_axis_tuser   => '0',

		input_1_axis_tdata   => memory_tx_write_resp_tdata,
		input_1_axis_tvalid  => memory_tx_write_resp_tvalid,
		input_1_axis_tready  => memory_tx_write_resp_tready,
		input_1_axis_tlast   => memory_tx_write_resp_tlast,
		input_1_axis_tuser   => '0',

		input_2_axis_tdata   => cpld_tx_tdata,
		input_2_axis_tvalid  => cpld_tx_tvalid,
		input_2_axis_tready  => cpld_tx_tready,
		input_2_axis_tlast   => cpld_tx_tlast,
		input_2_axis_tuser   => '0',

		output_axis_tdata    => muxed_tdata,
		output_axis_tvalid   => muxed_tvalid,
		output_axis_tready   => muxed_tready,
		output_axis_tlast    => muxed_tlast,
		output_axis_tuser    => open
	);

	--Cross to the tcp clock domain
	axi2tcp_fifo_inst : axis_async_fifo
	generic map (
		ADDR_WIDTH => 5,
		DATA_WIDTH => 32
	)
	port map (
		async_rst => rst,

		input_clk => clk,
		input_axis_tdata  => muxed_tdata,
		input_axis_tvalid => muxed_tvalid,
		input_axis_tready => muxed_tready,
		input_axis_tlast  => muxed_tlast,
		input_axis_tuser  => '0',

		output_clk => clk_tcp,
		output_axis_tdata  => muxed_tcp_clk_tdata,
		output_axis_tvalid => muxed_tcp_clk_tvalid,
		output_axis_tready => muxed_tcp_clk_tready,
		output_axis_tlast  => muxed_tcp_clk_tlast,
		output_axis_tuser  => open
	);

	--Convert down to the byte wide data path
	to_8bit_adapter_inst : axis_adapter
	generic map (
	  INPUT_DATA_WIDTH => 32,
	  INPUT_KEEP_WIDTH => 4,
	  OUTPUT_DATA_WIDTH => 8,
	  OUTPUT_KEEP_WIDTH => 1
	)
	port map (
	  clk => clk_tcp,
	  rst => rst_tcp,

	  input_axis_tdata    => byte_swap(muxed_tcp_clk_tdata),
	  input_axis_tkeep    => (others => '1'),
	  input_axis_tvalid   => muxed_tcp_clk_tvalid,
	  input_axis_tready   => muxed_tcp_clk_tready,
	  input_axis_tlast    => '0',
	  input_axis_tuser    => '0',

	  output_axis_tdata  => tcp_tx_tdata,
	  output_axis_tkeep  => open,
	  output_axis_tvalid => tcp_tx_tvalid,
	  output_axis_tready => tcp_tx_tready,
	  output_axis_tlast  => open,
	  output_axis_tuser  => open
	);


end architecture;
