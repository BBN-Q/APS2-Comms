-- Reads configuration bytes from EPROM
-- * MAC address
-- * IPv4 address
-- * DHCP enable bit
--
-- Original authors: Brian Donnovan, Colm Ryan
-- Copyright 2015, Raytheon BBN Technologies

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eprom_cfg_reader is
  generic (
    DEFAULT_MAC_ADDR : std_logic_vector(47 downto 0) := x"4651dbbada55";
    DEFAULT_IP_ADDR : std_logic_vector(31 downto 0) := x"c0a8027b"
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    -- coming from ethernet
    rx_in_tdata  : in std_logic_vector(31 downto 0);
    rx_in_tvalid : in std_logic;
    rx_in_tready : out std_logic;
    rx_in_tlast  : in std_logic;

    -- going to CPLD
    rx_out_tdata  : out std_logic_vector(31 downto 0);
    rx_out_tvalid : out std_logic;
    rx_out_tlast  : out std_logic;
    rx_out_tready : in std_logic;

    -- coming from CPLD
    tx_in_tdata  : in std_logic_vector(31 downto 0);
    tx_in_tvalid : in std_logic;
    tx_in_tready : out std_logic;
    tx_in_tlast  : in std_logic;

    -- going to ethernet
    tx_out_tdata  : out std_logic_vector(31 downto 0);
    tx_out_tvalid : out std_logic;
    tx_out_tlast  : out std_logic;
    tx_out_tready : in std_logic;

    -- configuration/status ports
    mac_addr : out std_logic_vector(47 downto 0);
    ip_addr  : out std_logic_vector(31 downto 0);
    dhcp_enable : out std_logic;
    done : out std_logic

  );
end entity;

architecture arch of eprom_cfg_reader is

  constant READ_EPROM_CMD	: std_logic_vector(31 downto 0) := x"12000004"; -- read 4 32 bit words
  constant EPROM_ADDR : std_logic_vector(31 downto 0) := x"00FF0000"; --starting at 0x00FF0000

  type main_state_t is (START, WRITE_CMD, WRITE_ADDR, READ_RESPONSE, FINISHED);
  signal main_state : main_state_t;

  signal recv_eprom_cmd : std_logic_vector(31 downto 0);

begin

main : process(clk)
  variable read_ct : natural range 0 to 5;
begin
  if rising_edge(clk) then
    if rst = '1' then
      main_state <= START;
      read_ct := 0;
      mac_addr <= DEFAULT_MAC_ADDR;
      ip_addr <= DEFAULT_IP_ADDR;
      dhcp_enable <= '0';
    else
      case( main_state ) is

        when START =>
          main_state <= WRITE_CMD;

        when WRITE_CMD =>
          if rx_out_tready = '1' then
            main_state <= WRITE_ADDR;
          end if;

        when WRITE_ADDR =>
          if rx_out_tready = '1' then
            main_state <= READ_RESPONSE;
          end if;

        when READ_RESPONSE =>
          --TODO: do we need a timeout here?
          if tx_in_tvalid = '1' then
            case( read_ct ) is
              when 0 =>
                recv_eprom_cmd <= tx_in_tdata;
              when 1 =>
                mac_addr(47 downto 16) <= tx_in_tdata;
              when 2 =>
                mac_addr(15 downto 0) <= tx_in_tdata(31 downto 16);
              when 3 =>
                ip_addr <= tx_in_tdata;
              when 4 =>
                dhcp_enable <= tx_in_tdata(0);
                main_state <= FINISHED;
              when others =>
                null;
            end case;
            read_ct := read_ct + 1;
          end if;

        when FINISHED =>
            null;

      end case;

    end if;
  end if;
end process;

done <= '1' when main_state = FINISHED else '0';

--Mux streams
with main_state select rx_out_tdata <=
  READ_EPROM_CMD when WRITE_CMD,
  EPROM_ADDR when WRITE_ADDR,
  rx_in_tdata when others;
with main_state select rx_out_tvalid <=
  rx_in_tvalid when FINISHED,
  '1' when WRITE_CMD | WRITE_ADDR,
  '0' when others;
  with main_state select rx_out_tlast <=
    rx_in_tlast when FINISHED,
    '1' when WRITE_ADDR,
    '0' when others;
rx_in_tready <= rx_out_tready when main_state = FINISHED else '0';

tx_out_tdata <= tx_in_tdata;
tx_out_tvalid <= tx_in_tvalid when main_state = FINISHED else '0';
tx_out_tlast <= tx_in_tlast when main_state = FINISHED else '0';
tx_in_tready <= tx_out_tready when main_state = FINISHED else '1';

end architecture;
