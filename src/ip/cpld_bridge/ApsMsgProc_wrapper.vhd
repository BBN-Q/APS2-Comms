-- Wrapper around ZRL ApsMsgProc
-- * Prepends rx packets with a fake Ethernet frame header_ct
-- * strips header of tx packets
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cpld_bridge_pkg.all;

entity ApsMsgProc_wrapper is
  port (
    clk : in std_logic;
    rst : in std_logic;

    --RX and TX to TCP comms.
    rx_tdata  : in std_logic_vector(7 downto 0);
    rx_tvalid : in std_logic;
    rx_tready : out std_logic;
    rx_tlast  : in std_logic;

    tx_tdata  : out std_logic_vector(7 downto 0);
    tx_tvalid : out std_logic;
    tx_tready : in std_logic;
    tx_tlast  : out std_logic;

    -- Config Bus Connections
    cfg_clk   : in std_logic;	-- 100 MHZ clock from the Config CPLD
    cfgd      : inout std_logic_vector(15 downto 0);	-- Config Data bus from CPLD
    fpga_cmdl : out std_logic;	-- Command strobe from FPGA
    fpga_rdyl : out std_logic;	-- Ready Strobe from FPGA
    cfg_rdy   : in std_logic;	-- Ready to complete current transfer.	Connected to CFG_RDWR_B
    cfg_err   : in std_logic;	-- Error during current command.	Connecte to CFG_CSI_B
    cfg_act   : in std_logic;	-- Current transaction is complete
    stat_oel  : out std_logic -- Enable CPLD to drive status onto CFGD

  );
end entity;

architecture arch of ApsMsgProc_wrapper is

  signal rx_framed_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_framed_tvalid, rx_framed_tready, rx_framed_tlast : std_logic := '0';

  signal rx_frame_status_tvalid, rx_frame_padded, rx_frame_truncated : std_logic;
  signal rx_frame_length, rx_frame_original_length : unsigned(15 downto 0);

  signal rx_msgproc_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal rx_msgproc_tvalid, rx_msgproc_tready, rx_msgproc_tlast : std_logic := '0';

  signal tx_msgproc_tdata : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_msgproc_tvalid, tx_msgproc_tready, tx_msgproc_tlast : std_logic := '0';

  type ethernet_frame_header_t is array(0 to 15) of std_logic_vector(7 downto 0);
  constant ethernet_frame_header : ethernet_frame_header_t := (
  x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", -- destination MAC address
  x"ba", x"ad", x"0d", x"db", x"a1", x"11", -- source MAC address
  x"bb", x"4e", --frame type
  x"00", x"00" --sequence number
  );

  type rx_framer_state_t is (IDLE, WRITE_HEADER, WAIT_FOR_LAST, INTERFRAME_GAP);
  signal rx_framer_state : rx_framer_state_t;

  signal header_tdata : std_logic_vector(7 downto 0);

  type tx_deframer_state_t is (IDLE, STRIP_HEADER, WAIT_FOR_LAST);
  signal tx_deframer_state : tx_deframer_state_t;

  signal nv_data : std_logic_vector(63 downto 0);
  signal mac_addr : std_logic_vector(47 downto 0);
  signal good_toggle, bad_toggle : std_logic;

begin

--Frame incoming packets with a fake Ethernet frame header
rx_framer : process(clk)
	variable header_ct : integer range 0 to ethernet_frame_header'length;
	variable ifg_ct : integer range 1 to 12;
begin
	if rising_edge(clk) then
		if rst = '1' then
			rx_framer_state <= IDLE;
			header_ct := 0;
			ifg_ct := 1;
		else

			case( rx_framer_state ) is

				when IDLE =>
					header_ct := 0;
					ifg_ct := 1;
					--wait for valid to signal start of packet
					if rx_tvalid = '1' then
						rx_framer_state <= WRITE_HEADER;
					end if;

				when WRITE_HEADER =>
					if rx_framed_tready = '1' then
						if header_ct = ethernet_frame_header'length-1 then
							rx_framer_state <= WAIT_FOR_LAST;
						else
							header_ct := header_ct + 1;
						end if;
					end if;

				when WAIT_FOR_LAST =>
					--wait for tlast
					if rx_tvalid = '1' and rx_tlast = '1' then
						rx_framer_state <= INTERFRAME_GAP;
					end if;

				--Not actually sure what the ApsMsgProc demands but might as well be compliant with convention
				when INTERFRAME_GAP =>
					if ifg_ct = 12 then
						rx_framer_state <= IDLE;
					end if;
					ifg_ct := ifg_ct + 1;

			end case;
		end if;

		header_tdata <= ethernet_frame_header(header_ct);

	end if;
end process;

--combinational AXIS signals
--hold back data until frame is applied
rx_tready <= rx_framed_tready when rx_framer_state = WAIT_FOR_LAST else '0';
rx_framed_tlast <= rx_tlast when rx_framer_state = WAIT_FOR_LAST else '0';
with rx_framer_state select rx_framed_tvalid <=
	'1' when WRITE_HEADER,
	rx_tvalid when WAIT_FOR_LAST,
	'0' when others;
with rx_framer_state select rx_framed_tdata <=
	header_tdata when WRITE_HEADER,
	rx_tdata when others;

--Make sure we have a valid ethernet frame size
--Instantiate axis_frame_length_adjust
rx_frame_adjuster_inst : axis_frame_length_adjust
	generic map (
		DATA_WIDTH => 8
	)
	port map (
		clk => clk,
		rst => rst,

		--AXIS input
		input_axis_tdata  => rx_framed_tdata,
		input_axis_tkeep  => "1",
		input_axis_tvalid => rx_framed_tvalid,
		input_axis_tready => rx_framed_tready,
		input_axis_tlast  => rx_framed_tlast,
		input_axis_tuser  => '0',

		--AXIS output
		output_axis_tdata  => rx_msgproc_tdata,
		output_axis_tkeep  => open,
		output_axis_tvalid => rx_msgproc_tvalid,
		output_axis_tready => rx_msgproc_tready,
		output_axis_tlast  => rx_msgproc_tlast,
		output_axis_tuser  => open,

		--status
		status_valid                           => rx_frame_status_tvalid,
		status_ready                           => '1',
		status_frame_pad                       => rx_frame_padded,
		status_frame_truncate                  => rx_frame_truncated,
		unsigned(status_frame_length)          => rx_frame_length,
		unsigned(status_frame_original_length) => rx_frame_original_length,

		--control
		length_min => x"0040", --64
		length_max => x"05f2" --1522
	);
--Questionable assumption ApsMsgProc can always take data
rx_msgproc_tready <= '1';

--strip Ethernet frame header from tx packets
tx_deframer : process(clk)
	variable header_ct : integer range 0 to ethernet_frame_header'length;
begin
	if rising_edge(clk) then
		if rst = '1' then
			tx_deframer_state <= IDLE;
			header_ct := 0;
		else
			case( tx_deframer_state ) is

				when IDLE =>
					header_ct := 0;
					--wait for valid to assert to indicate start of packet
					if tx_msgproc_tvalid = '1' then
						tx_deframer_state <= STRIP_HEADER;
					end if;

				when STRIP_HEADER =>
					if header_ct = ethernet_frame_header'length-2 then
						tx_deframer_state <= WAIT_FOR_LAST;
					end if;
					header_ct := header_ct + 1;

				when WAIT_FOR_LAST =>
					if tx_msgproc_tvalid = '1' and tx_msgproc_tlast = '1' and tx_tready = '1' then
						tx_deframer_state <= IDLE;
					end if;

			end case;
		end if;
	end if;
end process;

--combinational AXIS signals
tx_tdata <= tx_msgproc_tdata;
tx_tvalid <= tx_msgproc_tvalid when tx_deframer_state = WAIT_FOR_LAST else '0';
tx_tlast <= tx_msgproc_tlast when tx_deframer_state = WAIT_FOR_LAST else '0';
tx_msgproc_tready <= tx_tready when tx_deframer_state = WAIT_FOR_LAST else '1';

--Intantiate ZRL message processor
--Because the only working simulation model we have is old have to if generate block
-- msgproc_sim : if in_simulation generate
-- AMP1 : entity work.ApsMsgProc
--   port map
--   (
--   -- Interface to MAC to get Ethernet packets
--   	MAC_CLK			 => clk,
--   	RESET				 => rst,
--
--   	MAC_RXD      => rx_msgproc_tdata,
--   	MAC_RX_VALID => rx_msgproc_tvalid,
--   	MAC_RX_EOP   => rx_msgproc_tlast,
--   	MAC_BAD_FCS	 => '0',
--
--   	MAC_TXD       => tx_msgproc_tdata,
--   	MAC_TX_RDY    => tx_msgproc_tready,
--   	MAC_TX_VALID  => tx_msgproc_tvalid,
--   	MAC_TX_EOP    => tx_msgproc_tlast,
--
--   	-- User Logic Connections
--   	USER_CLK     => clk,
--   	USER_RST     => open,
--   	USER_VERSION => x"badda555",
--   	USER_STATUS	 => x"0ddba111",
--
--   	USER_DIF      => open,
--   	USER_DIF_RD   => '0',
--
--   	USER_CIF_EMPTY => open,
--   	USER_CIF_RD    => '0',
--   	USER_CIF_RW    => open,
--   	USER_CIF_MODE  => open,
--   	USER_CIF_CNT   => open,
--   	USER_CIF_ADDR  => open,
--
--   	USER_DOF       => (others => '0'),
--   	USER_DOF_WR    => '0',
--
--   	USER_COF_STAT	=> (others => '0'),
--   	USER_COF_CNT	 => (others => '0'),
--   	USER_COF_AFULL => open,
--   	USER_COF_WR		=> '0',
--
--   	-- Config Bus Connections
--   	CFG_CLK				=> cfg_clk,
--
--   	-- ApsMsgProc OlderVersion
--   	CFGD_IN       => x"AAAA",
--   	CFGD_OUT      => open,
--   	CFGD_OE       => open,
--   	STAT_OE       => open,
--
--   	-- Status to top level
--   	GOOD_TOGGLE	 => good_toggle,
--   	BAD_TOGGLE		=> bad_toggle
--   );
-- end generate;

msgproc_impl : if in_synthesis generate
  -- This encapsulates all of the packet and message processing
  AMP1 : ApsMsgProc
  port map
  (
  -- Interface to MAC to get Ethernet packets
    MAC_CLK       => clk,
    RESET         => rst,

    MAC_RXD      => rx_msgproc_tdata,
  	MAC_RX_VALID => rx_msgproc_tvalid,
  	MAC_RX_EOP   => rx_msgproc_tlast,
  	MAC_BAD_FCS	 => '0',

  	MAC_TXD       => tx_msgproc_tdata,
  	MAC_TX_RDY    => tx_msgproc_tready,
  	MAC_TX_VALID  => tx_msgproc_tvalid,
  	MAC_TX_EOP    => tx_msgproc_tlast,

    NV_DATA       => open,
    MAC_ADDRESS   => open,

    -- User Logic Connections
    USER_CLK     => clk,
  	USER_RST     => open,
  	USER_VERSION => x"badda555",
  	USER_STATUS	 => x"0ddba111",

  	USER_DIF      => open,
  	USER_DIF_RD   => '0',

  	USER_CIF_EMPTY => open,
  	USER_CIF_RD    => '0',
  	USER_CIF_RW    => open,
  	USER_CIF_MODE  => open,
  	USER_CIF_CNT   => open,
  	USER_CIF_ADDR  => open,

  	USER_DOF       => (others => '0'),
  	USER_DOF_WR    => '0',

  	USER_COF_STAT	 => (others => '0'),
  	USER_COF_CNT	 => (others => '0'),
  	USER_COF_AFULL => open,
  	USER_COF_WR		 => '0',

    -- Config Bus Connections
    CFG_CLK    => cfg_clk,
    CFGD       => cfgd,
    FPGA_CMDL  => fpga_cmdl,
    FPGA_RDYL  => fpga_rdyl,
    CFG_RDY    => cfg_rdy,
    CFG_ERR    => cfg_err,
    CFG_ACT    => cfg_act,
    STAT_OEL   => stat_oel,

    -- Status to top level
    GOOD_TOGGLE => good_toggle,
  	BAD_TOGGLE  => bad_toggle
  );
end generate;

end architecture;
