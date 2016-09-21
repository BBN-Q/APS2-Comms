-- Test bench for the TCP-AXI Bridge
-- Tests:
--  * no-ack write
--  * ack write
--  * read
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcp_bridge_tb is
end;

architecture bench of tcp_bridge_tb is

  signal axi_resetn : std_logic := '0';
  signal clk : std_logic := '0';
  signal clk_tcp : std_logic := '0';
  signal rst : std_logic := '0';
  signal rst_tcp : std_logic := '0';
	signal cpld_rx_tdata : std_logic_vector (31 downto 0) := (others => '0');
  signal cpld_rx_tready : std_logic := '0';
  signal cpld_rx_tvalid : std_logic := '0';
	signal cpld_rx_tlast : std_logic := '0';
  signal cpld_tx_tdata : std_logic_vector (31 downto 0) := (others => '0');
  signal cpld_tx_tready : std_logic := '1';
  signal cpld_tx_tvalid : std_logic := '0';
	signal cpld_tx_tlast : std_logic := '0';
  signal tcp_rx_tdata : std_logic_vector (7 downto 0) := (others => '0');
  signal tcp_rx_tready : std_logic := '0';
  signal tcp_rx_tvalid : std_logic := '0';
  signal tcp_tx_tdata : std_logic_vector (7 downto 0) := (others => '0');
  signal tcp_tx_tready : std_logic := '1';
  signal tcp_tx_tvalid : std_logic := '0';
  signal mm2s_err : std_logic := '0';
  signal s2mm_err : std_logic := '0';

	constant clock_period : time := 10 ns;
  constant clock_tcp_period : time := 8 ns;
  signal stop_the_clocks : boolean := false;
  signal checking_finished : boolean := false;

	type TestBenchState_t is (RESET, WRITE_SHORT_NOACK, WRITE_SHORT_ACK, READ_SHORT, FINISHED);
  signal testBench_state : TestBenchState_t;

begin

  uut: entity work.tcp_bridge_tb_bd
		port map (
		clk            => clk,
    clk_tcp        => clk_tcp,
		rst            => rst,
    rst_tcp        => rst_tcp,
		axi_resetn     => axi_resetn,

		cpld_rx_tdata  => cpld_rx_tdata,
		cpld_rx_tready => cpld_rx_tready,
		cpld_rx_tvalid => cpld_rx_tvalid,
		cpld_rx_tlast  => cpld_rx_tlast,
		cpld_tx_tdata  => cpld_tx_tdata,
		cpld_tx_tready => cpld_tx_tready,
		cpld_tx_tvalid => cpld_tx_tvalid,
		cpld_tx_tlast  => cpld_tx_tlast,

		tcp_rx_tdata   => tcp_rx_tdata,
		tcp_rx_tready  => tcp_rx_tready,
		tcp_rx_tvalid  => tcp_rx_tvalid,
		tcp_tx_tdata   => tcp_tx_tdata,
		tcp_tx_tready => tcp_tx_tready,
		tcp_tx_tvalid => tcp_tx_tvalid,

    mm2s_err => mm2s_err,
    s2mm_err => s2mm_err
	);

  clk <= not clk after clock_period / 2 when not stop_the_clocks;
  clk_tcp <= not clk_tcp after clock_tcp_period / 2 when not stop_the_clocks;

  stimulus: process
    procedure write_word(word : std_logic_vector(31 downto 0)) is
    begin
      tcp_rx_tvalid <= '1';
      for ct in 0 to 3 loop
        tcp_rx_tdata <= word(31-ct*8 downto 24-ct*8);
        wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
      end loop;
      tcp_rx_tvalid <= '0';
    end procedure write_word;
  begin

    wait until rising_edge(clk_tcp);

		testBench_state <= RESET;
		axi_resetn <= '0';
		rst <= '1';
    rst_tcp <= '1';
		wait for 100ns;
    wait until rising_edge(clk_tcp);
    rst_tcp <= '0';
    wait until rising_edge(clk);
		axi_resetn <= '1';
		rst <= '0';
		wait for 100ns;

		--Clock in a write request with no-ack
		wait until rising_edge(clk_tcp);
    testBench_state <= WRITE_SHORT_NOACK;
    --control word
    write_word(x"00000004");
		--address
    write_word(x"C0000000");
		--data
    tcp_rx_tvalid <= '1';
		for ct in 1 to 16 loop
			tcp_rx_tdata <= std_logic_vector(to_unsigned(ct, 8));
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;

    --ifg
		tcp_rx_tvalid <= '0';
		for ct in 1 to 4 loop
			wait until rising_edge(clk_tcp);
		end loop;

		--Clock in a write request with ack req.
		wait until rising_edge(clk_tcp);
		testBench_state <= WRITE_SHORT_ACK;
		--control word
    write_word(x"80000004");
		--address
    write_word(x"C0000010");
		--data
    tcp_rx_tvalid <= '1';
		for ct in 1 to 16 loop
			tcp_rx_tdata <= std_logic_vector(to_unsigned(16+ct, 8));
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;

    --ifg
		tcp_rx_tvalid <= '0';
		for ct in 1 to 4 loop
			wait until rising_edge(clk_tcp);
		end loop;

		--Clock in a read request
		wait until rising_edge(clk_tcp);
		testBench_state <= READ_SHORT;
		--control word
    write_word(x"10000008");
		--address
		write_word(x"C0000000");

    tcp_rx_tvalid <= '0';
    wait for 1 us;
    assert checking_finished report "Checking incomplete!";
		testBench_state <= FINISHED;
		stop_the_clocks <= true;

  end process;

	checking : process
    procedure check_word(word : std_logic_vector(31 downto 0); error_str : string) is
    begin
      for ct in 0 to 3 loop
    		wait until rising_edge(clk_tcp) and tcp_tx_tvalid = '1';
		    assert tcp_tx_tdata = word(31-8*ct downto 24-8*ct) report error_str;
      end loop;
    end procedure check_word;
	begin
		--READ_SHORT comes out first because it's response starts before WRITE_SHORT_ACK
		--command and address
    check_word(x"10000008", "Incorrect READ_SHORT command response received.");
		check_word(x"c0000000", "Incorrect READ_SHORT address response received.");
		--data
		for ct in 1 to 32 loop
			wait until rising_edge(clk_tcp) and tcp_tx_tvalid = '1';
			assert tcp_tx_tdata = std_logic_vector(to_unsigned(ct, 8)) report "Incorrect READ_SHORT data response received.";
		end loop;

    --Next thing that should come out is the WRITE_SHORT_ACK
    check_word(x"80800004", "Incorrect WRITE_SHORT_ACK command response received.");
    check_word(x"c0000010", "Incorrect WRITE_SHORT_ACK address response received.");

    checking_finished <= true;

	end process;


end;
