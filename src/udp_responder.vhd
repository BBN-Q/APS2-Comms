-- Respond to APS2 UDP packets on port x"bb4e"
-- Implements an eumerate response; tcp port reset
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.udp_responder_pkg.all;

entity UDP_responder is
	port (
		clk : in std_logic;
		rst : in std_logic;

		udp_rx_tdata  : in std_logic_vector(7 downto 0);
		udp_rx_tvalid : in std_logic;
		udp_rx_tlast  : in std_logic;

		udp_src_port: in std_logic_vector(15 downto 0);
		src_ip_addr : in std_logic_vector(31 downto 0);

		dest_ip_addr  : out std_logic_vector(31 downto 0);
		udp_tx_tdata  : out std_logic_vector(7 downto 0);
		udp_tx_tvalid : out std_logic;
		udp_tx_tlast  : out std_logic;
		udp_tx_tready : in std_logic;
		udp_tx_ack    : in std_logic;
		udp_tx_nack   : in std_logic;

		rst_tcp : out std_logic

	);
end entity;

architecture arch of UDP_responder is

signal packet_in_error : std_logic := '0';
signal packet_in_tvalid : std_logic := '0';

signal packet_out_tdata : std_logic_vector(7 downto 0) := (others => '0');
signal packet_out_tvalid, packet_out_tready, packet_out_tlast : std_logic := '0';

signal overflow, good_frame, bad_frame : std_logic;

signal is_bbn_packet : boolean := false;
signal cur_cmd_vld	 : boolean := false;
signal cur_cmd : std_logic_vector(7 downto 0) := (others => '0');

type packet_processing_state_t is (IDLE, LATCH_COMMAND, DRAIN_PACKET);
signal packet_processing_state : packet_processing_state_t;

signal start_enumerate_resp, start_tcp_rst : std_logic := '0';

type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);
-- "I am an APS2"
constant ENUMERATE_RESPONSE : byte_array(0 to 11) :=
(x"49", x"20", x"61", x"6d", x"20", x"61", x"6e", x"20", x"41", x"50", x"53", x"32");

type enumerate_response_state_t is (IDLE, SEND_RESPONSE, WAIT_FOR_ACK, ARP_DELAY);
signal enumerate_response_state : enumerate_response_state_t;
signal enumerate_response_ct : integer range 0 to ENUMERATE_RESPONSE'length;

begin

--Convert from ComBlock error indicator (last high but valid low)
--and more conventional AXIS style with a tuser signal
packet_in_error <= udp_rx_tlast and not udp_rx_tvalid;
packet_in_tvalid <= udp_rx_tvalid or udp_rx_tlast;

--Store the packet in a FIFO to make sure we have a valid UDP packet
packet_fifo : axis_frame_fifo
	generic map (
		ADDR_WIDTH => 12,
		DATA_WIDTH => 8,
		DROP_WHEN_FULL => true
	)
	port map (
		clk => clk,
		rst => rst,

		input_axis_tdata	=> udp_rx_tdata,
		input_axis_tvalid => packet_in_tvalid,
		input_axis_tready => open,
		input_axis_tlast	=> udp_rx_tlast,
		input_axis_tuser	=> packet_in_error,

		output_axis_tdata	=> packet_out_tdata,
		output_axis_tvalid => packet_out_tvalid,
		output_axis_tready => packet_out_tready,
		output_axis_tlast	=> packet_out_tlast,

		overflow	 => overflow,
		bad_frame	=> bad_frame,
		good_frame => good_frame
	);

udp_src_port_check : process(clk)
	variable udp_src_port_l : std_logic_vector(15 downto 0);
begin
	if rising_edge(clk) then
		if rst = '1' then
			udp_src_port_l := (others => '0');
			is_bbn_packet <= false;
		else
			is_bbn_packet <= (udp_src_port_l = x"bb4f");
			if udp_rx_tlast = '1' then
				udp_src_port_l := udp_src_port;
			end if;
		end if;
	end if;
end process;

--Process packet and register command
packet_processing : process(clk)
begin
	if rising_edge(clk) then
		if rst = '1' then
			packet_processing_state <= IDLE;
			cur_cmd_vld <= false;
			cur_cmd <= (others => '0');
		else

			cur_cmd_vld <= false;

			case( packet_processing_state ) is

				when IDLE =>
					--Wait for a valid packet
					if packet_out_tvalid = '1' then
						if is_bbn_packet then
							packet_processing_state <= LATCH_COMMAND;
						else
							packet_processing_state <= DRAIN_PACKET;
						end if;
					end if;

				when LATCH_COMMAND =>
					cur_cmd <= packet_out_tdata;
					dest_ip_addr <= src_ip_addr;
					packet_processing_state <= DRAIN_PACKET;
					cur_cmd_vld <= true;

				when DRAIN_PACKET =>
					if packet_out_tlast = '1' then
						packet_processing_state <= IDLE;
					end if;
			end case;

		end if;
	end if;
end process;
packet_out_tready <= '1' when packet_processing_state = DRAIN_PACKET else '0';

--Process commands
command_processing : process(clk)
	type cmd_state_t is (IDLE, DECODE_CMD);
	variable cmd_state : cmd_state_t;
begin
	if rising_edge(clk) then
		if rst = '1' then
			cmd_state := IDLE;
			start_enumerate_resp <= '0';
			start_tcp_rst <= '0';
		else
			case( cmd_state ) is

				when IDLE =>
					start_enumerate_resp <= '0';
					start_tcp_rst <= '0';
					if cur_cmd_vld then
						cmd_state := DECODE_CMD;
					end if;

				when DECODE_CMD =>
					cmd_state := IDLE;
					case( cur_cmd ) is

						when x"01" =>
							start_enumerate_resp <= '1';

						when x"02" =>
							start_tcp_rst <= '1';

						when others =>
							null;

					end case;

			end case;
		end if;
	end if;
end process;

--Send enumerate response when start flag goes high
--If we get back a nack presumably the destination is not in the ARP table
--so wait 10ms from the ARP query-response and try again
enumerate_resp_pro : process(clk)
	constant NUM_TRIES : natural := 3;
	variable try_ct : natural range 0 to NUM_TRIES-1;
	constant ARP_DELAY_CLOCKS : natural := 1_250_000
	--pragma synthesis_off
	/1000
	--pragma synthesis_on
	; --10ms at 125 MHz - shorten to 10 us for simulation
	variable arp_delay_ct : unsigned(integer(ceil(log2(real(ARP_DELAY_CLOCKS)))) downto 0);
begin
	if rising_edge(clk) then
		if rst = '1' then
			enumerate_response_ct <= 0;
			try_ct := 0;
			arp_delay_ct := to_unsigned(ARP_DELAY_CLOCKS, arp_delay_ct'length);
		else
			enumerate_response_ct <= 0;

			case( enumerate_response_state ) is

				when IDLE =>
					try_ct := 0;
					if start_enumerate_resp = '1' then
						enumerate_response_state <= SEND_RESPONSE;
					end if;

				when SEND_RESPONSE =>
					if udp_tx_tready = '1' then
						if enumerate_response_ct = ENUMERATE_RESPONSE'high then
							enumerate_response_state <= WAIT_FOR_ACK;
						else
							enumerate_response_ct <= enumerate_response_ct + 1;
						end if;
					end if;

				when WAIT_FOR_ACK =>
					arp_delay_ct := to_unsigned(ARP_DELAY_CLOCKS, arp_delay_ct'length);
					if udp_tx_ack = '1' then
						enumerate_response_state <= IDLE;
					elsif udp_tx_nack = '1' then
						if try_ct = NUM_TRIES-1 then
							enumerate_response_state <= IDLE;
						else
							try_ct := try_ct + 1;
							enumerate_response_state <= ARP_DELAY;
						end if;
					end if;

				when ARP_DELAY =>
					if arp_delay_ct(arp_delay_ct'high) = '1' then
						enumerate_response_state <= SEND_RESPONSE;
					else
						arp_delay_ct := arp_delay_ct - 1;
					end if;

			end case;
		end if;


	end if;
end process;
udp_tx_tdata <= ENUMERATE_RESPONSE(enumerate_response_ct);
udp_tx_tvalid <= '1' when enumerate_response_state = SEND_RESPONSE else '0';
udp_tx_tlast <= '1' when (enumerate_response_state = SEND_RESPONSE) and
										(enumerate_response_ct = ENUMERATE_RESPONSE'high) else '0';

--Hold tcp reset high for a couple clocks when start flag goes high
tcp_reset_pro : process(clk)
 variable reset_line : std_logic_vector(1 downto 0);
begin
	if rising_edge(clk) then
		if rst = '1' then
			reset_line := (others => '1');
		else
			if start_tcp_rst = '1' then
				reset_line := (others => '1');
			else
				reset_line := reset_line(reset_line'high-1 downto 0) & '0';
			end if;
		end if;
		rst_tcp <= reset_line(reset_line'high);
	end if;
end process;

end architecture;
