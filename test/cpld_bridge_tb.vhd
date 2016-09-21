library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpld_bridge_tb is
end;

architecture bench of cpld_bridge_tb is

  signal cfg_act : std_logic := '0';
  signal cfg_clk : std_logic := '0';
  signal cfg_err : std_logic := '0';
  signal cfg_rdy : std_logic := '0';
  signal cfgd : std_logic_vector ( 15 downto 0 ) := (others => '0');
  signal clk : std_logic := '0';
  signal rx_tdata : std_logic_vector ( 31 downto 0 ) := (others => '0');
  signal rx_tlast : std_logic := '0';
  signal rx_tready : std_logic := '0';
  signal rx_tvalid : std_logic := '0';
  signal tx_tdata : std_logic_vector ( 31 downto 0 ) := (others => '0');
  signal tx_tlast : std_logic := '0';
  signal tx_tready : std_logic := '1';
  signal tx_tvalid : std_logic := '0';
  signal fpga_cmdl : std_logic := '0';
  signal fpga_rdyl : std_logic := '0';
  signal rst : std_logic := '0';
  signal stat_oel : std_logic := '0';

  constant clock_period : time := 10 ns;
  constant cfg_clock_period : time := 10 ns;
  signal stop_the_clocks : boolean := false;

  type TestBenchState_t is (RESET, STATUS_REQUEST, STATUS_REQUEST2, FINISHED);
  signal testBench_state : TestBenchState_t;

  type APSCommand_t is record
  	ack : std_logic;
  	seq : std_logic;
  	sel : std_logic;
  	rw : std_logic;
  	cmd : std_logic_vector(3 downto 0);
  	mode : std_logic_vector(7 downto 0);
  	cnt : std_logic_vector(15 downto 0);
  end record;

begin

  uut : entity work.cpld_bridge
		port map (
			clk       => clk,
			rst       => rst,
			rx_tdata  => rx_tdata,
			rx_tlast  => rx_tlast,
			rx_tready => rx_tready,
			rx_tvalid => rx_tvalid,
			tx_tdata  => tx_tdata,
			tx_tlast  => tx_tlast,
			tx_tready => tx_tready,
			tx_tvalid => tx_tvalid,
			cfg_clk   => cfg_clk,
			cfg_act   => cfg_act,
			cfg_err   => cfg_err,
			cfg_rdy   => cfg_rdy,
			cfgd      => cfgd,
			fpga_cmdl => fpga_cmdl,
			fpga_rdyl => fpga_rdyl,
			stat_oel  => stat_oel
	);

  clk <= not clk after clock_period / 2 when not stop_the_clocks;
  cfg_clk <= not cfg_clk after cfg_clock_period / 2 when not stop_the_clocks;

  stimulus : process
    variable command_word : APSCommand_t := (ack => '0', seq => '0', sel => '0', rw => '0', cmd => (others => '0'), mode => (others => '0'), cnt => x"0000");
  begin

    wait until rising_edge(clk);

    testBench_state <= RESET;
		rst <= '1';
		wait for 100ns;
		rst <= '0';
		wait for 100ns;

    --Clock in a status request
    wait until rising_edge(clk);
    testBench_state <= STATUS_REQUEST;
    command_word.rw := '1';
  	command_word.cmd := x"7";
    command_word.sel := '1';
    rx_tdata <= command_word.ack & command_word.seq & command_word.sel & command_word.rw & command_word.cmd & x"000010";
    rx_tvalid <= '1';
    rx_tlast <= '1';
    wait until rising_edge(clk) and rx_tready = '1';

    rx_tvalid <= '0';
    rx_tlast <= '0';

    wait until tx_tlast = '1';

    --Clock in a 2nd status request
    wait until rising_edge(clk);
    testBench_state <= STATUS_REQUEST2;
    rx_tdata <= command_word.ack & command_word.seq & command_word.sel & command_word.rw & command_word.cmd & x"000010";
    rx_tvalid <= '1';
    rx_tlast <= '1';
    wait until rising_edge(clk) and rx_tready = '1';

    rx_tvalid <= '0';
    rx_tlast <= '0';

    wait until tx_tlast = '1';
    wait for 10ns;

    stop_the_clocks <= true;
  end process;

  checking : process

  begin
    --First thing back in the status registers
    --command word
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"97000010" report "Incorrect STATUS_REQUEST command word response";
    --host firmware version
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"00000a01" report "Incorrect STATUS_REQUEST host firmware version";
    --user firmware version
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"badda555" report "Incorrect STATUS_REQUEST user firmware version";
    --config source
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"bbbbbbbb" report "Incorrect STATUS_REQUEST config source";
    --user status
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"0ddba111" report "Incorrect STATUS_REQUEST user status";
    --dac0 status, dac1 status, pll status, temperature
    for ct in 1 to 4 loop
      wait until rising_edge(clk) and tx_tvalid = '1';
      assert tx_tdata = x"00000000" report "Incorrect STATUS_REQUEST dac0/dac1/pll status";
    end loop;
    --send pkt count
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"00000000" report "Incorrect STATUS_REQUEST send packet count";
    --receive pkt count
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"00000001" report "Incorrect STATUS_REQUEST receive packet count";
    --skip pkt count, dup pkt count, fcs error pkt count, overrun count
    for ct in 1 to 4 loop
      wait until rising_edge(clk) and tx_tvalid = '1';
      assert tx_tdata = x"00000000" report "Incorrect STATUS_REQUEST skip/dup/fcs errors/overrun pkt count";
    end loop;
    --uptime
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"00000000" report "Incorrect STATUS_REQUEST uptime seconds";
    wait until rising_edge(clk) and tx_tvalid = '1';
    assert tx_tdata = x"000002b8" report "Incorrect STATUS_REQUEST updtime nanoseconds";
    assert tx_tlast = '1' report "tlast did not go high when expected";

  end process;

end;
