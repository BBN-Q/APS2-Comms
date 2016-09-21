-- Testbench for tcp_demux
--
-- * memory write/read
-- * to cpld with tready deasserting
--
-- Original author: Colm Ryan
-- Copyright 2015,2016 Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tcp_demux_tb is
end;

architecture bench of tcp_demux_tb is

  signal clk : std_logic := '0';
  signal clk_tcp : std_logic := '0';
  signal rst : std_logic := '0';
  signal rst_tcp : std_logic := '0';
  signal tcp_rx_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal tcp_rx_tvalid : std_logic := '0';
  signal tcp_rx_tready : std_logic := '0';
  signal memory_rx_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal memory_rx_tvalid : std_logic := '0';
  signal memory_rx_tready : std_logic := '1';
  signal memory_rx_tlast : std_logic := '0';
  signal cpld_rx_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal cpld_rx_tvalid : std_logic := '0';
  signal cpld_rx_tready : std_logic := '0';
  signal cpld_rx_tlast : std_logic := '0';

  constant clock_period : time := 10 ns;
  constant clock_tcp_period : time := 8 ns;
  signal stop_the_clocks : boolean;

	type TestBenchState_t is (RESET, TO_MEMORY_WRITE, TO_MEMORY_READ, TO_CPLD_SHORT, TO_CPLD_LONG);
	signal testBench_state : TestBenchState_t;

  signal checking_finished : boolean := false;

begin

  uut : entity work.tcp_demux
		port map (
			clk              => clk,
      rst              => rst,
      clk_tcp          => clk_tcp,
      rst_tcp          => rst_tcp,
      tcp_rx_tdata     => tcp_rx_tdata,
      tcp_rx_tvalid    => tcp_rx_tvalid,
      tcp_rx_tready    => tcp_rx_tready,
      memory_rx_tdata  => memory_rx_tdata,
      memory_rx_tvalid => memory_rx_tvalid,
      memory_rx_tready => memory_rx_tready,
      memory_rx_tlast  => memory_rx_tlast,
      cpld_rx_tdata    => cpld_rx_tdata,
      cpld_rx_tvalid   => cpld_rx_tvalid,
      cpld_rx_tready   => cpld_rx_tready,
      cpld_rx_tlast    => cpld_rx_tlast
		);

  clk <= not clk after clock_period / 2 when not stop_the_clocks;
  clk_tcp <= not clk_tcp after clock_tcp_period / 2 when not stop_the_clocks;

  --CPLD goes into axis adapter so can take data only every 1/4 clock cycles
  cpld_rx_tready_drive: process
  begin
    while true loop
      cpld_rx_tready <= '1';
      wait until rising_edge(clk) and cpld_rx_tvalid = '1';
      cpld_rx_tready <= '0';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
  end loop;
  end process;

  stimulus: process
		type byte_array is array(natural range <>) of std_logic_vector(7 downto 0);
		variable cmd : byte_array(0 to 3);
		variable addr : byte_array(0 to 3);
    variable cnt : natural;
  begin

		wait until rising_edge(clk_tcp);
		testBench_state <= RESET;
		rst <= '1';
		wait for 100ns;
    wait until rising_edge(clk_tcp);
    rst_tcp <= '0';
    wait until rising_edge(clk);
		rst <= '0';
		wait for 100ns;
		wait until rising_edge(clk_tcp);

		testBench_state <= TO_MEMORY_WRITE;
		tcp_rx_tvalid <= '1';
		--command word
		cmd := (x"00", x"00", x"00", x"04");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= cmd(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--address
		addr := (x"c0", x"00", x"00", x"00");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= addr(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--data payload
		for ct in 1 to 16 loop
			tcp_rx_tdata <= std_logic_vector(to_unsigned(ct, 8));
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		tcp_rx_tvalid <= '0';

		wait until rising_edge(clk) and memory_rx_tlast = '1';

    testBench_state <= TO_MEMORY_READ;
		tcp_rx_tvalid <= '1';
		--command word
		cmd := (x"10", x"00", x"00", x"ff");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= cmd(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--address
		addr := (x"c0", x"00", x"00", x"00");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= addr(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;

		tcp_rx_tvalid <= '0';

		wait until rising_edge(clk) and memory_rx_tlast = '1';

		testBench_state <= TO_CPLD_SHORT;
		tcp_rx_tvalid <= '1';
		--command word
		cmd := (x"20", x"00", x"00", x"00");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= cmd(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--address
		addr := (x"ba", x"ad", x"a5", x"55");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= addr(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		tcp_rx_tvalid <= '0';

		wait until rising_edge(clk_tcp) and cpld_rx_tlast = '1';

		testBench_state <= TO_CPLD_LONG;
    tcp_rx_tvalid <= '1';
		--command word
		cmd := (x"25", x"00", x"01", x"00");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= cmd(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--address
		addr := (x"ba", x"ad", x"a5", x"55");
		for ct in 0 to 3 loop
			tcp_rx_tdata <= addr(ct);
			wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
		end loop;
		--data payload
    cnt := 0;
    while cnt < 1024 loop
      tcp_rx_tdata <= std_logic_vector(to_unsigned(cnt, 8));
      tcp_rx_tvalid <= '1';
      wait until rising_edge(clk_tcp) and tcp_rx_tready = '1';
      cnt := cnt + 1;
    end loop;

		tcp_rx_tvalid <= '0';

		wait until rising_edge(clk) and cpld_rx_tlast = '1' for 3us;

    wait for 100 ns;
    assert checking_finished report "Checking process failed to finish";
    stop_the_clocks <= true;

  end process;

------------------------------------------------------------------------------------------------

	checking : process
		type array_slv32_t is array(natural range <>) of std_logic_vector(31 downto 0);
		variable tmp : array_slv32_t(0 to 5);
    variable tmp_slv32 : std_logic_vector(31 downto 0);
	begin
		--First thing is packet to memory
		tmp(0 to 1) := (x"00000004", x"c0000000");
		for ct in 0 to 3 loop
			for ct2 in 0 to 3 loop
				tmp(2+ct)(31 - 8*ct2 downto 24 - 8*ct2) := std_logic_vector(to_unsigned(ct*4+ct2+1, 8));
			end loop;
		end loop;
		for ct in 0 to tmp'high loop
			wait until rising_edge(clk) and memory_rx_tvalid = '1';
			assert cpld_rx_tvalid = '0' report "cpld valid line asserted when it should not have";
			assert memory_rx_tdata = tmp(ct) report "Packet to memory failed to arrive as expected.";
			if ct = tmp'high then
				assert memory_rx_tlast = '1' report "Packet to memory tlast failed to assert correctly";
			else
				assert memory_rx_tlast = '0' report "Packet to memory tlast failed to assert correctly";
			end if;
		end loop;

    --Then read request to memory
		tmp(0 to 1) := (x"100000ff", x"c0000000");
    for ct in 0 to 1 loop
			wait until rising_edge(clk) and memory_rx_tvalid = '1';
			assert cpld_rx_tvalid = '0' report "cpld valid line asserted when it should not have";
			assert memory_rx_tdata = tmp(ct) report "Packet to memory failed to arrive as expected.";
			if ct = 1 then
				assert memory_rx_tlast = '1' report "Packet to memory tlast failed to assert correctly";
			else
				assert memory_rx_tlast = '0' report "Packet to memory tlast failed to assert correctly";
			end if;
		end loop;

		--Then short command only to CPLD
		tmp(0 to 1) := (x"20000000", x"baada555");
		for ct in 0 to 1 loop
			wait until rising_edge(clk) and cpld_rx_tvalid = '1' and cpld_rx_tready = '1';
			assert memory_rx_tvalid = '0' report "memory valid line asserted when it should not have";
			assert cpld_rx_tdata = tmp(ct) report "Packet cmd and addr to cpld failed to arrive as expected.";
			if ct = 1 then
				assert cpld_rx_tlast = '1' report "Packet to cpld tlast failed to assert correctly";
		  else
				assert cpld_rx_tlast = '0' report "Packet to cpld tlast failed to assert correctly";
			end if;
		end loop;

		--Then longer packet to CPLD
		tmp(0 to 1) := (x"25000100", x"baada555");
		for ct in 0 to 1 loop
			wait until rising_edge(clk) and cpld_rx_tvalid = '1' and cpld_rx_tready = '1';
			assert memory_rx_tvalid = '0' report "memory valid line asserted when it should not have";
			assert cpld_rx_tdata = tmp(ct) report "Packet cmd and addr to cpld failed to arrive as expected.";
		end loop;
    for ct in 0 to 255 loop
      wait until rising_edge(clk) and cpld_rx_tvalid = '1' and cpld_rx_tready = '1';
      for ct2 in 0 to 3 loop
        tmp_slv32(31 - 8*ct2 downto 24 - 8*ct2) := std_logic_vector(to_unsigned(ct*4+ct2, 8));
      end loop;
      assert cpld_rx_tdata = tmp_slv32 report "Packet to cpld failed to arrive as expected: " & integer'image(to_integer(unsigned(tmp_slv32)));
      if ct = 255 then
				assert cpld_rx_tlast = '1' report "Packet to cpld tlast failed to assert correctly";
		  else
				assert cpld_rx_tlast = '0' report "Packet to cpld tlast failed to assert correctly";
			end if;
    end loop;

    checking_finished <= true;

    wait;

	end process;

end;
