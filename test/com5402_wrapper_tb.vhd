-- Testbench for com5402_wrapper
--
-- * ARP requests
-- * broadcast udp rx
-- * unicast udp rx
-- * unicast udp rx filtering
-- * udp tx with NACK from ComBlock
-- * tcp conneciton establish
-- * tcp tx with tready deasserting
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.ethernet_frame_pkg.all;
use work.IPv4_packet_pkg.all;

entity com5402_wrapper_tb is
end;

architecture bench of com5402_wrapper_tb is

  constant APS2_UDP_PORT     : std_logic_vector(15 downto 0) := x"bb4f";
  constant UUT_MAC_ADDR      : MACAddr_t := (x"46", x"1d", x"db", x"11", x"22", x"33");
  constant UUT_IP_ADDR       : IPv4_addr_t := (x"c0", x"a8", x"02", x"03");
  constant HOST_MAC_ADDR     : MACAddr_t := (x"ba", x"ad", x"0d", x"db", x"a1", x"11");
  constant HOST_IP_ADDR      : IPv4_addr_t := (x"c0", x"a8", x"02", x"01");
  constant HOST2_MAC_ADDR    : MACAddr_t := (x"ba", x"ad", x"0d", x"db", x"a1", x"12");
  constant HOST2_IP_ADDR     : IPv4_addr_t := (x"c0", x"a8", x"02", x"51");
  constant BROADCAST_IP_ADDR : IPv4_addr_t := (x"c0", x"a8", x"02", x"ff");
  constant WRONG_IP_ADDR     : IPv4_addr_t := (x"c0", x"a8", x"02", x"04");
  constant BROADCAST_MAC_ADDR : MACAddr_t := (x"ff", x"ff", x"ff", x"ff", x"ff", x"ff");

  -- "I am an APS2"
  constant ENUMERATE_RESPONSE : byte_array :=
  (x"49", x"20", x"61", x"6d", x"20", x"61", x"6e", x"20", x"41", x"50", x"53", x"32");

  signal clk : std_logic := '0';
  signal rst : std_logic := '0';
  signal mac_addr : std_logic_vector(47 downto 0) := UUT_MAC_ADDR(0) & UUT_MAC_ADDR(1) & UUT_MAC_ADDR(2) & UUT_MAC_ADDR(3) & UUT_MAC_ADDR(4) & UUT_MAC_ADDR(5);
  signal IPv4_addr : std_logic_vector(31 downto 0) := UUT_IP_ADDR(0) & UUT_IP_ADDR(1) & UUT_IP_ADDR(2) & UUT_IP_ADDR(3);
  signal subnet_mask : std_logic_vector(31 downto 0) := x"ffffff00";
  signal gateway_ip_addr : std_logic_vector(31 downto 0) := x"c0a80201";
  signal tcp_rst : std_logic := '0';
  signal dhcp_enable : std_logic := '0';

  signal mac_tx_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal mac_tx_tvalid : std_logic := '0';
  signal mac_tx_tlast  : std_logic := '0';
  signal mac_tx_tuser  : std_logic := '0';
  signal mac_tx_tready : std_logic := '1';
  signal mac_rx_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal mac_rx_tvalid : std_logic := '0';
  signal mac_rx_tlast  : std_logic := '0';
  signal mac_rx_tuser  : std_logic := '0';
  signal mac_rx_tready : std_logic := '0';

  signal udp_rx_tdata    : std_logic_vector(7 downto 0) := (others => '0');
  signal udp_rx_tvalid   : std_logic := '0';
  signal udp_rx_tlast    : std_logic := '0';
  signal udp_rx_src_port : std_logic_vector(15 downto 0) := (others => '0');
  signal rx_src_ip_addr  : std_logic_vector(31 downto 0);

  signal udp_tx_tdata        : std_logic_vector(7 downto 0) := (others => '0');
  signal udp_tx_tvalid       : std_logic := '0';
  signal udp_tx_tlast        : std_logic := '0';
  signal udp_tx_tready       : std_logic := '0';
  signal udp_tx_src_port     : std_logic_vector(15 downto 0) := APS2_UDP_PORT;
  signal udp_tx_dest_port    : std_logic_vector(15 downto 0) := APS2_UDP_PORT;
  signal udp_tx_dest_ip_addr : std_logic_vector(31 downto 0) := HOST2_IP_ADDR(0) & HOST2_IP_ADDR(1) & HOST2_IP_ADDR(2) & HOST2_IP_ADDR(3);
  signal udp_tx_ack          : std_logic;
  signal udp_tx_nack         : std_logic;

  signal tcp_port      : std_logic_vector(15 downto 0) := x"bb4e";
  signal tcp_rx_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal tcp_rx_tvalid : std_logic := '0';
  signal tcp_rx_tready : std_logic := '1';
  signal tcp_tx_tdata  : std_logic_vector(7 downto 0) := (others => '0');
  signal tcp_tx_tvalid : std_logic := '0';
  signal tcp_tx_tready : std_logic := '0';

  constant clock_period: time := 8 ns;
  signal stop_the_clock: boolean := false;

  type TestBenchState_t is (RESET, ARP_REQUEST, UDP_BROADCAST_RX, UDP_UNICAST_RX,
                            NO_INTERFRAME_GAP, UDP_UNICAST_IP_FILTER, UDP_TX,
                            ARP_RESPONSE, UDP_TX_RETRY, TCP_ESTABLISH, TCP_RX, DHCP);
  signal testBench_state : TestBenchState_t;

  signal checking_finished : boolean := false;

  shared variable tcp_test_payload : byte_array(0 to 1023);

begin

  uut: entity work.com5402_wrapper
    generic map ( SIMULATION => '1')
    port map (
      clk             => clk,
      rst             => rst,
      tcp_rst         => tcp_rst,
      mac_addr        => mac_addr,
      IPv4_addr       => IPv4_addr,
      subnet_mask     => subnet_mask,
      gateway_ip_addr => gateway_ip_addr,
      dhcp_enable     => dhcp_enable,

      mac_tx_tdata    => mac_tx_tdata,
      mac_tx_tvalid   => mac_tx_tvalid,
      mac_tx_tlast    => mac_tx_tlast,
      mac_tx_tuser    => mac_tx_tuser,
      mac_tx_tready   => mac_tx_tready,
      mac_rx_tdata    => mac_rx_tdata,
      mac_rx_tvalid   => mac_rx_tvalid,
      mac_rx_tlast    => mac_rx_tlast,
      mac_rx_tuser    => mac_rx_tuser,
      mac_rx_tready   => mac_rx_tready,

      udp_rx_tdata     => udp_rx_tdata,
      udp_rx_tvalid    => udp_rx_tvalid,
      udp_rx_tlast     => udp_rx_tlast,
      udp_rx_dest_port => APS2_UDP_PORT,
      udp_rx_src_port  => udp_rx_src_port,
      rx_src_ip_addr   => rx_src_ip_addr,

      udp_tx_tdata        => udp_tx_tdata,
      udp_tx_tvalid       => udp_tx_tvalid,
      udp_tx_tlast        => udp_tx_tlast,
      udp_tx_tready       => udp_tx_tready,
      udp_tx_src_port     => udp_tx_src_port,
      udp_tx_dest_port    => udp_tx_dest_port,
      udp_tx_dest_ip_addr => udp_tx_dest_ip_addr,
      udp_tx_ack          => udp_tx_ack,
      udp_tx_nack         => udp_tx_nack,

      tcp_port        => tcp_port,
      tcp_rx_tdata    => tcp_rx_tdata,
      tcp_rx_tvalid   => tcp_rx_tvalid,
      tcp_rx_tready   => tcp_rx_tready,
      tcp_tx_tdata    => tcp_tx_tdata,
      tcp_tx_tvalid   => tcp_tx_tvalid,
      tcp_tx_tready   => tcp_tx_tready
    );

  clk <= not clk after clock_period / 2 when not stop_the_clock;

  stimulus: process

  constant ARP_req : byte_array := (
    x"00", x"01", -- hardware type
    x"08", x"00", -- protocol type
    x"06", --hardware length (MAC address is 6 bytes)
    x"04", --protocol size
    x"00", x"01", -- request operation
    HOST_MAC_ADDR(0), HOST_MAC_ADDR(1), HOST_MAC_ADDR(2),
    HOST_MAC_ADDR(3), HOST_MAC_ADDR(4), HOST_MAC_ADDR(5), --sender MAC address
    HOST_IP_ADDR(0), HOST_IP_ADDR(1), HOST_IP_ADDR(2), HOST_IP_ADDR(3), --sender IPv4 address
    x"00", x"00", x"00", x"00", x"00", x"00", --target MAC address; empty for request
    UUT_IP_ADDR(0), UUT_IP_ADDR(1), UUT_IP_ADDR(2), UUT_IP_ADDR(3) -- target IP address
  );

  constant ARP_resp : byte_array := (
    x"00", x"01", -- hardware type
    x"08", x"00", -- protocol type
    x"06", --hardware length (MAC address is 6 bytes)
    x"04", --protocol size
    x"00", x"02", -- response operation
    HOST2_MAC_ADDR(0), HOST2_MAC_ADDR(1), HOST2_MAC_ADDR(2),
    HOST2_MAC_ADDR(3), HOST2_MAC_ADDR(4), HOST2_MAC_ADDR(5), --sender MAC address
    HOST2_IP_ADDR(0), HOST2_IP_ADDR(1), HOST2_IP_ADDR(2), HOST2_IP_ADDR(3), -- sender IP address
    UUT_MAC_ADDR(0), UUT_MAC_ADDR(1), UUT_MAC_ADDR(2),
    UUT_MAC_ADDR(3), UUT_MAC_ADDR(4), UUT_MAC_ADDR(5), --target MAC address
    UUT_IP_ADDR(0), UUT_IP_ADDR(1), UUT_IP_ADDR(2), UUT_IP_ADDR(3) --target IPv4 address
  );

  constant empty_payload : byte_array(0 to -1) := (others => (others => '0'));

  constant UDP_test_payload : byte_array := (x"01", x"02", x"03", x"04");

  variable tcp_response_packet : byte_array(0 to 1521);
  variable ct : natural;

  variable seq_num, ack_num, recv_seq_num, recv_ack_num : natural;
  variable tmp : std_logic_vector(31 downto 0);

  variable src_MAC, dest_MAC : MACAddr_t := (others => (others => '0'));

  variable timeout : time;

  begin

    wait until rising_edge(clk);

--------------------------------------------------------------------------------

    testBench_state <= RESET;
    rst <= '1';
    wait for 100ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait for 100ns;

    wait until rising_edge(clk);

--------------------------------------------------------------------------------

    testBench_state <= ARP_REQUEST;

    --ARP request who has 192.168.2.3? Tell 192.168.2.1";
    src_MAC := (x"ba", x"ad", x"0d", x"db", x"a1", x"11");
  	dest_MAC := (x"FF", x"FF", x"FF", x"FF", x"FF", x"FF");
    write_ethernet_frame(dest_MAC, src_MAC, x"0806", ARP_req, clk, mac_rx_tdata,
      mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);
    mac_rx_tlast <= '1';

    --wait for the response to come back
    wait until rising_edge(clk) and mac_tx_tvalid = '1' and mac_tx_tlast = '1' for 1us;

    --Make sure nothing else comes back
    --coverage for issue #26
    timeout := now + 5 us;
    while now < timeout loop
      wait until rising_edge(clk);
      assert mac_tx_tvalid = '0' report "mac_tx traffic when there shouldn't be";
      assert mac_tx_tlast = '0' report "mac_tx traffic when there shouldn't be";
    end loop;

--------------------------------------------------------------------------------

    --Clock in a broadcast UDP packet
    testBench_state <= UDP_BROADCAST_RX;
    dest_MAC := UUT_MAC_ADDR;
    write_ethernet_frame(BROADCAST_MAC_ADDR, src_MAC, x"0800",
    udp_packet(HOST_IP_ADDR, BROADCAST_IP_ADDR, x"abcd", APS2_UDP_PORT, UDP_test_payload),
    clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    --interframe gap
    for ct in 1 to 12 loop
      wait until rising_edge(clk);
    end loop;

    --Clock in an unicast UDP packet to the correct IP
    testBench_state <= UDP_UNICAST_RX;
    dest_MAC := UUT_MAC_ADDR;
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      udp_packet(HOST_IP_ADDR, UUT_IP_ADDR, APS2_UDP_PORT, APS2_UDP_PORT, UDP_test_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    --repeat with no interframe gap to test gap adder
    testBench_state <= NO_INTERFRAME_GAP;
    dest_MAC := UUT_MAC_ADDR;
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      udp_packet(HOST_IP_ADDR, UUT_IP_ADDR, APS2_UDP_PORT, APS2_UDP_PORT, UDP_test_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    --interframe gap
    for ct in 1 to 12 loop
      wait until rising_edge(clk);
    end loop;

    --Clock in a unicast UDP packet to the wrong IP
    testBench_state <= UDP_UNICAST_IP_FILTER;
    dest_MAC := UUT_MAC_ADDR;
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      udp_packet(HOST_IP_ADDR, WRONG_IP_ADDR, APS2_UDP_PORT, APS2_UDP_PORT, UDP_test_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

--------------------------------------------------------------------------------

    --Try to send a response to UDP
    --Send to different host to trigger ARP request and NACK
    testBench_state <= UDP_TX;
    wait until rising_edge(clk);
    for ct in 0 to ENUMERATE_RESPONSE'high loop
      udp_tx_tdata <= ENUMERATE_RESPONSE(ct);
      udp_tx_tvalid <= '1';
      if ct = ENUMERATE_RESPONSE'high then
        udp_tx_tlast <= '1';
      else
        udp_tx_tlast <= '0';
      end if;
      wait until rising_edge(clk) and udp_tx_tready = '1';
    end loop;
    udp_tx_tvalid <= '0';
    udp_tx_tlast <= '0';

    wait until mac_tx_tvalid = '1' and mac_tx_tlast = '1' for 5 us;

    --Send back the ARP response
    testBench_state <= ARP_RESPONSE;
    src_MAC := (x"ba", x"ad", x"0d", x"db", x"a1", x"12");
    write_ethernet_frame(dest_MAC, src_MAC, x"0806", ARP_resp, clk, mac_rx_tdata,
      mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    wait for 5 us;

    --Try again the UDP_TX
    testBench_state <= UDP_TX_RETRY;
    wait until rising_edge(clk);
    for ct in 0 to ENUMERATE_RESPONSE'high loop
      udp_tx_tdata <= ENUMERATE_RESPONSE(ct);
      udp_tx_tvalid <= '1';
      if ct = ENUMERATE_RESPONSE'high then
        udp_tx_tlast <= '1';
      else
        udp_tx_tlast <= '0';
      end if;
      wait until rising_edge(clk) and udp_tx_tready = '1';
    end loop;
    udp_tx_tvalid <= '0';
    udp_tx_tlast <= '0';

    wait until mac_tx_tvalid = '1' and mac_tx_tlast = '1' for 5 us;

--------------------------------------------------------------------------------

    --Try to establish TCP connection
    seq_num := 0;
    ack_num := 0;
    testBench_state <= TCP_ESTABLISH;
    wait until rising_edge(clk);
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      tcp_packet(HOST_IP_ADDR, UUT_IP_ADDR, x"bb4f", x"bb4e", seq_num, ack_num, '1', '0', empty_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    --extract the sequence and ack number returned
    ct := 0;
    loop
      wait until rising_edge(clk) and  mac_tx_tvalid = '1';
      tcp_response_packet(ct) := mac_tx_tdata;
      ct := ct + 1;
      exit when mac_tx_tlast = '1';
    end loop;
    --sequence number starts at byte 14 (ethernet frame header) + 20 (IPv4 header) + 4 (tcp src/dest port)= 38
    --For some reason Vivado can't infer this as one line
    -- recv_seq_num := to_integer(unsigned( tcp_response_packet(38) & tcp_response_packet(39) & tcp_response_packet(40) & tcp_response_packet(41) ) );
    -- recv_ack_num := to_integer(unsigned( tcp_response_packet(42) & tcp_response_packet(43) & tcp_response_packet(44) & tcp_response_packet(45) ) );
    tmp := tcp_response_packet(38) & tcp_response_packet(39) & tcp_response_packet(40) & tcp_response_packet(41);
    recv_seq_num := to_integer(unsigned(tmp));
    tmp := tcp_response_packet(42) & tcp_response_packet(43) & tcp_response_packet(44) & tcp_response_packet(45);
    recv_ack_num := to_integer(unsigned(tmp));
    ack_num := recv_seq_num + 1;
    seq_num := recv_ack_num;

    --send ack back to finish connection established
    wait until rising_edge(clk);
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      tcp_packet(HOST_IP_ADDR, UUT_IP_ADDR, x"bb4f", x"bb4e", seq_num, ack_num, '0', '1', empty_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    --interframe gap
    for ct in 1 to 12 loop
      wait until rising_edge(clk);
    end loop;

    --send data
    testBench_state <= TCP_RX;
    for k in 0 to 1023 loop
      tcp_test_payload(k) := std_logic_vector(to_unsigned(k, 8));
    end loop;
    wait until rising_edge(clk);
    write_ethernet_frame(dest_MAC, src_MAC, x"0800",
      tcp_packet(HOST_IP_ADDR, UUT_IP_ADDR, x"bb4f", x"bb4e", seq_num, ack_num, '0', '1', tcp_test_payload),
      clk, mac_rx_tdata, mac_rx_tvalid, mac_rx_tlast, mac_rx_tready);

    ct := 0;
    loop
      wait until rising_edge(clk) and  mac_tx_tvalid = '1';
      tcp_response_packet(ct) := mac_tx_tdata;
      ct := ct + 1;
      exit when mac_tx_tlast = '1';
    end loop;

    --wait for the data to show up
    wait until tcp_rx_tvalid = '1' for 100 ns;
    -- let the first half go by then start dropping ready periodically
    ct := 0;
    loop
      if ct < 512 then
        tcp_rx_tready <= '1';
        wait until rising_edge(clk);
      else
        if (ct mod 16) = 0 then
          tcp_rx_tready <= '0';
          wait until rising_edge(clk);
          wait until rising_edge(clk);
        else
          tcp_rx_tready <= '1';
          wait until rising_edge(clk);
        end if;
      end if;
      ct := ct + 1;
      exit when ct = 1024;
    end loop;
    tcp_rx_tready <= '1';
    wait for 500 ns;

--------------------------------------------------------------------------------

    testBench_state <= DHCP;
    dhcp_enable <= '1';
    wait until mac_tx_tvalid = '1' and mac_tx_tlast = '1' for 250us;


    assert checking_finished report "Checking process failed to finish";
    wait for 1 us;
    stop_the_clock <= true;

  end process;

  checking : process
    constant ARP_resp : byte_array := (
      x"00", x"01", -- hardware type
      x"08", x"00", -- protocol type
      x"06", --hardware length (MAC address is 6 bytes)
      x"04", --protocol size
      x"00", x"02", -- response operation
      UUT_MAC_ADDR(0), UUT_MAC_ADDR(1), UUT_MAC_ADDR(2),
      UUT_MAC_ADDR(3), UUT_MAC_ADDR(4), UUT_MAC_ADDR(5), --sender MAC address
      UUT_IP_ADDR(0), UUT_IP_ADDR(1), UUT_IP_ADDR(2), UUT_IP_ADDR(3), --sender IPv4 address
      HOST_MAC_ADDR(0), HOST_MAC_ADDR(1), HOST_MAC_ADDR(2),
      HOST_MAC_ADDR(3), HOST_MAC_ADDR(4), HOST_MAC_ADDR(5), --target MAC address
      HOST_IP_ADDR(0), HOST_IP_ADDR(1), HOST_IP_ADDR(2), HOST_IP_ADDR(3) -- target IP address
    );

    constant ARP_req : byte_array := (
      x"00", x"01", -- hardware type
      x"08", x"00", -- protocol type
      x"06", --hardware length (MAC address is 6 bytes)
      x"04", --protocol size
      x"00", x"01", -- request operation
      UUT_MAC_ADDR(0), UUT_MAC_ADDR(1), UUT_MAC_ADDR(2),
      UUT_MAC_ADDR(3), UUT_MAC_ADDR(4), UUT_MAC_ADDR(5), --sender MAC address
      UUT_IP_ADDR(0), UUT_IP_ADDR(1), UUT_IP_ADDR(2), UUT_IP_ADDR(3), --sender IPv4 address
      x"00", x"00", x"00", x"00", x"00", x"00", --target MAC address; empty for request
      HOST2_IP_ADDR(0), HOST2_IP_ADDR(1), HOST2_IP_ADDR(2), HOST2_IP_ADDR(3) -- target IP address
    );

  begin

--------------------------------------------------------------------------------

    --First thing back is the ARP response
    --Ethernet frame header
    for ct in 0 to 5 loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = HOST_MAC_ADDR(ct) report "ARP response ethernet frame MAC header incorrect";
    end loop;
    for ct in 0 to 5 loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = UUT_MAC_ADDR(ct) report "ARP response ethernet frame MAC header incorrect";
    end loop;
    --Ethernet type
    wait until rising_edge(clk) and mac_tx_tvalid = '1';
    assert mac_tx_tdata = x"08" report "ARP response ethernet frame MAC header incorrect";
    wait until rising_edge(clk) and mac_tx_tvalid = '1';
    assert mac_tx_tdata = x"06" report "ARP response ethernet frame MAC header incorrect";
    for ct in 0 to ARP_resp'high loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = ARP_resp(ct) report "ARP response payload incorrect";
      if ct = ARP_resp'high then
        assert mac_tx_tlast = '1' report "tlast failed to assert end of ARP response";
      else
        assert mac_tx_tlast = '0' report "tlast asserted early in ARP response";
      end if;
    end loop;

--------------------------------------------------------------------------------

    -- broadcast UDP packet at udp_rx should come through
    wait until rising_edge(clk) and mac_rx_tvalid = '1';
    -- wait for header (14 Ethernet + 20 IP + 8 UDP) and latency (4)
    for ct in 1 to 46 loop
      wait until rising_edge(clk);
    end loop;
    assert udp_rx_src_port = x"abcd" report "UDP source port incorrect";
    assert rx_src_ip_addr = HOST_IP_ADDR(0) & HOST_IP_ADDR(1) & HOST_IP_ADDR(2) & HOST_IP_ADDR(3) report "RX source IP address incorrect";
    for ct in 0 to 3 loop
      assert udp_rx_tdata = std_logic_vector(to_unsigned(ct+1,8));
      assert udp_rx_tvalid = '1' report "udp_rx_tvalid failed to assert";
      if ct = 3 then
        assert udp_rx_tlast = '1' report "udp_rx_tlast failed to assert";
      else
        assert udp_rx_tlast = '0' report "udp_rx_tlast asserted incorrectly";
        wait until rising_edge(clk);
      end if;
    end loop;
    --wait for end of packet
    wait until rising_edge(clk) and mac_rx_tlast = '1' for 1 us;

    ---unicast UDP packet at udp_rx
    wait until rising_edge(clk) and mac_rx_tvalid = '1';
    -- wait for header (14 Ethernet + 20 IP + 8 UDP) and latency (4)
    for ct in 1 to 46 loop
      wait until rising_edge(clk);
    end loop;
    assert udp_rx_src_port = APS2_UDP_PORT report "UDP source port incorrect";
    assert rx_src_ip_addr = HOST_IP_ADDR(0) & HOST_IP_ADDR(1) & HOST_IP_ADDR(2) & HOST_IP_ADDR(3) report "RX source IP address incorrect";
    for ct in 0 to 3 loop
      assert udp_rx_tdata = std_logic_vector(to_unsigned(ct+1,8));
      assert udp_rx_tvalid = '1' report "udp_rx_tvalid failed to assert";
      if ct = 3 then
        assert udp_rx_tlast = '1' report "udp_rx_tlast failed to assert";
      else
        assert udp_rx_tlast = '0' report "udp_rx_tlast asserted incorrectly";
        wait until rising_edge(clk);
      end if;
    end loop;
    --wait for end of packet
    wait until rising_edge(clk) and mac_rx_tlast = '1' for 1 us;

    ---second unicast UDP packet at udp_rx should be delayed by added interframe gap
    wait until rising_edge(clk) and mac_rx_tvalid = '1';
    for ct in 1 to 8 loop
      assert mac_rx_tready = '0' report "mac_rx_tready failed to deassert for interframe gap";
      wait until rising_edge(clk);
    end loop;
    -- wait for header (14 Ethernet + 20 IP + 8 UDP) and latency (4)
    for ct in 1 to 46 loop
      wait until rising_edge(clk);
    end loop;
    assert udp_rx_src_port = APS2_UDP_PORT report "UDP source port incorrect";
    assert rx_src_ip_addr = HOST_IP_ADDR(0) & HOST_IP_ADDR(1) & HOST_IP_ADDR(2) & HOST_IP_ADDR(3) report "RX source IP address incorrect";
    for ct in 0 to 3 loop
      assert udp_rx_tdata = std_logic_vector(to_unsigned(ct+1,8));
      assert udp_rx_tvalid = '1' report "udp_rx_tvalid failed to assert";
      if ct = 3 then
        assert udp_rx_tlast = '1' report "udp_rx_tlast failed to assert";
      else
        assert udp_rx_tlast = '0' report "udp_rx_tlast asserted incorrectly";
        wait until rising_edge(clk);
      end if;
    end loop;
    --wait for end of packet
    wait until rising_edge(clk) and mac_rx_tlast = '1' for 1 us;

    ---unicast UDP packet to different IP address should not come through at udp_rx
    wait until rising_edge(clk) and mac_rx_tvalid = '1';
    -- wait for header (14 Ethernet + 20 IP + 8 UDP) and latency (4)
    for ct in 1 to 46 loop
      wait until rising_edge(clk);
    end loop;
    for ct in 0 to 3 loop
        assert udp_rx_tvalid = '0' report "udp_rx_tvalid asserted incorrectly";
        wait until rising_edge(clk);
    end loop;
    --wait for end of packet
    wait until rising_edge(clk) and mac_rx_tlast = '1' for 1 us;

--------------------------------------------------------------------------------

    --Next is a ARP request at mac_tx
    --Ethernet frame header
    for ct in 0 to 5 loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = x"ff" report "ARP request ethernet frame MAC header incorrect";
    end loop;
    for ct in 0 to 5 loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = UUT_MAC_ADDR(ct) report "ARP request ethernet frame MAC header incorrect";
    end loop;
    --Ethernet type
    wait until rising_edge(clk) and mac_tx_tvalid = '1';
    assert mac_tx_tdata = x"08" report "ARP request ethernet frame MAC header incorrect";
    wait until rising_edge(clk) and mac_tx_tvalid = '1';
    assert mac_tx_tdata = x"06" report "ARP request ethernet frame MAC header incorrect";
    for ct in 0 to ARP_req'high loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = ARP_req(ct) report "ARP request payload incorrect";
      if ct = ARP_resp'high then
        assert mac_tx_tlast = '1' report "tlast failed to assert end of ARP request";
      else
        assert mac_tx_tlast = '0' report "tlast asserted early in ARP request";
      end if;
    end loop;

    --Next is UDP tx appearing at mac_tx
    --count off header (should be checking) 14 bytes ethernet frame header; 20 bytes IpV4 header; 8 byte UDP header
    for ct in 1 to 42 loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
    end loop;
    --Now check ennumerate response
    for ct in 0 to ENUMERATE_RESPONSE'high loop
      wait until rising_edge(clk) and mac_tx_tvalid = '1';
      assert mac_tx_tdata = ENUMERATE_RESPONSE(ct) report "udp_tx data incorrect";
    end loop;


    --Next is TCP stream at tcp_rx
    for ct in 0 to 1023 loop
      wait until rising_edge(clk) and tcp_rx_tvalid = '1' and tcp_rx_tready = '1';
      assert tcp_rx_tdata = tcp_test_payload(ct) report "tcp data incorrect";
    end loop;

    --Next is DHCP request
    --TODO: checking
    checking_finished <= true;

    wait;

  end process;

end;
