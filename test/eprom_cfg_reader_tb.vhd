-- Testbench for the eprom_cfg_reader
-- Tests:
--  * default values until done
--  * request sent
--  * response processed and addresses set
--  * done asserted
--  * AXIS pass through after done asserted
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eprom_cfg_reader_tb is
end;

architecture bench of eprom_cfg_reader_tb is

  signal clk : std_logic := '0';
  signal rst : std_logic := '0';
  signal rx_in_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_in_tvalid : std_logic := '0';
  signal rx_in_tready : std_logic := '0';
  signal rx_in_tlast : std_logic := '0';
  signal rx_out_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal rx_out_tvalid : std_logic := '0';
  signal rx_out_tlast : std_logic := '0';
  signal rx_out_tready : std_logic := '0';
  signal tx_in_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_in_tvalid : std_logic := '0';
  signal tx_in_tready : std_logic := '0';
  signal tx_in_tlast : std_logic := '0';
  signal tx_out_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal tx_out_tvalid : std_logic := '0';
  signal tx_out_tlast : std_logic := '0';
  signal tx_out_tready : std_logic := '0';
  signal mac_addr : std_logic_vector(47 downto 0) := (others => '0');
  signal ip_addr : std_logic_vector(31 downto 0) := (others => '0');
  signal dhcp_enable : std_logic := '0';
  signal done : std_logic := '0';

  constant clock_period: time := 10 ns;
  signal stop_the_clock: boolean := false;

  type TestBenchState_t is (RESET, WAIT_FOR_READ_REQ, FLASH_READ_DELAY, SEND_READ_RESPONSE, WAIT_FOR_DONE, RX_PASS_THROUGH, TX_PASS_THROUGH, FINISHED);
  signal testBench_state : TestBenchState_t;

  type array_slv32 is array(natural range <>) of std_logic_vector(31 downto 0);
  constant FLASH_DATA : array_slv32 := (x"92000004", x"4651db00", x"002e0000", x"c0a80202", x"00000001");

begin

  uut: entity work.eprom_cfg_reader
   port map (
    clk           => clk,
    rst           => rst,
    rx_in_tdata   => rx_in_tdata,
    rx_in_tvalid  => rx_in_tvalid,
    rx_in_tready  => rx_in_tready,
    rx_in_tlast   => rx_in_tlast,
    rx_out_tdata  => rx_out_tdata,
    rx_out_tvalid => rx_out_tvalid,
    rx_out_tlast  => rx_out_tlast,
    rx_out_tready => rx_out_tready,
    tx_in_tdata   => tx_in_tdata,
    tx_in_tvalid  => tx_in_tvalid,
    tx_in_tready  => tx_in_tready,
    tx_in_tlast   => tx_in_tlast,
    tx_out_tdata  => tx_out_tdata,
    tx_out_tvalid => tx_out_tvalid,
    tx_out_tlast  => tx_out_tlast,
    tx_out_tready => tx_out_tready,
    ip_addr       => ip_addr,
    mac_addr      => mac_addr,
    dhcp_enable   => dhcp_enable,
    done          => done
  );

  clk <= not clk after clock_period / 2 when not stop_the_clock;

  stimulus: process
  begin

    wait until rising_edge(clk);

    --Reset
    testBench_state <= RESET;
		rst <= '1';
		wait for 100ns;
		rst <= '0';
		wait for 100ns;

    --Wait for read request to come out
    testBench_state <= WAIT_FOR_READ_REQ;
    rx_out_tready <= '1';
    wait until rising_edge(clk) and rx_out_tlast = '1' for 100 ns;

    --flash read delay (probably much longer)
    testBench_state <= FLASH_READ_DELAY;
    wait for 1 us;

    --send back data
    testBench_state <= SEND_READ_RESPONSE;
    for ct in 0 to FLASH_DATA'high loop
      wait until rising_edge(clk) and tx_in_tready = '1';
      tx_in_tdata <= FLASH_DATA(ct);
      tx_in_tvalid <= '1';
      if ct = FLASH_DATA'high then
        tx_in_tlast <= '1';
      else
        tx_in_tlast <= '0';
      end if;
      for ct2 in 0 to 2 loop
        wait until rising_edge(clk);
        tx_in_tdata <= (others => '0');
        tx_in_tvalid <= '0';
        tx_in_tlast <= '0';
      end loop;
    end loop;

    --wait for done
    wait until done = '1' for 100 ns;
    assert done = '1' report "Done failed to assert";

    --Test pass through an rx side
    testBench_state <= RX_PASS_THROUGH;
    rx_out_tready <= '0';
    wait until rising_edge(clk);
    assert rx_in_tready = '0' report "rx tready pass through failed";
    rx_in_tvalid <= '1';
    wait until rising_edge(clk);
    assert rx_out_tvalid = '1' report "rx tvalid pass through failed";
    rx_in_tlast <= '1';
    wait until rising_edge(clk);
    assert rx_out_tlast = '1' report "rx tlast pass through failed";
    rx_in_tdata <= x"12345678";
    wait until rising_edge(clk);
    assert rx_out_tdata = x"12345678" report "rx tdata pass through failed";

    --Test pass through an rx side
    testBench_state <= TX_PASS_THROUGH;
    tx_out_tready <= '1';
    wait until rising_edge(clk);
    assert tx_in_tready = '1' report "tx tready pass through failed";
    tx_in_tvalid <= '1';
    wait until rising_edge(clk);
    assert tx_out_tvalid = '1' report "tx tvalid pass through failed";
    tx_in_tlast <= '1';
    wait until rising_edge(clk);
    assert tx_out_tlast = '1' report "tx tlast pass through failed";
    tx_in_tdata <= x"12345678";
    wait until rising_edge(clk);
    assert tx_out_tdata = x"12345678" report "tx tdata pass through failed";

    stop_the_clock <= true;

  end process;

  checking: process
  begin

    --Check defaults are set
    wait until falling_edge(rst);
    wait for 10 ns;
    assert mac_addr = x"4651dbbada55" report "Incorrect default MAC address";
    assert ip_addr = x"c0a8027b" report "Incorrect default IP address";
    assert dhcp_enable = '0' report "incorrect default DHCP bit";

    --check read request is sent
    wait until rising_edge(clk) and rx_out_tvalid = '1' and rx_out_tready = '1';
    assert rx_out_tdata = x"12000004" report "Read command incorrect";
    assert rx_out_tlast = '0' report "Read tlast incorrect";
    wait until rising_edge(clk) and rx_out_tvalid = '1';
    assert rx_out_tdata = x"00FF0000" report "Read address incorrect";
    assert rx_out_tlast = '1' report "Read tlast incorrect";

    wait until done = '1' for 2 us;

    --check updated addresses
    assert mac_addr = x"4651db00002e" report "Incorrect MAC address";
    assert ip_addr = x"c0a80202" report "Incorrect IP address";
    assert dhcp_enable = '1' report "incorrect DHCP bit";


  end process;

end;
