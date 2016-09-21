library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package udp_responder_pkg is

	component axis_frame_fifo
    generic (
			ADDR_WIDTH     : natural := 12;
	    DATA_WIDTH     : natural := 8;
	    DROP_WHEN_FULL : boolean := false
    );
    port (
      clk         : in std_logic;
      rst         : in std_logic;

      input_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
      input_axis_tvalid : in std_logic;
      input_axis_tready : out std_logic;
      input_axis_tlast  : in std_logic;
      input_axis_tuser  : in std_logic;

      output_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      output_axis_tvalid : out std_logic;
      output_axis_tready : in std_logic;
      output_axis_tlast  : out std_logic;

			overflow   : out std_logic;
	    bad_frame  : out std_logic;
	    good_frame : out std_logic
    );
  end component;

end udp_responder_pkg;
