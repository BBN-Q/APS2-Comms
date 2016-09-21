library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package com5402_wrapper_pkg is

  component axis_srl_fifo
    generic (
      DATA_WIDTH : natural := 8;
      DEPTH : natural := 16
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
      output_axis_tuser  : out std_logic;

      count : out std_logic_vector(integer(ceil(log2(real(DEPTH+1))))-1 downto 0)
    );
  end component;

end com5402_wrapper_pkg;
