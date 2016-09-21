-- Package for handling IPv4 headers, UDP and TCP packets
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ethernet_frame_pkg.byte_array;

package IPv4_packet_pkg is

subtype IPv4_addr_t is byte_array(0 to 3);

function header_checksum(header : byte_array) return std_logic_vector;

function ipv4_header(
	protocol : std_logic_vector(7 downto 0);
	packet_length : natural;
	src_IP : IPv4_addr_t;
	dest_IP : IPv4_addr_t
) return byte_array;

function udp_checksum(packet : byte_array) return std_logic_vector;

function udp_packet (
	src_IP : IPv4_addr_t;
	dest_IP : IPv4_addr_t;
	src_port  : std_logic_vector(15 downto 0);
	dest_port : std_logic_vector(15 downto 0);
	payload : byte_array
) return byte_array;

function tcp_checksum(packet : byte_array) return std_logic_vector;

function tcp_packet (
	src_IP : IPv4_addr_t;
	dest_IP : IPv4_addr_t;
	src_port  : std_logic_vector(15 downto 0);
	dest_port : std_logic_vector(15 downto 0);
	seq_num : natural;
	ack_num : natural;
	syn : std_logic;
	ack : std_logic;
	payload : byte_array
) return byte_array;


end IPv4_packet_pkg;

package body IPv4_packet_pkg is

	function header_checksum(header : byte_array) return std_logic_vector is
		variable sum : unsigned(31 downto 0) := (others => '0');
		variable checksum : std_logic_vector(15 downto 0);
		variable tmp : std_logic_vector(15 downto 0);
	begin
		--Sum header
		for ct in 0 to 9 loop
			--For some reason Vivado can't infer this as one line
			-- sum := sum + unsigned(header(2*ct) & header(2*ct+1))
			tmp := header(2*ct) & header(2*ct+1);
			sum := sum + unsigned(tmp);
		end loop;
		--Fold back in the carry
		checksum := std_logic_vector(sum(15 downto 0) + sum(31 downto 16));
		--Return one's complement
		return not checksum;
	end header_checksum;

	function ipv4_header(
		protocol : std_logic_vector(7 downto 0);
		packet_length : natural;
		src_IP : IPv4_addr_t;
		dest_IP : IPv4_addr_t
	) return byte_array is
		variable header : byte_array(0 to 19);
		variable len : unsigned(15 downto 0);
		variable checksum : std_logic_vector(15 downto 0);
		variable idx : natural := 0;
	begin
		header(0) := x"45"; --version and header length
		header(1) := x"00"; --type of service
		len := to_unsigned(packet_length, 16);
		header(2) := std_logic_vector(len(15 downto 8));
		header(3) := std_logic_vector(len(7 downto 0));
		header(4) := x"ba"; header(5) := x"ad"; -- identification
		header(6) := x"00"; header(7) := x"00"; --flags and fragment
		header(8) := x"80"; --time to live
		header(9) := protocol; --protocol
		header(10) := x"00"; header(11) := x"00"; --checksum
		idx := 12;
		--source IP
		for ct in 0 to 3 loop
			header(idx) := src_IP(ct);
			idx := idx + 1;
		end loop;
		--destination IP
		for ct in 0 to 3 loop
			header(idx) := dest_IP(ct);
			idx := idx + 1;
		end loop;
		--Calculate checksum and insert it
		checksum := header_checksum(header);
		header(10) := checksum(15 downto 8);
		header(11) := checksum(7 downto 0);

		return header;

	end ipv4_header;

	function udp_checksum(packet : byte_array) return std_logic_vector is
		variable sum : unsigned(31 downto 0) := (others => '0');
		variable checksum : std_logic_vector(15 downto 0);
		variable tmp : std_logic_vector(15 downto 0);
		variable udp_length : natural;
	begin
		--Extract pseudo packet header
		--source and dest IP
		for ct in 0 to 3 loop
			tmp := packet(12 + 2*ct) & packet(12 + 2*ct + 1);
			sum := sum + unsigned(tmp);
		end loop;
		--Protocol 0x0011
		sum := sum + to_unsigned(17, 32);
		--UDP length
		tmp := packet(24) & packet(25);
		sum := sum + unsigned(tmp);
		udp_length := to_integer(unsigned(tmp));
		for ct in 0 to udp_length/2 - 1 loop
			tmp := packet(20 + 2*ct) & packet(20 + 2*ct + 1);
			sum := sum + unsigned(tmp);
		end loop;
		--Fold back in carry
		checksum := std_logic_vector(sum(15 downto 0) + sum(31 downto 16));
		--return one's complement
		return not checksum;
	end udp_checksum;

	function udp_packet (
		src_IP : IPv4_addr_t;
		dest_IP : IPv4_addr_t;
		src_port  : std_logic_vector(15 downto 0);
		dest_port : std_logic_vector(15 downto 0);
		payload : byte_array
	) return byte_array is
		variable packet_length : natural := 20 + 8 + payload'length; --IPv4 header + UDP header
		variable len : unsigned(15 downto 0);
		variable checksum : std_logic_vector(15 downto 0);
		variable packet : byte_array(0 to packet_length-1);
	begin
		--IPv4 header
		packet(0 to 19) := ipv4_header(x"11", packet_length, src_IP, dest_IP);
		--UDP source and destination port
		packet(20) := src_port(15 downto 8);
		packet(21) := src_port(7 downto 0);
		packet(22) := dest_port(15 downto 8);
		packet(23) := dest_port(7 downto 0);
		--UDP packet length
		len := to_unsigned(8 + payload'length, 16);
  	packet(24) := std_logic_vector(len(15 downto 8));
		packet(25) := std_logic_vector(len(7 downto 0));
		--checksum
		packet(26) := x"00";
		packet(27) := x"00";
		--start after IPv4 + UDP header
		for ct in 0 to payload'high loop
			packet(28+ct) := payload(ct);
		end loop;
		--Go back and fill in checksum
		checksum := udp_checksum(packet);
		packet(26) := checksum(15 downto 8);
		packet(27) := checksum(7 downto 0);
		return packet;
	end udp_packet;

	function tcp_checksum(packet : byte_array) return std_logic_vector is
		variable sum : unsigned(31 downto 0) := (others => '0');
		variable checksum : std_logic_vector(15 downto 0);
		variable tmp : std_logic_vector(15 downto 0);
		variable tcp_length : natural;
	begin
		--Extract pseudo packet header
		--source and dest IP
		for ct in 0 to 3 loop
			tmp := packet(12 + 2*ct) & packet(12 + 2*ct + 1);
			sum := sum + unsigned(tmp);
		end loop;
		--Protocol 0x0006
		sum := sum + to_unsigned(6, 32);
		--tcp length - subtract off ipv4 header (20 bytes)
		tcp_length := packet'length - 20;
		sum := sum + to_unsigned(tcp_length, 32);
		for ct in 0 to tcp_length/2 - 1 loop
			tmp := packet(20 + 2*ct) & packet(20 + 2*ct + 1);
			sum := sum + unsigned(tmp);
		end loop;
		--Fold back in carry
		checksum := std_logic_vector(sum(15 downto 0) + sum(31 downto 16));
		--return one's complement
		return not checksum;
	end tcp_checksum;


	function tcp_packet (
		src_IP : IPv4_addr_t;
		dest_IP : IPv4_addr_t;
		src_port  : std_logic_vector(15 downto 0);
		dest_port : std_logic_vector(15 downto 0);
		seq_num : natural;
		ack_num : natural;
		syn : std_logic;
		ack : std_logic;
		payload : byte_array
	) return byte_array is
		variable packet_length : natural := 20 + 20 + payload'length; --IPv4 header + TCP header
		variable len : unsigned(15 downto 0);
		variable checksum : std_logic_vector(15 downto 0);
		variable packet : byte_array(0 to packet_length-1);
		variable num : std_logic_vector(31 downto 0);
	begin
		--IPv4 header
		packet(0 to 19) := ipv4_header(x"06", packet_length, src_IP, dest_IP);
		--TCP source and destination port
		packet(20) := src_port(15 downto 8);
		packet(21) := src_port(7 downto 0);
		packet(22) := dest_port(15 downto 8);
		packet(23) := dest_port(7 downto 0);

		--sequence number
		num := std_logic_vector(to_unsigned(seq_num, 32));
		packet(24) := num(31 downto 24);
		packet(25) := num(23 downto 16);
		packet(26) := num(15 downto 8);
		packet(27) := num(7 downto 0);

		--ack number
		num := std_logic_vector(to_unsigned(ack_num, 32));
		packet(28) := num(31 downto 24);
		packet(29) := num(23 downto 16);
		packet(30) := num(15 downto 8);
		packet(31) := num(7 downto 0);

		packet(32) := x"50"; --data offset
		--flags
		if payload'length > 0 then
			packet(33) := "000" & ack & "00" & syn & "0";
		else
			packet(33) := "000" & ack & "10" & syn & "0";
		end if;

		--window size
		packet(34) := x"08";
		packet(35) := x"00";

		--checksum
		packet(36) := x"00";
		packet(37) := x"00";

		--urgent pointer
		packet(38) := x"00"; packet(39) := x"00";

		for ct in 0 to payload'high loop
			packet(40+ct) := payload(ct);
		end loop;
		--Go back and fill in checksum
		checksum := tcp_checksum(packet);
		packet(36) := checksum(15 downto 8);
		packet(37) := checksum(7 downto 0);
		return packet;
	end tcp_packet;


end package body;
