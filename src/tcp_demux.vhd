-- Cross from tcp clock domain
-- Demux tcp stream between AXI memory and CPLD
-- Packetize by adding tlast to stream
-- Adapt to 32bit wide data path
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tcp_bridge_pkg.all;

entity tcp_demux is
  port (
		clk : in std_logic;
		rst : in std_logic;
		clk_tcp : in std_logic;
		rst_tcp : in std_logic;

		--TCP stream receive
		tcp_rx_tdata  : in std_logic_vector(7 downto 0);
		tcp_rx_tvalid : in std_logic;
		tcp_rx_tready : out std_logic;

		--rx stream passed to memory
		memory_rx_tdata  : out std_logic_vector(31 downto 0);
		memory_rx_tvalid : out std_logic;
		memory_rx_tready : in std_logic;
		memory_rx_tlast  : out std_logic;

		--rx stream passed to CPLD bridge
		cpld_rx_tdata  : out std_logic_vector(31 downto 0);
		cpld_rx_tvalid : out std_logic;
		cpld_rx_tready : in std_logic;
		cpld_rx_tlast  : out std_logic
  );
end entity;

architecture arch of tcp_demux is

signal tcp_rx_long_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal tcp_rx_long_tvalid, tcp_rx_long_tready : std_logic := '0';

signal tcp_rx_long_cc_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal tcp_rx_long_cc_tvalid, tcp_rx_long_cc_tready : std_logic := '0';

signal demux_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal demux_tvalid, demux_tlast, demux_tready : std_logic := '0';

type main_state_t is (IDLE, LATCH_COMMAND, COUNT_PACKET);
signal main_state : main_state_t := IDLE;

signal cmd : std_logic_vector(31 downto 0);
alias cmd_rw_bit : std_logic is cmd(28);
alias cmd_cpld_bit : std_logic is cmd(29);
alias cmd_length : std_logic_vector(15 downto 0) is cmd(15 downto 0);
signal word_ct : unsigned(16 downto 0);

begin

--Adapt up to 32 bit wide data path
axis_adapter_inst : axis_adapter
generic map (
  INPUT_DATA_WIDTH => 8,
  INPUT_KEEP_WIDTH => 1,
  OUTPUT_DATA_WIDTH => 32,
  OUTPUT_KEEP_WIDTH => 4
)
port map (
	clk => clk_tcp,
	rst => rst_tcp,

	input_axis_tdata  => tcp_rx_tdata,
	input_axis_tkeep(0)  => '1',
	input_axis_tvalid => tcp_rx_tvalid,
	input_axis_tready => tcp_rx_tready,
	input_axis_tlast  => '0',
	input_axis_tuser  => '0',

	output_axis_tdata  => tcp_rx_long_tdata,
	output_axis_tkeep  => open,
	output_axis_tvalid => tcp_rx_long_tvalid,
	output_axis_tready => tcp_rx_long_tready,
	output_axis_tlast  => open,
	output_axis_tuser  => open
);

--Cross from the tcp clock domain
tcp2axi_fifo_inst : axis_async_fifo
generic map (
	ADDR_WIDTH => 5,
	DATA_WIDTH => 32
)
port map (
	async_rst => rst,

	input_clk => clk_tcp,
	input_axis_tdata  => byte_swap(tcp_rx_long_tdata),
	input_axis_tvalid => tcp_rx_long_tvalid,
	input_axis_tready => tcp_rx_long_tready,
	input_axis_tlast  => '0',
	input_axis_tuser  => '0',

	output_clk => clk,
	output_axis_tdata  => tcp_rx_long_cc_tdata,
	output_axis_tvalid => tcp_rx_long_cc_tvalid,
	output_axis_tready => tcp_rx_long_cc_tready,
	output_axis_tlast  => open,
	output_axis_tuser  => open
);

--Main decision loop
main : process(clk)
begin
	if rising_edge(clk) then
		if rst = '1' then
			main_state <= IDLE;
			word_ct <= (others => '0');
      cmd <= (others => '0');
		else
			case( main_state ) is

				when IDLE =>
					cmd <= tcp_rx_long_cc_tdata;
					--Wait for valid to announce start of packet
					if tcp_rx_long_cc_tvalid = '1' then
						main_state <= LATCH_COMMAND;
					end if;

				when LATCH_COMMAND =>
					main_state <= COUNT_PACKET;
					--For reads only have command and address so mask out word_ct
					--normally - 2 for zero indexed and roll-over but count cmd and address
					--TODO: change to when/else when I get VHDL 2008 working
					if cmd_rw_bit = '0' then
						word_ct <= resize(unsigned(cmd_length),17);
					else
						word_ct <= (others => '0');
					end if;

				when COUNT_PACKET =>
					if demux_tvalid = '1' and demux_tready = '1' then
						if word_ct(word_ct'high) = '1' then
							main_state <= IDLE;
						end if;
						word_ct <= word_ct - 1;
					end if;

			end case;
		end if;
	end if;
end process;

--Combinational AXI stream signals
demux_tdata <= tcp_rx_long_cc_tdata;
demux_tvalid <= tcp_rx_long_cc_tvalid when main_state = COUNT_PACKET else '0';
tcp_rx_long_cc_tready <= demux_tready when main_state = COUNT_PACKET else '0';
demux_tlast <= demux_tvalid when main_state = COUNT_PACKET and word_ct(word_ct'high) = '1' else '0';

--Demux between memory and CPLD
memory_cpld_demux : axis_demux_2
generic map ( DATA_WIDTH => 32)
port map (
	clk => clk,
	rst => rst,

	input_axis_tdata  => demux_tdata,
	input_axis_tvalid => demux_tvalid,
	input_axis_tready => demux_tready,
	input_axis_tlast  => demux_tlast,
	input_axis_tuser  => '0',

	output_0_axis_tdata  => memory_rx_tdata,
	output_0_axis_tvalid => memory_rx_tvalid,
	output_0_axis_tready => memory_rx_tready,
	output_0_axis_tlast  => memory_rx_tlast,
	output_0_axis_tuser  => open,

	output_1_axis_tdata  => cpld_rx_tdata,
	output_1_axis_tvalid => cpld_rx_tvalid,
	output_1_axis_tready => cpld_rx_tready,
	output_1_axis_tlast  => cpld_rx_tlast,
	output_1_axis_tuser  => open,

	enable => '1',
	control(0) => cmd_cpld_bit
);
end architecture;
