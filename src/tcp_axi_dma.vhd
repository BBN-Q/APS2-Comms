-- Bridge from TCP receive and send streams to an AXI memory map
-- Also can route packets to/from CPLD interface
--
-- Original author: Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tcp_bridge_pkg.all;

entity TCP_AXI_DMA is
	port (
		clk : in std_logic;
		rst : in std_logic;

		---TCP receive
		rx_tdata  : in std_logic_vector(31 downto 0);
		rx_tvalid : in std_logic;
		rx_tready : out std_logic;
		rx_tlast  : in std_logic;

		--TCP send channels
		tx_write_resp_tdata  : out std_logic_vector(31 downto 0);
		tx_write_resp_tvalid : out std_logic;
		tx_write_resp_tlast  : out std_logic;
		tx_write_resp_tready : in std_logic;

		tx_read_resp_tdata  : out std_logic_vector(31 downto 0);
		tx_read_resp_tvalid : out std_logic;
		tx_read_resp_tlast  : out std_logic;
		tx_read_resp_tready : in std_logic;

		--DataMover interfaces
		MM2S_CMD_tdata  : out std_logic_vector( 71 downto 0 );
		MM2S_CMD_tready : in std_logic;
		MM2S_CMD_tvalid : out std_logic;

		MM2S_tdata  : in std_logic_vector( 31 downto 0 );
		MM2S_tkeep  : in std_logic_vector( 3 downto 0 );
		MM2S_tlast  : in std_logic;
		MM2S_tready : out std_logic;
		MM2S_tvalid : in std_logic;

		MM2S_STS_tdata  : in std_logic_vector( 7 downto 0 );
		MM2S_STS_tkeep  : in std_logic_vector( 0 to 0 );
		MM2S_STS_tlast  : in std_logic;
		MM2S_STS_tready : out std_logic;
		MM2S_STS_tvalid : in std_logic;

		S2MM_CMD_tdata  : out std_logic_vector( 71 downto 0 );
		S2MM_CMD_tready : in std_logic;
		S2MM_CMD_tvalid : out std_logic;

		S2MM_tdata  : out std_logic_vector( 31 downto 0 );
		S2MM_tkeep  : out std_logic_vector( 3 downto 0 );
		S2MM_tlast  : out std_logic;
		S2MM_tready : in std_logic;
		S2MM_tvalid : out std_logic;

		S2MM_STS_tdata  : in std_logic_vector( 7 downto 0 );
		S2MM_STS_tkeep  : in std_logic_vector( 0 to 0 );
		S2MM_STS_tlast  : in std_logic;
		S2MM_STS_tready : out std_logic;
		S2MM_STS_tvalid : in std_logic
	);
end entity;

architecture arch of TCP_AXI_DMA is

--Annoying internal signals for Vivado's crummy VHDL support
signal rx_tready_int : std_logic;
signal tx_write_resp_tvalid_int : std_logic;
signal tx_read_resp_tvalid_int : std_logic;

type DataMoverCmd_t is record
	rsvd    : std_logic_vector(3 downto 0) ;
	tag     : std_logic_vector(3 downto 0) ;
	addr    : std_logic_vector(31 downto 0) ;
	drr     : std_logic;
	eof     : std_logic;
	dsa     : std_logic_vector(5 downto 0) ;
	axiType : std_logic;
	btt     : std_logic_vector(22 downto 0) ;
end record;

signal mover_cmd : DataMoverCmd_t := (rsvd => (others => '0'), tag => (others => '0'), addr => (others => '0'), drr => '0', eof => '1', dsa => (others => '0'), axiType => '1', btt => (others => '0'));

function movercmd2slv(cmd : DataMoverCmd_t) return std_logic_vector is
variable slvOut : std_logic_vector(71 downto 0) ;
begin
	slvOut := cmd.rsvd & cmd.tag & cmd.addr & cmd.drr & cmd.eof & cmd.dsa & cmd.axiType & cmd.btt;
	return slvOut;
end movercmd2slv;

type main_state_t is (IDLE, LATCH_CONTROL, LATCH_ADDR, ISSUE_DMA_READ_CMD, ISSUE_DMA_WRITE_CMD, WAIT_FOR_LAST);
signal main_state : main_state_t;

type mm2s_data_state_t is (IDLE, WRITE_CMD, WRITE_ADDR, WAIT_FOR_LAST);
signal mm2s_data_state : mm2s_data_state_t;

type s2mm_status_state_t is (IDLE, CHECK_ACK_NEEDED, WRITE_CMD, WRITE_ADDR, DRIVE_READY);
signal s2mm_status_state : s2mm_status_state_t;

signal write_cmd_in_tdata : std_logic_vector(63 downto 0) := (others => '0');
signal write_cmd_in_tvalid, write_cmd_in_tready, write_cmd_in_tlast : std_logic := '0';
signal write_cmd_out_tdata : std_logic_vector(63 downto 0) := (others => '0');
signal write_cmd_out_tvalid, write_cmd_out_tready, write_cmd_out_tlast : std_logic := '0';
signal write_cmd_fifo_count : std_logic_vector(4 downto 0);

signal read_cmd_in_tdata : std_logic_vector(63 downto 0) := (others => '0');
signal read_cmd_in_tvalid, read_cmd_in_tready, read_cmd_in_tlast : std_logic := '0';
signal read_cmd_out_tdata : std_logic_vector(63 downto 0) := (others => '0');
signal read_cmd_out_tvalid, read_cmd_out_tready, read_cmd_out_tlast : std_logic := '0';
signal read_cmd_fifo_count : std_logic_vector(4 downto 0);

begin

--Irritatingly Vivado simulator doesn't support VHDL-2008 so need extra signal to read out port
rx_tready <= rx_tready_int;
tx_write_resp_tvalid <= tx_write_resp_tvalid_int;
tx_read_resp_tvalid <= tx_read_resp_tvalid_int;

main : process(clk)
	variable cmd  : std_logic_vector(31 downto 0);
	variable addr : std_logic_vector(31 downto 0);
	alias cmd_rw  : std_logic is cmd(28);
	variable accepted_tcp_data : boolean;
begin
	if rising_edge(clk) then
		if rst = '1' then
			main_state <= IDLE;
		else

			accepted_tcp_data := rx_tvalid = '1' and rx_tready_int = '1';

			write_cmd_in_tdata <= cmd & addr;
			write_cmd_in_tvalid <= '0';
			write_cmd_in_tlast <= '0';

			read_cmd_in_tdata <= cmd & addr;
			read_cmd_in_tvalid <= '0';
			read_cmd_in_tlast <= '0';

			case( main_state ) is

				when IDLE =>
					--Use tx_valid to indicate start of packet
					if rx_tvalid = '1' then
						main_state <= LATCH_CONTROL;
					end if;

				when LATCH_CONTROL =>
					cmd := rx_tdata;
					mover_cmd.btt <= b"00000" & cmd(15 downto 0) & b"00";
					mover_cmd.tag <= cmd(27 downto 24);
					if accepted_tcp_data then
						main_state <= LATCH_ADDR;
					end if;

				when LATCH_ADDR =>
					addr := rx_tdata;
					mover_cmd.addr <= addr;
					if accepted_tcp_data then
						if cmd_rw = '1' then
							main_state <= ISSUE_DMA_READ_CMD;
						else
							main_state <= ISSUE_DMA_WRITE_CMD;
						end if;
					end if;

				when ISSUE_DMA_WRITE_CMD =>
					if S2MM_tready = '1' then
						--Should probably also check cmd FIFO isn't full
						write_cmd_in_tvalid <= '1';
						write_cmd_in_tlast <= '1';
						main_state <= WAIT_FOR_LAST;
					end if;

				when ISSUE_DMA_READ_CMD =>
					if MM2S_CMD_tready = '1' then
						--Should probably also check cmd FIFO isn't full
						read_cmd_in_tvalid <= '1';
						read_cmd_in_tlast <= '1';
						main_state <= IDLE;
					end if;

				when WAIT_FOR_LAST =>
					if accepted_tcp_data and rx_tlast = '1' then
							main_state <= IDLE;
					end if;
			end case;
		end if;
	end if;
end process;

--Combinational signals
S2MM_tkeep <= "1111"; --Assume 4 byte boundaries for now
S2MM_tdata <= rx_tdata;
S2MM_tvalid <= rx_tvalid when (main_state = WAIT_FOR_LAST) else '0';
S2MM_tlast <= rx_tlast;
--hold ready high for latching control and address otherwise let stream handle
with main_state select rx_tready_int <=
	S2MM_tready when WAIT_FOR_LAST,
	'1' when LATCH_CONTROL | LATCH_ADDR,
	'0' when others;

--We only have one source of mover commands so wire both S2MM and MM2S to the same command
S2MM_CMD_tdata <=	movercmd2slv(mover_cmd);
MM2S_CMD_tdata <= movercmd2slv(mover_cmd);
--just use the valid to choose between S2MM and MM2S
S2MM_CMD_tvalid <= '1' when (main_state = ISSUE_DMA_WRITE_CMD) else '0';
MM2S_CMD_tvalid <= '1' when (main_state = ISSUE_DMA_READ_CMD) else '0';

-- FIFOs to store read/write commands waiting for status or read responses
write_cmd_fifo: axis_srl_fifo
generic map (
	DATA_WIDTH => 64,
	DEPTH => 16
)
port map (
	clk => clk,
	rst => rst,

	input_axis_tdata  => write_cmd_in_tdata,
	input_axis_tvalid => write_cmd_in_tvalid,
	input_axis_tready => write_cmd_in_tready,
	input_axis_tlast  => write_cmd_in_tlast,
	input_axis_tuser  => '0',

	output_axis_tdata  => write_cmd_out_tdata,
	output_axis_tvalid => write_cmd_out_tvalid,
	output_axis_tready => write_cmd_out_tready,
	output_axis_tlast  => write_cmd_out_tlast,
	output_axis_tuser  => open,

	count => write_cmd_fifo_count
);

read_cmd_fifo: axis_srl_fifo
generic map (
	DATA_WIDTH => 64,
	DEPTH => 16
)
port map (
	clk => clk,
	rst => rst,

	input_axis_tdata  => read_cmd_in_tdata,
	input_axis_tvalid => read_cmd_in_tvalid,
	input_axis_tready => read_cmd_in_tready,
	input_axis_tlast  => read_cmd_in_tlast,
	input_axis_tuser  => '0',

	output_axis_tdata  => read_cmd_out_tdata,
	output_axis_tvalid => read_cmd_out_tvalid,
	output_axis_tready => read_cmd_out_tready,
	output_axis_tlast  => read_cmd_out_tlast,
	output_axis_tuser  => open,

	count => read_cmd_fifo_count
);

--read data receiver
mm2s_data_receiver : process(clk)
begin
	if rising_edge(clk) then
		if rst = '1' then
			mm2s_data_state <= IDLE;
			read_cmd_out_tready <= '0';
		else
			read_cmd_out_tready <= '0';

			case( mm2s_data_state ) is

				when IDLE =>
					--wait for cmd fifo valid to signal command has been issued
					if read_cmd_out_tvalid = '1' then
						mm2s_data_state <= WRITE_CMD;
					end if;

				when WRITE_CMD =>
					if tx_read_resp_tready = '1' then
						mm2s_data_state <= WRITE_ADDR;
					end if;

				when WRITE_ADDR =>
					if tx_read_resp_tready = '1' then
						mm2s_data_state <= WAIT_FOR_LAST;
						read_cmd_out_tready <= '1';
					end if;

				when WAIT_FOR_LAST =>
					--wait for tlast from MM2S
					--TODO also check status is not error and if error zero pad response and then send error packet
					if MM2S_tlast = '1' and tx_read_resp_tready = '1' then
						mm2s_data_state <= IDLE;
					end if;
			end case;
		end if;
	end if;
end process;
--combinationally mux in MM2S stream
MM2S_tready <= tx_read_resp_tready when mm2s_data_state = WAIT_FOR_LAST else '0';
with mm2s_data_state select tx_read_resp_tdata <=
	read_cmd_out_tdata(63 downto 32) when WRITE_CMD,
	read_cmd_out_tdata(31 downto 0) when WRITE_ADDR,
	MM2S_tdata when others;
with mm2s_data_state select tx_read_resp_tvalid_int <=
	MM2S_tvalid when WAIT_FOR_LAST,
	'1' when WRITE_CMD | WRITE_ADDR,
	'0' when others;
with mm2s_data_state select tx_read_resp_tlast <=
	MM2S_tlast when WAIT_FOR_LAST,
	'0' when others;

--TODO: read in process and send error codes
MM2S_STS_tready <= '1';

s2mm_status_receiver : process(clk)
	variable status : std_logic_vector(7 downto 0);
	alias status_ok : std_logic is status(7);
	variable cmd : std_logic_vector(31 downto 0);
	alias ack_req : std_logic is cmd(31);
begin
	if rising_edge(clk) then
		if rst = '1' then
			s2mm_status_state <= IDLE;
		else

			cmd := write_cmd_out_tdata(63 downto 32);

			case( s2mm_status_state ) is

				when IDLE =>
					status := S2MM_STS_tdata;
					if S2MM_STS_tvalid = '1' and write_cmd_out_tvalid = '1' then
						s2mm_status_state <= CHECK_ACK_NEEDED;
					end if;

				when CHECK_ACK_NEEDED =>
					--check whether there was an error or if we want an acknowledge
					if status_ok = '0' or ack_req = '1' then
						s2mm_status_state <= WRITE_CMD;
					else
						s2mm_status_state <= DRIVE_READY;
					end if;

				when WRITE_CMD =>
					if tx_write_resp_tready = '1' then
						s2mm_status_state <= WRITE_ADDR;
					end if;

				when WRITE_ADDR =>
					if tx_write_resp_tready = '1' then
						s2mm_status_state <= DRIVE_READY;
					end if;

				when DRIVE_READY =>
					s2mm_status_state <= IDLE;

			end case;
		end if;
	end if;
end process;
--combinational AXIS signals
with s2mm_status_state select tx_write_resp_tvalid_int <=
	'1' when WRITE_CMD | WRITE_ADDR,
	'0' when others;
tx_write_resp_tlast	<= '1' when s2mm_status_state = WRITE_ADDR else '0';

--content of an ACK:
-- (ACK SEQ SEL R/W CMD<3:0>) (DATAMOVER STATUS<7:0>) CNT<15:0>
-- ADDRESS<31:0>
with s2mm_status_state select tx_write_resp_tdata <=
	write_cmd_out_tdata(63 downto 56) & S2MM_STS_tdata & write_cmd_out_tdata(47 downto 32) when WRITE_CMD,
	write_cmd_out_tdata(31 downto 0) when WRITE_ADDR,
	(others => '0') when others;

S2MM_STS_tready <= '1' when s2mm_status_state = DRIVE_READY else '0';
write_cmd_out_tready <= '1' when s2mm_status_state = DRIVE_READY else '0';

end architecture;
