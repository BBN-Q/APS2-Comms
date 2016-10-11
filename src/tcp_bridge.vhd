-- Top-level entity for the bridge to the TCP stream
-- Contains:
-- 1. tcp_demux to send data to either memory or CPLD
-- 2. tcp_axi_dma to issue read/write DMA commands to memory
-- 3. tcp_mux to combine return streams
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcp_bridge is
	port (
		clk     : in std_logic;
		rst     : in std_logic;
		clk_tcp : in std_logic;
		rst_tcp : in std_logic;

		--TCP streams
		tcp_rx_tdata  : in std_logic_vector(7 downto 0);
		tcp_rx_tvalid : in std_logic;
		tcp_rx_tready : out std_logic;

		tcp_tx_tdata  : out std_logic_vector(7 downto 0);
		tcp_tx_tvalid : out std_logic;
		tcp_tx_tready : in std_logic;

		comms_active : out std_logic;

		--CPLD streams
		cpld_rx_tdata  : out std_logic_vector(31 downto 0);
		cpld_rx_tvalid : out std_logic;
		cpld_rx_tready : in std_logic := '1';
		cpld_rx_tlast  : out std_logic;

		cpld_tx_tdata	 : in std_logic_vector(31 downto 0) := (others => '0');
		cpld_tx_tvalid : in std_logic := '0';
		cpld_tx_tready : out std_logic;
		cpld_tx_tlast	 : in std_logic := '0';

		--AXI DataMover streams
		MM2S_CMD_tdata  : out std_logic_vector( 71 downto 0 );
		MM2S_CMD_tready : in std_logic;
		MM2S_CMD_tvalid : out std_logic;

		MM2S_tdata     : in std_logic_vector( 31 downto 0 );
		MM2S_tkeep     : in std_logic_vector( 3 downto 0 );
		MM2S_tlast     : in std_logic;
		MM2S_tready    : out std_logic;
		MM2S_tvalid    : in std_logic;

		MM2S_STS_tdata  : in std_logic_vector( 7 downto 0 );
		MM2S_STS_tkeep  : in std_logic_vector( 0 to 0 );
		MM2S_STS_tlast  : in std_logic;
		MM2S_STS_tready : out std_logic;
		MM2S_STS_tvalid : in std_logic;

		S2MM_CMD_tdata  : out std_logic_vector( 71 downto 0 );
		S2MM_CMD_tready : in std_logic;
		S2MM_CMD_tvalid : out std_logic;

		S2MM_tdata  : out std_logic_vector( 31 downto 0 );
		S2MM_tkeep  : out std_logic_vector( 3 downto 0 );
		S2MM_tlast  : out std_logic;
		S2MM_tready : in std_logic;
		S2MM_tvalid : out std_logic;

		S2MM_STS_tdata  : in std_logic_vector( 7 downto 0 );
		S2MM_STS_tkeep  : in std_logic_vector( 0 to 0 );
		S2MM_STS_tlast  : in std_logic;
		S2MM_STS_tready : out std_logic;
		S2MM_STS_tvalid : in std_logic
	);
end entity;

architecture arch of tcp_bridge is


attribute X_INTERFACE_INFO : string;
attribute X_INTERFACE_INFO of clk_tcp : signal is "xilinx.com:signal:clock:1.0 clk_tcp CLK";
attribute X_INTERFACE_PARAMETER : string;
attribute X_INTERFACE_PARAMETER of clk_tcp : signal is
	"ASSOCIATED_BUSIF tcp_rx:tcp_tx, ASSOCIATED_RESET rst_tcp, FREQ_HZ 125000000";


signal memory_rx_tdata : std_logic_vector(31 downto 0) := (others => '0');
signal memory_rx_tvalid, memory_rx_tready, memory_rx_tlast : std_logic := '0';

signal memory_tx_write_resp_tdata : std_logic_vector(31 downto 0);
signal memory_tx_write_resp_tvalid, memory_tx_write_resp_tready, memory_tx_write_resp_tlast : std_logic;
signal memory_tx_read_resp_tdata : std_logic_vector(31 downto 0);
signal memory_tx_read_resp_tvalid, memory_tx_read_resp_tready, memory_tx_read_resp_tlast : std_logic;

signal tcp_tx_tvalid_int : std_logic;

begin

tcp_tx_tvalid <= tcp_tx_tvalid_int;

--Clock out valids as indicators of comms_active
comms_active_reg : process( clk_tcp )
begin
	if rising_edge( clk_tcp) then
		if rst_tcp = '1' then
			comms_active <= '0';
		else
			comms_active <= tcp_rx_tvalid or tcp_tx_tvalid_int;
		end if;
	end if;
end process;

--TCP Demux
tcp_demux_inst : entity work.tcp_demux
port map (
	clk => clk,
	rst => rst,
	clk_tcp => clk_tcp,
	rst_tcp => rst_tcp,

	--TCP stream receive
	tcp_rx_tdata  => tcp_rx_tdata,
	tcp_rx_tvalid => tcp_rx_tvalid,
	tcp_rx_tready => tcp_rx_tready,

	--rx stream passed to memory
	memory_rx_tdata  => memory_rx_tdata,
	memory_rx_tvalid => memory_rx_tvalid,
	memory_rx_tready => memory_rx_tready,
	memory_rx_tlast  => memory_rx_tlast,

	--rx stream passed to CPLD bridge
	cpld_rx_tdata  => cpld_rx_tdata,
	cpld_rx_tvalid => cpld_rx_tvalid,
	cpld_rx_tready => cpld_rx_tready,
	cpld_rx_tlast  => cpld_rx_tlast
);

--TCP DMA
tcp_axi_dma_inst : entity work.tcp_axi_dma
port map (
	clk => clk,
	rst => rst,

	---TCP receive
	rx_tdata  => memory_rx_tdata,
	rx_tvalid => memory_rx_tvalid,
	rx_tready => memory_rx_tready,
	rx_tlast  => memory_rx_tlast,

	--TCP send channels
	tx_write_resp_tdata  => memory_tx_write_resp_tdata,
	tx_write_resp_tvalid => memory_tx_write_resp_tvalid,
	tx_write_resp_tlast  => memory_tx_write_resp_tlast,
	tx_write_resp_tready => memory_tx_write_resp_tready,

	tx_read_resp_tdata  => memory_tx_read_resp_tdata,
	tx_read_resp_tvalid => memory_tx_read_resp_tvalid,
	tx_read_resp_tlast  => memory_tx_read_resp_tlast,
	tx_read_resp_tready => memory_tx_read_resp_tready,

	--DataMover interfaces
	MM2S_CMD_tdata  => MM2S_CMD_tdata,
	MM2S_CMD_tready => MM2S_CMD_tready,
	MM2S_CMD_tvalid => MM2S_CMD_tvalid,

	MM2S_tdata  => MM2S_tdata,
	MM2S_tkeep  => MM2S_tkeep,
	MM2S_tlast  => MM2S_tlast,
	MM2S_tready => MM2S_tready,
	MM2S_tvalid => MM2S_tvalid,

	MM2S_STS_tdata  => MM2S_STS_tdata,
	MM2S_STS_tkeep  => MM2S_STS_tkeep,
	MM2S_STS_tlast  => MM2S_STS_tlast,
	MM2S_STS_tready => MM2S_STS_tready,
	MM2S_STS_tvalid => MM2S_STS_tvalid,

	S2MM_CMD_tdata  => S2MM_CMD_tdata,
	S2MM_CMD_tready => S2MM_CMD_tready,
	S2MM_CMD_tvalid => S2MM_CMD_tvalid,

	S2MM_tdata  => S2MM_tdata,
	S2MM_tkeep  => S2MM_tkeep,
	S2MM_tlast  => S2MM_tlast,
	S2MM_tready => S2MM_tready,
	S2MM_tvalid => S2MM_tvalid,

	S2MM_STS_tdata  => S2MM_STS_tdata,
	S2MM_STS_tkeep  => S2MM_STS_tkeep,
	S2MM_STS_tlast  => S2MM_STS_tlast,
	S2MM_STS_tready => S2MM_STS_tready,
	S2MM_STS_tvalid => S2MM_STS_tvalid
);

tcp_mux_inst : entity work.tcp_mux
port map (
	clk => clk,
	rst => rst,
	clk_tcp => clk_tcp,
	rst_tcp => rst_tcp,

	--memory write/read streams
	memory_tx_write_resp_tdata  => memory_tx_write_resp_tdata,
	memory_tx_write_resp_tvalid => memory_tx_write_resp_tvalid,
	memory_tx_write_resp_tlast  => memory_tx_write_resp_tlast,
	memory_tx_write_resp_tready => memory_tx_write_resp_tready,

	memory_tx_read_resp_tdata  => memory_tx_read_resp_tdata,
	memory_tx_read_resp_tvalid => memory_tx_read_resp_tvalid,
	memory_tx_read_resp_tlast  => memory_tx_read_resp_tlast,
	memory_tx_read_resp_tready => memory_tx_read_resp_tready,

	--CPLD tx stream
	cpld_tx_tdata  => cpld_tx_tdata,
	cpld_tx_tvalid => cpld_tx_tvalid,
	cpld_tx_tready => cpld_tx_tready,
	cpld_tx_tlast  => cpld_tx_tlast,

	--TCP tx stream
	tcp_tx_tdata  => tcp_tx_tdata,
	tcp_tx_tvalid => tcp_tx_tvalid_int,
	tcp_tx_tready => tcp_tx_tready
);

end architecture;
