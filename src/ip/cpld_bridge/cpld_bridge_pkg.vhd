library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package CPLD_bridge_pkg is

	--Sort out whether we are in simulation or synthesis
	constant in_simulation : boolean := false
	--pragma synthesis_off
																			or true
	--pragma synthesis_on
	;

	constant in_synthesis : boolean := not in_simulation;

	function byte_swap(word_in : std_logic_vector) return std_logic_vector;

	component axis_frame_length_adjust
		generic (
			DATA_WIDTH : natural := 8;
			KEEP_WIDTH : natural := 1
		);
		port (
			clk : in std_logic;
			rst : in std_logic;

			--AXIS input
			input_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
			input_axis_tkeep  : in std_logic_vector(KEEP_WIDTH-1 downto 0);
			input_axis_tvalid : in std_logic;
			input_axis_tready : out std_logic;
			input_axis_tlast  : in std_logic;
			input_axis_tuser  : in std_logic;

			--AXIS output
			output_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			output_axis_tkeep  : out std_logic_vector(KEEP_WIDTH-1 downto 0);
			output_axis_tvalid : out std_logic;
			output_axis_tready : in std_logic;
			output_axis_tlast  : out std_logic;
			output_axis_tuser  : out std_logic;

			--status
			status_valid                 : out std_logic;
			status_ready                 : in std_logic;
			status_frame_pad             : out std_logic;
			status_frame_truncate        : out std_logic;
			status_frame_length          : out std_logic_vector(15 downto 0);
			status_frame_original_length : out std_logic_vector(15 downto 0);

			--control
			length_min : in std_logic_vector(15 downto 0);
			length_max : in std_logic_vector(15 downto 0)
		);
	end component;

	component axis_adapter
		generic (
			INPUT_DATA_WIDTH : natural := 8;
			INPUT_KEEP_WIDTH : natural := 1;
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

	-- comment out this component declaration for simulation
	component ApsMsgProc
		port
		(
		  -- Interface to MAC to get Ethernet packets
		  MAC_CLK       : in std_logic;                             -- Clock for command FIFO interface
		  RESET         : in std_logic;                             -- Reset for Command Interface

		  MAC_RXD       : in std_logic_vector(7 downto 0);  -- Data read from input FIFO
		  MAC_RX_VALID  : in std_logic;                     -- Set when input fifo empty
		  MAC_RX_EOP    : in std_logic;                     -- Marks the end of a receive packet in Ethernet RX FIFO
		  MAC_BAD_FCS   : in std_logic;                     -- Set during EOP/VALID received packet had CRC error

		  MAC_TXD       : out std_logic_vector(7 downto 0); -- Data to write to output FIFO
		  MAC_TX_RDY    : in std_logic;                     -- Set when MAC can accept data
		  MAC_TX_VALID  : out std_logic;                    -- Set to write the Ethernet TX FIFO
		  MAC_TX_EOP    : out std_logic;                    -- Marks the end of a transmit packet to the Ethernet TX FIFO

		  -- Non-volatile Data
		  NV_DATA       : out std_logic_vector(63 downto 0);  -- NV Data from Multicast Address Words
		  MAC_ADDRESS   : out std_logic_vector(47 downto 0);  -- MAC Address from EPROM

			BOARD_TYPE    : in std_logic_vector(7 downto 0); -- x"00" for APS2 and x"01" for TDM

		  -- User Logic Connections
		  USER_CLK       : in std_logic;                      -- Clock for User side of FIFO interface
		  USER_RST       : out std_logic;                     -- User Logic global reset, synchronous to USER_CLK
		  USER_VERSION   : in std_logic_vector(31 downto 0);  -- User Logic Firmware Version.  Passed back in status packets
		  USER_STATUS    : in std_logic_vector(31 downto 0);  -- User Status Word.  Passed back in status packets

		  USER_DIF       : out std_logic_vector(31 downto 0); -- User Data Input FIFO output
		  USER_DIF_RD    : in std_logic;                      -- User Data Onput FIFO Read Enable

		  USER_CIF_EMPTY : out std_logic;                     -- Low when there is data available
		  USER_CIF_RD    : in std_logic;                      -- Command Input FIFO Read Enable
		  USER_CIF_RW    : out std_logic;                     -- High for read, low for write
		  USER_CIF_MODE  : out std_logic_vector(7 downto 0);  -- MODE field from current User I/O command
		  USER_CIF_CNT   : out std_logic_vector(15 downto 0); -- CNT field from current User I/O command
		  USER_CIF_ADDR  : out std_logic_vector(31 downto 0); -- Address for the current command

		  USER_DOF       : in std_logic_vector(31 downto 0);  -- User Data Onput FIFO input
		  USER_DOF_WR    : in std_logic;                      -- User Data Onput FIFO Write Enable

		  USER_COF_STAT  : in std_logic_vector(7 downto 0);   -- STAT value to return for current User I/O command
		  USER_COF_CNT   : in std_logic_vector(15 downto 0);  -- Number of words written to DOF for current User I/O command
		  USER_COF_AFULL : out std_logic;                     -- User Control Output FIFO Almost Full
		  USER_COF_WR    : in std_logic;                       -- User Control Onput FIFO Write Enable

		  -- Config CPLD Data Bus for reading status when STAT_OE is asserted
		  CFG_CLK    : in  STD_LOGIC;  -- 100 MHZ clock from the Config CPLD
		  CFGD       : inout std_logic_vector(15 downto 0);  -- Config Data bus from CPLD
		  FPGA_CMDL  : out  STD_LOGIC;  -- Command strobe from FPGA
		  FPGA_RDYL  : out  STD_LOGIC;  -- Ready Strobe from FPGA
		  CFG_RDY    : in  STD_LOGIC;  -- Ready to complete current transfer
		  CFG_ERR    : in  STD_LOGIC;  -- Error during current command
		  CFG_ACT    : in  STD_LOGIC;  -- Current transaction is complete
		  STAT_OEL   : out std_logic; -- Enable CPLD to drive status onto CFGD

		  -- Status to top level
		  GOOD_TOGGLE   : out std_logic;
		  BAD_TOGGLE    : out std_logic
		);
	end component;

end CPLD_bridge_pkg;

package body cpld_bridge_pkg is

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
