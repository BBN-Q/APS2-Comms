-- Helper procedures for handling writing raw ethernet frames
---
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ethernet_frame_pkg is

type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);
subtype MACAddr_t is byte_array(0 to 5);

type APSCommand_t is record
	ack : std_logic;
	seq : std_logic;
	sel : std_logic;
	rw : std_logic;
	cmd : std_logic_vector(3 downto 0);
	mode : std_logic_vector(7 downto 0);
	cnt : std_logic_vector(15 downto 0);
end record;

type APSEthernetFrameHeader_t is record
	destMAC : MACAddr_t;
	srcMAC : MACAddr_t;
	seqNum : unsigned(15 downto 0);
	command : APSCommand_t;
	addr : std_logic_vector(31 downto 0);
end record;

type APSPayload_t is array(integer range <>) of std_logic_vector(7 downto 0);

procedure write_MAC_addr (
	macAddr : in MACAddr_t;
	signal clk : in std_logic;
	signal mac_rx_tdata : out std_logic_vector(7 downto 0);
	signal mac_rx_tready : in std_logic
);

procedure write_ethernet_frame_header (
	destMAC : in MACAddr_t;
	srcMAC : in MACAddr_t;
	frameType : in std_logic_vector(15 downto 0);
	signal clk : in std_logic;
	signal mac_rx_tdata : out std_logic_vector(7 downto 0);
	signal mac_rx_tready : in std_logic
);

procedure write_ethernet_frame(
	destMAC : in MACAddr_t;
	srcMAC : in MACAddr_t;
	frameType : in std_logic_vector(15 downto 0);
	payload : byte_array;
	signal clk : in std_logic;
	signal mac_rx_tdata  : out std_logic_vector(7 downto 0);
	signal mac_rx_tvalid : out std_logic;
	signal mac_rx_tlast  : out std_logic;
	signal mac_rx_tready : in std_logic
);


-- procedure write_APS_command(cmd : in APSCommand_t; signal mac_rx : out std_logic_vector(7 downto 0); signal clk : in std_logic);
--
-- procedure write_APSEthernet_frame(frame : in APSEthernetFrameHeader_t; payload : in APSPayload_t; signal mac_rx : out std_logic_vector(7 downto 0);
-- 	signal clk : in std_logic; signal rx_valid : out std_logic; signal rx_eop : out std_logic; seqNum : in natural := 0; badFCS : in boolean := false; signal mac_fcs : out std_logic );

end ethernet_frame_pkg;

package body ethernet_frame_pkg is


procedure write_MAC_addr (
	macAddr : in MACAddr_t;
	signal clk : in std_logic;
	signal mac_rx_tdata : out std_logic_vector(7 downto 0);
	signal mac_rx_tready : in std_logic
) is
begin
		for ct in 0 to 5 loop
			mac_rx_tdata <= macAddr(ct);
			wait until rising_edge(clk) and mac_rx_tready = '1';
		end loop;
end procedure write_MAC_addr;

procedure write_ethernet_frame_header (
	destMAC : in MACAddr_t;
	srcMAC : in MACAddr_t;
	frameType : in std_logic_vector(15 downto 0);
	signal clk : in std_logic;
	signal mac_rx_tdata : out std_logic_vector(7 downto 0);
	signal mac_rx_tready : in std_logic
) is
begin
	write_MAC_addr(destMAC, clk, mac_rx_tdata, mac_rx_tready);
	write_MAC_addr(srcMAC, clk, mac_rx_tdata, mac_rx_tready);
	mac_rx_tdata <= frameType(15 downto 8); wait until rising_edge(clk) and mac_rx_tready = '1';
	mac_rx_tdata <= frameType(7 downto 0); wait until rising_edge(clk) and mac_rx_tready = '1';
end procedure write_ethernet_frame_header;

procedure write_ethernet_frame(
	destMAC : in MACAddr_t;
	srcMAC : in MACAddr_t;
	frameType : in std_logic_vector(15 downto 0);
	payload : byte_array;
	signal clk : in std_logic;
	signal mac_rx_tdata : out std_logic_vector(7 downto 0);
	signal mac_rx_tvalid : out std_logic;
	signal mac_rx_tlast  : out std_logic;
	signal mac_rx_tready : in std_logic
) is
begin
	mac_rx_tvalid <= '1';
	mac_rx_tlast <= '0';
	write_ethernet_frame_header(destMAC, srcMAC, frameType, clk, mac_rx_tdata, mac_rx_tready);
	for ct in 0 to payload'high loop
		mac_rx_tdata <= payload(ct);
		if ct = payload'high and ct >= 46 then
			mac_rx_tlast <= '1';
		end if;
		wait until rising_edge(clk) and mac_rx_tready = '1';
	end loop;
	--Pad out 64 byte frame
	for ct in (46 - payload'length - 1) downto 0 loop
		mac_rx_tdata <= (others => '0');
		if ct = 0 then
			mac_rx_tlast <= '1';
		end if;
		wait until rising_edge(clk) and mac_rx_tready = '1';
	end loop;
	mac_rx_tvalid <= '0';
	mac_rx_tlast <= '0';
end procedure write_ethernet_frame;

-- procedure write_APS_command(cmd : in APSCommand_t; signal mac_rx : out std_logic_vector(7 downto 0); signal clk : in std_logic) is
-- begin
-- 	mac_rx <= cmd.ack & cmd.seq & cmd.sel & cmd.rw & cmd.cmd; wait until rising_edge(clk);
-- 	mac_rx <= cmd.mode; wait until rising_edge(clk);
-- 	mac_rx <= cmd.cnt(15 downto 8); wait until rising_edge(clk);
-- 	mac_rx <= cmd.cnt(7 downto 0); wait until rising_edge(clk);
-- end procedure write_APS_command;


-- procedure write_APSEthernet_frame(frame : in APSEthernetFrameHeader_t; payload : in APSPayload_t; signal mac_rx : out std_logic_vector(7 downto 0);
-- 	signal clk : in std_logic; signal rx_valid : out std_logic; signal rx_eop : out std_logic; seqNum : in natural := 0; badFCS : in boolean := false; signal mac_fcs : out std_logic  ) is
--
-- variable seqNum_u : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(seqNum, 16));
-- begin
--
-- 	rx_valid <= '1';
--
-- 	write_ethernet_frame_header(frame.destMAC, frame.srcMAC, x"BB4E", mac_rx, clk);
--
-- 	--seq. num.
-- 	mac_rx <= seqNum_u(15 downto 8); wait until rising_edge(clk);
-- 	mac_rx <= seqNum_u(7 downto 0); wait until rising_edge(clk);
--
-- 	--command
-- 	write_APS_command(frame.command, mac_rx, clk);
--
-- 	--address
-- 	for ct in 4 downto 1 loop
-- 		--if there is no payload then the packet ends here
-- 		if (payload'length = 0) and (ct = 1) then
-- 			rx_eop <= '1';
-- 			if badFCS then
-- 				mac_fcs <= '1';
-- 			end if;
-- 		end if;
-- 		mac_rx <= frame.addr(ct*8-1 downto (ct-1)*8); wait until rising_edge(clk);
-- 	end loop;
--
-- 	-- clock in the payload
-- 	for ct in payload'range loop
-- 		--signal end of packet on the last byte
-- 		if ct = payload'right then
-- 			rx_eop <= '1';
-- 			if badFCS then
-- 				mac_fcs <= '1';
-- 			end if;
-- 		end if;
-- 		mac_rx <= payload(ct); wait until rising_edge(clk);
-- 	end loop;
--
-- 	--Frame check sequence
-- 	--Not passed through as FCS In Band Enable is disabled in the configuration vector
-- 	--rx_valid <= '0';
-- 	--for ct in 1 to 4 loop
-- 	--	wait until rising_edge(clk);
-- 	--end loop;
--
-- 	--Interframe gap of four beats
-- 	rx_valid <= '0';
-- 	rx_eop <= '0';
-- 	mac_fcs <= '0';
-- 	for ct in 1 to 4 loop
-- 		wait until rising_edge(clk);
-- 	end loop;
--
--
-- end procedure write_APSEthernet_frame;

end package body;
