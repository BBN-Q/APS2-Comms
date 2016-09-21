-- Testbench for the UDP responder modules
-- Tests:
--	* enumerate response
--	* packet filtering on UDP source port and valid packet
--	* TCP reset
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity udp_responder_tb is
end;

architecture bench of udp_responder_tb is


	signal clk : std_logic := '0';
	signal rst : std_logic := '0';
	signal udp_rx_tdata : std_logic_vector(7 downto 0) := (others => '0');
	signal udp_rx_tvalid : std_logic := '0';
	signal udp_rx_tlast : std_logic	:= '0';
	signal udp_src_port : std_logic_vector(15 downto 0) := (others => '0');
	signal src_ip_addr : std_logic_vector(31 downto 0) := (others => '0');
	signal dest_ip_addr : std_logic_vector(31 downto 0) := (others => '0');
	signal udp_tx_tdata : std_logic_vector(7 downto 0) := (others => '0');
	signal udp_tx_tvalid : std_logic := '0';
	signal udp_tx_tlast : std_logic	:= '0';
	signal udp_tx_tready : std_logic := '1';
	signal udp_tx_ack : std_logic := '0';
	signal udp_tx_nack : std_logic := '0';
	signal rst_tcp : std_logic := '0';

	constant clock_period: time := 8 ns;
	signal stop_the_clock: boolean := false;

	type TestBenchState_t is (RESET, ENUMERATE, ENUMERATE_AGAIN, WRONG_UDP_PORT,
	                          BAD_PACKET, BIG_BAD_PACKET, RESET_TCP, FINISHED);
	signal testBench_state : TestBenchState_t;

	signal checking_finished : boolean := false;

begin

	uut: entity work.UDP_responder
		port map (
			clk					 => clk,
			rst					 => rst,
			udp_rx_tdata	=> udp_rx_tdata,
			udp_rx_tvalid => udp_rx_tvalid,
			udp_rx_tlast	=> udp_rx_tlast,
			udp_src_port	=> udp_src_port,
			src_ip_addr	 => src_ip_addr,
			dest_ip_addr	=> dest_ip_addr,
			udp_tx_tdata	=> udp_tx_tdata,
			udp_tx_tvalid => udp_tx_tvalid,
			udp_tx_tlast	=> udp_tx_tlast,
			udp_tx_tready => udp_tx_tready,
			udp_tx_ack		=> udp_tx_ack,
			udp_tx_nack	 => udp_tx_nack,
			rst_tcp			 => rst_tcp
		);


	clk <= not clk after clock_period / 2 when not stop_the_clock;

	ack_pro : process
	begin
		--Should keep a table of seen IP addresses but send nack on first request then ack
		wait until rising_edge(clk) and udp_tx_tlast = '1';
		wait for 3us;
		wait until rising_edge(clk);
		udp_tx_nack <= '1';
		wait until rising_edge(clk);
		udp_tx_nack <= '0';
		while true loop
			wait until rising_edge(clk) and udp_tx_tlast = '1';
			wait for 1us;
			wait until rising_edge(clk);
			udp_tx_ack <= '1';
			wait until rising_edge(clk);
			udp_tx_ack <= '0';
		end loop;
	end process;

	stimulus: process
	begin

		wait until rising_edge(clk);

		testBench_state <= RESET;
		rst <= '1';
		wait for 100ns;
		rst <= '0';
		wait for 100ns;

-------------------------------------------
		--Clock in a enumerate request
		wait until rising_edge(clk);
		testBench_state <= ENUMERATE;
		udp_rx_tdata <= x"01";
		udp_rx_tvalid <= '1';
		udp_rx_tlast <= '1';
		udp_src_port <= x"bb4f";
		src_ip_addr <= x"c0a80201"; -- 192.168.2.1
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		--wait for UDP enumerate to actually come out
		wait until udp_tx_ack = '1' for 15 us;

		--Clock in a second enumerate request
		wait until rising_edge(clk);
		testBench_state <= ENUMERATE_AGAIN;
		udp_rx_tdata <= x"01";
		udp_rx_tvalid <= '1';
		udp_rx_tlast <= '1';
		udp_src_port <= x"bb4f";
		src_ip_addr <= x"c0a80201"; -- 192.168.2.1
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		--wait for UDP enumerate to actually come out
		wait until udp_tx_ack = '1' for 5 us;

		-------------------------------------------
		testBench_state <= WRONG_UDP_PORT;
		udp_rx_tdata <= x"01";
		udp_rx_tvalid <= '1';
		udp_rx_tlast <= '1';
		udp_src_port <= x"bb4e";
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		-------------------------------------------
		testBench_state <= BAD_PACKET;
		udp_rx_tdata <= x"01";
		udp_rx_tlast <= '1';
		udp_src_port <= x"bb4f";
		src_ip_addr <= x"c0a80205"; -- 192.168.2.5
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		-------------------------------------------
		testBench_state <= BIG_BAD_PACKET;
		for ct in 1 to 47 loop
			udp_rx_tdata <= std_logic_vector(to_unsigned(ct,8));
			udp_rx_tvalid <= '1';
			wait until rising_edge(clk);
		end loop;
		udp_rx_tdata <= std_logic_vector(to_unsigned(48,8));
		udp_rx_tlast <= '1';
		udp_rx_tvalid <= '0';
		udp_src_port <= x"bb4e";
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		-------------------------------------------
		testBench_state <= RESET_TCP;
		udp_rx_tdata <= x"02";
		udp_rx_tvalid <= '1';
		udp_rx_tlast <= '1';
		udp_src_port <= x"bb4f";
		src_ip_addr <= x"c0a80201"; -- 192.168.2.1
		wait until rising_edge(clk);

		udp_rx_tvalid <= '0';
		udp_rx_tlast <= '0';
		for ct in 1 to 12 loop
			wait until rising_edge(clk);
		end loop;

		wait for 100ns;
		testBench_state <= FINISHED;
		assert checking_finished report "Checking failed to finish.";

		stop_the_clock <= true;

	end process;

	checking : process

		type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);
		-- "I am an APS2"
		constant ENUMERATE_RESPONSE : byte_array(0 to 11) :=
		(x"49", x"20", x"61", x"6d", x"20", x"61", x"6e", x"20", x"41", x"50", x"53", x"32");

	begin

		--First thing that should come back is an enumerate response to 192.168.2.1
		wait until testBench_state = ENUMERATE;
		wait until rising_edge(clk) and udp_tx_tvalid = '1';
		assert dest_ip_addr = x"c0a80201" report "Incorrect destination IP address";
		assert udp_tx_tdata = ENUMERATE_RESPONSE(0) report "Incorrect enumerate response";
		for ct in 1 to ENUMERATE_RESPONSE'length -1 loop
			wait until rising_edge(clk) and udp_tx_tvalid = '1';
			assert udp_tx_tdata = ENUMERATE_RESPONSE(ct) report "Incorrect enumerate response";
			if ct = ENUMERATE_RESPONSE'high then
				assert udp_tx_tlast = '1' report "tlast failed to assert correctly";
			else
				assert udp_tx_tlast = '0' report "tlast failed to assert correctly";
			end if;
		end loop;

		--then we try again after nack
		wait until rising_edge(clk) and udp_tx_tvalid = '1';
		assert dest_ip_addr = x"c0a80201" report "Incorrect destination IP address";
		assert udp_tx_tdata = ENUMERATE_RESPONSE(0) report "Incorrect enumerate response";
		for ct in 1 to ENUMERATE_RESPONSE'length -1 loop
			wait until rising_edge(clk) and udp_tx_tvalid = '1';
			assert udp_tx_tdata = ENUMERATE_RESPONSE(ct) report "Incorrect enumerate response";
			if ct = ENUMERATE_RESPONSE'high then
				assert udp_tx_tlast = '1' report "tlast failed to assert correctly";
			else
				assert udp_tx_tlast = '0' report "tlast failed to assert correctly";
			end if;
		end loop;


		--then thing that should come back is an enumerate response to 192.168.2.1
		wait until testBench_state = ENUMERATE_AGAIN;
		wait until rising_edge(clk) and udp_tx_tvalid = '1';
		assert dest_ip_addr = x"c0a80201" report "Incorrect destination IP address";
		assert udp_tx_tdata = ENUMERATE_RESPONSE(0) report "Incorrect enumerate response";
		for ct in 1 to ENUMERATE_RESPONSE'length -1 loop
			wait until rising_edge(clk) and udp_tx_tvalid = '1';
			assert udp_tx_tdata = ENUMERATE_RESPONSE(ct) report "Incorrect enumerate response";
			if ct = ENUMERATE_RESPONSE'high then
				assert udp_tx_tlast = '1' report "tlast failed to assert correctly";
			else
				assert udp_tx_tlast = '0' report "tlast failed to assert correctly";
			end if;
		end loop;


		--Should get nothing back during bad packets
		wait until testBench_state = WRONG_UDP_PORT;
		while testBench_state /= RESET_TCP loop
			wait until rising_edge(clk);
			assert udp_tx_tvalid = '0' report "Got UDP packet response when should not have";
		end loop;

		--Then should get two clock reset pulse on rst_tcp
		wait until rising_edge(clk) and rst_tcp = '1';
		wait until rising_edge(clk);
		assert rst_tcp = '1' report "rst_tcp failed to assert";
		
		checking_finished <= true;

	end process;

end;
