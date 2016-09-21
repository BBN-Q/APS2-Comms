library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package tcp_bridge_pkg is

	function byte_swap(word_in : std_logic_vector) return std_logic_vector;

	component axis_srl_fifo
		generic (
			DATA_WIDTH : natural := 8;
			DEPTH : natural := 16
		);
		port (
			clk : in std_logic;
			rst : in std_logic;

			input_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_axis_tvalid : in std_logic;
			input_axis_tready : out std_logic;
			input_axis_tlast  : in std_logic;
			input_axis_tuser  : in std_logic;

			output_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_axis_tvalid : out std_logic;
			output_axis_tready : in std_logic;
			output_axis_tlast  : out std_logic;
			output_axis_tuser  : out std_logic;

			count : out std_logic_vector(integer(ceil(log2(real(DEPTH+1))))-1 downto 0)
		);
	end component;

	component axis_demux_2
		generic (
			DATA_WIDTH : natural := 8
		);
		port (
			clk : in std_logic;
			rst : in std_logic;

			input_axis_tdata     : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_axis_tvalid    : in std_logic;
			input_axis_tready    : out std_logic;
			input_axis_tlast     : in std_logic;
			input_axis_tuser     : in std_logic;

			output_0_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_0_axis_tvalid : out std_logic;
			output_0_axis_tready : in std_logic;
			output_0_axis_tlast  : out std_logic;
			output_0_axis_tuser  : out std_logic;

			output_1_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_1_axis_tvalid : out std_logic;
			output_1_axis_tready : in std_logic;
			output_1_axis_tlast  : out std_logic;
			output_1_axis_tuser  : out std_logic;

			enable : in std_logic;
			control : in std_logic_vector(0 downto 0)
		);
	end component;

	component axis_adapter
		generic (
			INPUT_DATA_WIDTH  : natural := 8;
			INPUT_KEEP_WIDTH  : natural := 1;
			OUTPUT_DATA_WIDTH : natural := 8;
			OUTPUT_KEEP_WIDTH : natural := 1
		);
		port (
			clk : in std_logic;
			rst : in std_logic;

			--AXIS input
			input_axis_tdata  : in std_logic_vector(INPUT_DATA_WIDTH-1 downto 0);
			input_axis_tkeep  : in std_logic_vector(INPUT_KEEP_WIDTH-1 downto 0);
			input_axis_tvalid : in std_logic;
			input_axis_tready : out std_logic;
			input_axis_tlast  : in std_logic;
			input_axis_tuser  : in std_logic;

			--AXIS input
			output_axis_tdata  : out std_logic_vector(OUTPUT_DATA_WIDTH-1 downto 0);
			output_axis_tkeep  : out std_logic_vector(OUTPUT_KEEP_WIDTH-1 downto 0);
			output_axis_tvalid : out std_logic;
			output_axis_tready : in std_logic;
			output_axis_tlast  : out std_logic;
			output_axis_tuser  : out std_logic
		);
	end component;

	component axis_arb_mux_3
		generic (
			DATA_WIDTH : natural := 8;
			ARB_TYPE : string := "PRIORITY"; --"PRIORITY" or "ROUND_ROBIN"
			LSB_PRIORITY : string := "HIGH" --"LOW" or "HIGH"
		);
		port (
			clk : in std_logic;
			rst : in std_logic;

			input_0_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_0_axis_tvalid : in std_logic;
			input_0_axis_tready : out std_logic;
			input_0_axis_tlast  : in std_logic;
			input_0_axis_tuser  : in std_logic;

			input_1_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_1_axis_tvalid : in std_logic;
			input_1_axis_tready : out std_logic;
			input_1_axis_tlast  : in std_logic;
			input_1_axis_tuser  : in std_logic;

			input_2_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_2_axis_tvalid : in std_logic;
			input_2_axis_tready : out std_logic;
			input_2_axis_tlast  : in std_logic;
			input_2_axis_tuser  : in std_logic;

			output_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_axis_tvalid  : out std_logic;
			output_axis_tready  : in std_logic;
			output_axis_tlast   : out std_logic;
			output_axis_tuser   : out std_logic
		);
	end component;

	component axis_async_fifo
		generic (
			ADDR_WIDTH : natural := 12;
			DATA_WIDTH : natural := 8
		);
		port (
			async_rst          : in std_logic;

			input_clk          : in std_logic;
			input_axis_tdata   : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_axis_tvalid  : in std_logic;
			input_axis_tready  : out std_logic;
			input_axis_tlast   : in std_logic;
			input_axis_tuser   : in std_logic;

			output_clk         : in std_logic;
			output_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_axis_tvalid : out std_logic;
			output_axis_tready : in std_logic;
			output_axis_tlast  : out std_logic;
			output_axis_tuser  : out std_logic
		);
	end component;

end tcp_bridge_pkg;

package body tcp_bridge_pkg is

	function byte_swap(word_in : std_logic_vector) return std_logic_vector is
		variable word_out : std_logic_vector(word_in'range);
		variable num_bytes : natural := word_in'length/8;
	begin
			for ct in 0 to num_bytes-1 loop
				word_out(8*(ct+1)-1 downto 8*ct) := word_in(8*(num_bytes-ct)-1 downto 8*(num_bytes-ct-1));
			end loop;
			return word_out;
	end function byte_swap;

end package body;
