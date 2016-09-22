-- Wraps ComBlock 5402 server into something more AXI compatible

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.com5402pkg.all;	-- defines global types, number of TCP streams, etc
use work.com5402_wrapper_pkg.all;

entity com5402_wrapper is
	generic (
		SIMULATION : std_logic := '0';
		FIXED_IP : boolean := false);
	port (
		clk     : in std_logic;
		rst     : in std_logic;
		tcp_rst : in std_logic;

		mac_addr		: in std_logic_vector(47 downto 0);
		IPv4_addr	  : in std_logic_vector(31 downto 0);
		subnet_mask : in std_logic_vector(31 downto 0);
		gateway_ip_addr : in std_logic_vector(31 downto 0);
		dhcp_enable : in std_logic;

		mac_tx_tdata	: out std_logic_vector(7 downto 0);
		mac_tx_tvalid : out std_logic;
		mac_tx_tlast	: out std_logic;
		mac_tx_tuser	: out std_logic;
		mac_tx_tready : in std_logic;

		mac_rx_tdata	: in std_logic_vector(7 downto 0);
		mac_rx_tvalid : in std_logic;
		mac_rx_tlast	: in std_logic;
		mac_rx_tuser	: in std_logic;
		mac_rx_tready : out std_logic;

		udp_rx_tdata	     : out std_logic_vector(7 downto 0);
		udp_rx_tvalid      : out std_logic;
		udp_rx_tlast	     : out std_logic;
		udp_rx_dest_port   : in std_logic_vector(15 downto 0);
		udp_rx_src_port    : out std_logic_vector(15 downto 0);
		rx_src_ip_addr     : out std_logic_vector(31 downto 0);

		udp_tx_tdata	      : in std_logic_vector(7 downto 0);
		udp_tx_tvalid       : in std_logic;
		udp_tx_tlast	      : in std_logic;
		udp_tx_tready       : out std_logic;
		udp_tx_src_port	    : in std_logic_vector(15 downto 0);
		udp_tx_dest_port    : in std_logic_vector(15 downto 0);
		udp_tx_dest_ip_addr : in std_logic_vector(31 downto 0);
		udp_tx_ack          : out std_logic;
		udp_tx_nack         : out std_logic;

		tcp_port      : in std_logic_vector(15 downto 0);
		tcp_rx_tdata	: out std_logic_vector(7 downto 0);
		tcp_rx_tvalid : out std_logic;
		tcp_rx_tready : in	std_logic;

		tcp_tx_tdata	: in std_logic_vector(7 downto 0);
		tcp_tx_tvalid : in std_logic;
		tcp_tx_tready	: out	std_logic

	);
end entity;

architecture arch of com5402_wrapper is

signal tcp_rx_data, tcp_tx_data : SLV8xNTCPSTREAMStype;

--sof/eof signal generation
type SOF_STATE_TYPE is (IDLE, WAIT_FOR_LAST);
signal mac_rx_sof_state : SOF_STATE_TYPE;
signal mac_rx_sof : std_logic;
signal udp_tx_sof_state : SOF_STATE_TYPE;
signal udp_tx_sof : std_logic;
signal udp_tx_cts : std_logic;
signal udp_tx_data_valid : std_logic;
signal udp_tx_eof : std_logic;

--Vivado doesn't properly support reading from out in simulation
signal mac_tx_tlast_int : std_logic;
signal mac_rx_tready_int : std_logic;

--CTS / tready handshakes
signal tcp_rx_tvalid_int : std_logic;
signal tcp_tx_cts : std_logic;
signal tcp_tx_tvalid_int : std_logic;

--AXIS to Comblock tlast conversion
signal mac_rx_tlast_int : std_logic;

type rx_ifg_state_t is (IDLE, GAP);
signal rx_ifg_state : rx_ifg_state_t := IDLE;

begin

--don't leave mac_rx_tlast hanging asserted otherwise Comblock gets messed up
mac_rx_tlast_int <= mac_rx_tlast and mac_rx_tvalid;

mac_tx_tuser <= '0';
mac_tx_tlast <= mac_tx_tlast_int;

-- seems to be no signal from ComBlock to apply back pressure
-- generate one to ensure an interframe gap
mac_rx_ifg : process(clk)
	constant RX_IFG_DELAY : natural := 7;
	variable ifg_counter : natural range 0 to RX_IFG_DELAY := 0;
begin
	if rising_edge(clk) then
		if rst = '1' then
			rx_ifg_state <= IDLE;
		else
			case (rx_ifg_state) is
				when IDLE =>
					ifg_counter := RX_IFG_DELAY;
					if mac_rx_tlast_int = '1' then
						rx_ifg_state <= GAP;
					end if;
				when GAP =>
					if ifg_counter = 0 then
						rx_ifg_state <= IDLE;
					else
						ifg_counter := ifg_counter - 1;
					end if;
			end case;
		end if;
	end if;
end process ; -- mac_rx_ifg
mac_rx_tready_int <= '0' when rx_ifg_state = GAP else '1';
mac_rx_tready <= mac_rx_tready_int;

--Create start-of-frame signals
--TODO turn into procedure
mac_rx_sof_creator : process(clk)
begin
	if rising_edge(clk) then
		if rst = '1' then
			mac_rx_sof_state <= IDLE;
		else
			case( mac_rx_sof_state ) is
				when IDLE =>
					if mac_rx_tvalid = '1' and mac_rx_tready_int = '1' then
						mac_rx_sof_state <= WAIT_FOR_LAST;
					end if;

				when WAIT_FOR_LAST =>
					if mac_rx_tlast = '1' and mac_rx_tvalid = '1' and mac_rx_tready_int = '1' then
						mac_rx_sof_state <= IDLE;
					end if;
			end case;
		end if;
	end if;
end process;
mac_rx_sof <= mac_rx_tvalid and mac_rx_tready_int when mac_rx_sof_state = IDLE else '0';

udp_tx_sof_creator : process(clk)
begin
	if rising_edge(clk) then
		if rst = '1' then
			udp_tx_sof_state <= IDLE;
			udp_tx_sof <= '0';
		else
			case( udp_tx_sof_state ) is
				when IDLE =>
					udp_tx_sof <= '0';
					if udp_tx_tvalid = '1' and udp_tx_cts = '1' then
						udp_tx_sof_state <= WAIT_FOR_LAST;
						udp_tx_sof <= '1';
					end if;

				when WAIT_FOR_LAST =>
					udp_tx_sof <= '0';
					if udp_tx_tvalid = '1' and udp_tx_tlast = '1' then
						udp_tx_sof_state <= IDLE;
					end if;
			end case;
		end if;
	end if;
end process;
udp_tx_data_valid <= udp_tx_tvalid when udp_tx_sof_state = WAIT_FOR_LAST else '0';
udp_tx_eof <= udp_tx_tlast when udp_tx_sof_state = WAIT_FOR_LAST else '0';

--the ComBlock UDP_TX module can take a full packet when CTS is asserted.
--we could add a frame length check to make sure we don't try and send more than one frame
udp_tx_tready <= '1' when udp_tx_sof_state = WAIT_FOR_LAST else '0';

--TCP stream interface between Comblock CTS and AXIS tready For rx CTS is more
--like a read enable so use a small FIFO as an elastic buffer  and short-circuit
--the ready signal. When ready deasserts the Comblock stream will continue to
--flow for two clock cycles which can be soaked up by the FIFO.  When ready
--asserts then Comblock stream will take two clocks to get going again giving us time to catch up.

tcp_rx_handshake: axis_srl_fifo
generic map (
  DATA_WIDTH => 8,
  DEPTH => 32
)
port map (
  clk => clk,
  rst => rst,

  input_axis_tdata  => tcp_rx_data(0),
  input_axis_tvalid => tcp_rx_tvalid_int,
  input_axis_tready => open,
  input_axis_tlast  => '0',
  input_axis_tuser  => '0',

  output_axis_tdata  => tcp_rx_tdata,
  output_axis_tvalid => tcp_rx_tvalid,
  output_axis_tready => tcp_rx_tready,
  output_axis_tlast  => open,
  output_axis_tuser  => open,

  count => open
);

--Digging into the Comblock it appears tcp_tx_cts asserts when the buffer can
--take up to 128 bytes. Need to mask out valid though when CTS is low because
--AXIS thinks data is not accepted
tcp_tx_tready <= tcp_tx_cts;
tcp_tx_tvalid_int <= tcp_tx_tvalid when tcp_tx_cts = '1' else '0';

com5402_inst : entity work.COM5402_DHCP
generic map (
	NUDPTX => 1,
	NUDPRX => 1,
	IGMP_EN => '0',
	NTCPSTREAMS => 1,
	CLK_FREQUENCY => 125,
	SIMULATION => SIMULATION,
	WITH_DHCP_CLIENT => true,
	FIXED_IP => FIXED_IP
)
port map (
	CLK => clk,
	SYNC_RESET	=> rst,

	MAC_ADDR => mac_addr,
	REQUESTED_IPv4_ADDR => IPv4_addr,
	IPv6_ADDR => (others => '0'),
	MULTICAST_IP_ADDR => (others => '0'),
	SUBNET_MASK => subnet_mask,
	GATEWAY_IP_ADDR => gateway_ip_addr,
	DYNAMIC_IP => dhcp_enable,

	CONNECTION_RESET(0) => tcp_rst,

	MAC_TX_DATA => mac_tx_tdata,
	MAC_TX_DATA_VALID => mac_tx_tvalid,
	MAC_TX_SOF => open,
	MAC_TX_EOF => mac_tx_tlast_int,
	MAC_TX_CTS => mac_tx_tready,

	MAC_RX_DATA => mac_rx_tdata,
	MAC_RX_DATA_VALID => mac_rx_tvalid,
	MAC_RX_SOF => mac_rx_sof,
	MAC_RX_EOF => mac_rx_tlast_int,

	UDP_RX_DATA => udp_rx_tdata,
	UDP_RX_DATA_VALID => udp_rx_tvalid,
	UDP_RX_EOF	=> udp_rx_tlast,

	UDP_RX_DEST_PORT_NO_IN => udp_rx_dest_port,
	CHECK_UDP_RX_DEST_PORT_NO => '1',
	UDP_RX_DEST_PORT_NO_OUT => open,
	UDP_RX_SRC_PORT_NO => udp_rx_src_port,
	RX_SRC_IP_ADDR     => rx_src_ip_addr,

	UDP_TX_DATA => udp_tx_tdata,
	UDP_TX_DATA_VALID => udp_tx_data_valid,
	UDP_TX_SOF => udp_tx_sof,
	UDP_TX_EOF => udp_tx_eof,
	UDP_TX_CTS => udp_tx_cts,
	UDP_TX_ACK => udp_tx_ack,
	UDP_TX_NAK => udp_tx_nack,
	UDP_TX_DEST_IP_ADDR(127 downto 32) => (others => '0'), --ignore IPv6 for now
	UDP_TX_DEST_IP_ADDR(31 downto 0) => udp_tx_dest_ip_addr,
	UDP_TX_DEST_PORT_NO => udp_tx_dest_port,
	UDP_TX_SOURCE_PORT_NO => udp_tx_src_port,

	TCP_PORT_NO => tcp_port,

	TCP_RX_DATA => tcp_rx_data,
	TCP_RX_DATA_VALID(0) => tcp_rx_tvalid_int,
	TCP_RX_RTS => open,
	TCP_RX_CTS(0) => tcp_rx_tready,

	TCP_TX_DATA => tcp_tx_data,
	TCP_TX_DATA_VALID(0) => tcp_tx_tvalid_int,
	TCP_TX_CTS(0) => tcp_tx_cts
);

--std_logic_vector
tcp_tx_data(0) <= tcp_tx_tdata;

end architecture;
