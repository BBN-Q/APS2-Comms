
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- models a DHCP server based on 
-- http://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity DHCPServer is
  Port ( 
    MAC_CLK : in std_logic;
    RST : in std_logic;
    
    dhcp_discover_parse_start : in std_logic;
    dhcp_discover_parsed: buffer std_logic;
    
    dhcp_offer_send : in std_logic;
    dhcp_offer_sent : buffer std_logic;
    
    dhcp_request_parse_start : in std_logic;
    dhcp_request_parsed : buffer std_logic;
    
    dhcp_ack_send : in std_logic;
    dhcp_ack_sent : buffer std_logic;
    
    in_trimac :  in std_logic_vector(7 downto 0);
    in_trimac_eop : in std_logic;
    out_trimac : out std_logic_vector(7 downto 0);
    out_trimac_valid : out std_logic;
    out_trimac_eop : out std_logic
  );

end DHCPServer;

architecture Behavioral of DHCPServer is

type DHCPStates_t is (IDLE, PARSE_DISCOVER, SEND_OFFER, PARSE_REQUEST, SEND_ACK);
signal dhcpState : DHCPStates_t;

signal dhcp_discover_error : std_logic := '0';
signal dhcp_mac_src : std_logic_vector(47 downto 0) := (others => '0');
signal dhcp_mac_dest : std_logic_vector(47 downto 0) := (others => '0');
signal dhcp_ip_src : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_ip_dest : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_port_src : std_logic_vector(15 downto 0) := (others => '0');
signal dhcp_port_dest : std_logic_vector(15 downto 0) := (others => '0');
signal dhcp_udp_len : std_logic_vector(15 downto 0) := (others => '0');

signal dhcp_header : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_xid : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_secs : std_logic_vector(15 downto 0) := (others => '0');
signal dhcp_flags : std_logic_vector(15 downto 0) := (others => '0');
signal dhcp_ciaddr : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_yiaddr : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_siaddr : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_giaddr : std_logic_vector(31 downto 0) := (others => '0');
signal dhcp_chaddr : std_logic_vector(127 downto 0) := (others => '0');
signal dhcp_cookie : std_logic_vector(31 downto 0) := (others => '0');

signal ether_frame : std_logic_vector(15 downto 0) := (others => '0');

signal parse_error : std_logic;

signal dhcp_offer_trimac : std_logic_vector(7 downto 0);
signal in_trimac_d : std_logic_vector(7 downto 0);
signal in_trimac_d2 : std_logic_vector(7 downto 0);

signal dhcp_discover_byte_cnt : natural := 0;
signal dhcp_offer_byte_cnt : natural := 0;

begin

out_trimac <=  dhcp_offer_trimac;

dhcp_sm : process( MAC_CLK, RST)
begin
    if rising_edge(MAC_CLK) then
        if (RST = '1') then
            dhcpState <= IDLE;
        end if;
        
        -- store delayed trimac input
        in_trimac_d2 <= in_trimac;
        in_trimac_d <= in_trimac_d2;
        
        if ( dhcp_discover_parse_start = '1' and dhcp_discover_parsed = '0') then
           dhcpState <= PARSE_DISCOVER;
        end if;
        
   
        
        if ( dhcp_offer_send = '1' and dhcp_offer_sent = '0') then
            dhcpState <= SEND_OFFER;
        end if;
              
        if ( dhcp_request_parse_start = '1' and dhcp_request_parsed = '0') then
           dhcpState <= PARSE_REQUEST;
        end if;
        
        if ( dhcp_ack_send = '1' and dhcp_ack_sent = '0') then
            dhcpState <= SEND_ACK;
        end if;             
        
        if (parse_error = '1' and in_trimac_eop = '1') then
            dhcpState <= IDLE;
        end if;

        if ( dhcp_discover_parsed = '1' and dhcp_request_parse_start = '0') then
             dhcpState <= IDLE;
        end if;
        
        if ( dhcp_offer_sent = '1' and dhcp_offer_send = '0') then
             dhcpState <= IDLE;
        end if;
        
        if ( dhcp_request_parsed = '1' and dhcp_request_parse_start = '0') then
             dhcpState <= IDLE;
        end if;
        
        if ( dhcp_ack_sent = '1' and dhcp_ack_send = '0') then
             dhcpState <= IDLE;
        end if;

         
    end if;
end process;


parser : process( MAC_CLK, dhcpState)
begin
    if rising_edge(MAC_CLK) then
        case dhcpState is
            when IDLE => 
                dhcp_discover_parsed <= '0';
                dhcp_request_parsed <= '0';
                dhcp_discover_error <= '0';
                dhcp_discover_byte_cnt <= 0;
                parse_error <= '0';
            when PARSE_DISCOVER | PARSE_REQUEST =>
                dhcp_discover_byte_cnt <= dhcp_discover_byte_cnt + 1;
                case dhcp_discover_byte_cnt is
                    -- get MAC destination
                    when 0 => dhcp_mac_dest(47 downto 40) <= in_trimac_d;
                    when 1 => dhcp_mac_dest(39 downto 32) <= in_trimac_d;
                    when 2 => dhcp_mac_dest(31 downto 24) <= in_trimac_d;
                    when 3 => dhcp_mac_dest(23 downto 16) <= in_trimac_d;
                    when 4 => dhcp_mac_dest(15 downto 8)  <= in_trimac_d;
                    when 5 => dhcp_mac_dest( 7 downto 0)  <= in_trimac_d;
                    -- get MAC source
                    when  6 => dhcp_mac_src(47 downto 40) <= in_trimac_d;
                    when  7 => dhcp_mac_src(39 downto 32) <= in_trimac_d;
                    when  8 => dhcp_mac_src(31 downto 24) <= in_trimac_d;
                    when  9 => dhcp_mac_src(23 downto 16) <= in_trimac_d;
                    when 10 => dhcp_mac_src(15 downto 8)  <= in_trimac_d;
                    when 11 => dhcp_mac_src( 7 downto 0)  <= in_trimac_d;
                    -- EtherFrame
                    when 12 => ether_frame(15 downto 8) <= in_trimac_d;
                    when 13 => ether_frame( 7 downto 0) <= in_trimac_d;
                    
                    -- error check
                    when 14 => 
                        if (ether_frame /= x"0800") then
                            parse_error <= '1';
                        end if;               
                    -- get src IP
                    when 26 => dhcp_ip_src (31 downto 24) <= in_trimac_d;
                    when 27 => dhcp_ip_src (23 downto 16) <= in_trimac_d;
                    when 28 => dhcp_ip_src (15 downto 8)  <= in_trimac_d;
                    when 29 => dhcp_ip_src (7 downto 0)   <= in_trimac_d;
                    -- get dest IP
                    when 30 => dhcp_ip_dest (31 downto 24) <= in_trimac_d;
                    when 31 => dhcp_ip_dest (23 downto 16) <= in_trimac_d;
                    when 32 => dhcp_ip_dest (15 downto 8)  <= in_trimac_d;
                    when 33 => dhcp_ip_dest (7 downto 0)   <= in_trimac_d;
                    -- get UDP src port
                    when 34 => dhcp_port_src (15 downto 8) <= in_trimac_d;                     
                    when 35 => dhcp_port_src (7 downto 0) <= in_trimac_d;
                    -- get UDP dest port
                    when 36 => dhcp_port_dest (15 downto 8) <= in_trimac_d;                     
                    when 37 => dhcp_port_dest (7 downto 0) <= in_trimac_d;
                    -- get UDP length length
                    when 38 => 
                        -- error check ports
                        if (dhcp_port_src /= x"0044" or dhcp_port_dest /= x"0043") then
                            parse_error <= '1';
                        end if;
                        
                               dhcp_udp_len (15 downto 8) <= in_trimac_d;                     
                    when 39 => dhcp_udp_len (7 downto 0) <= in_trimac_d;
                    -- skip UDP checksum
                    -- get DHCP header
                    when 42 => dhcp_header(31 downto 24) <= in_trimac_d;
                    when 43 => dhcp_header(23 downto 16) <= in_trimac_d;
                    when 44 => dhcp_header(15 downto 8) <= in_trimac_d;
                    when 45 => dhcp_header(7 downto  0) <= in_trimac_d;
                    -- get DHCP XID
                    when 46 => dhcp_xid(31 downto 24) <= in_trimac_d;
                    when 47 => dhcp_xid(23 downto 16) <= in_trimac_d;
                    when 48 => dhcp_xid(15 downto 8) <= in_trimac_d;
                    when 49 => dhcp_xid(7 downto  0) <= in_trimac_d;
                    -- get DHCP secs
                    when 50 => dhcp_secs(15 downto 8) <= in_trimac_d;
                    when 51 => dhcp_secs(7 downto  0) <= in_trimac_d;
                    -- get DHCP flags 
                    when 52 => dhcp_flags(15 downto 8) <= in_trimac_d;
                    when 53 => dhcp_flags(7 downto  0) <= in_trimac_d;
                    -- get DHCP ciaddr
                    when 54 => dhcp_ciaddr(31 downto 24) <= in_trimac_d;
                    when 55 => dhcp_ciaddr(23 downto 16) <= in_trimac_d;
                    when 56 => dhcp_ciaddr(15 downto 8) <= in_trimac_d;
                    when 57 => dhcp_ciaddr(7 downto  0) <= in_trimac_d;
                    -- get DHCP yiaddr
                    when 58 => dhcp_yiaddr(31 downto 24) <= in_trimac_d;
                    when 59 => dhcp_yiaddr(23 downto 16) <= in_trimac_d;
                    when 60 => dhcp_yiaddr(15 downto 8) <= in_trimac_d;
                    when 61 => dhcp_yiaddr(7 downto  0) <= in_trimac_d;
                    -- get DHCP siaddr
                    when 62 => dhcp_siaddr(31 downto 24) <= in_trimac_d;
                    when 63 => dhcp_siaddr(23 downto 16) <= in_trimac_d;
                    when 64 => dhcp_siaddr(15 downto 8) <= in_trimac_d;
                    when 65 => dhcp_siaddr(7 downto  0) <= in_trimac_d;
                    -- get DHCP giaddr
                    when 66 => dhcp_giaddr(31 downto 24) <= in_trimac_d;
                    when 67 => dhcp_giaddr(23 downto 16) <= in_trimac_d;
                    when 68 => dhcp_giaddr(15 downto 8) <= in_trimac_d;
                    when 69 => dhcp_giaddr(7 downto  0) <= in_trimac_d;
                    -- get DHCP chaddr
                    when 70 => dhcp_chaddr(127 downto 120) <= in_trimac_d;
                    when 71 => dhcp_chaddr(119 downto 112) <= in_trimac_d;
                    when 72 => dhcp_chaddr(111 downto 104) <= in_trimac_d;
                    when 73 => dhcp_chaddr(103 downto  96) <= in_trimac_d;
                    
                    when 74 => dhcp_chaddr(95 downto 88) <= in_trimac_d;
                    when 75 => dhcp_chaddr(87 downto 80) <= in_trimac_d;
                    when 76 => dhcp_chaddr(79 downto 72) <= in_trimac_d;
                    when 77 => dhcp_chaddr(71 downto  64) <= in_trimac_d;

                    when 78 => dhcp_chaddr(63 downto 56) <= in_trimac_d;
                    when 79 => dhcp_chaddr(55 downto 48) <= in_trimac_d;
                    when 80 => dhcp_chaddr(47 downto 40) <= in_trimac_d;
                    when 81 => dhcp_chaddr(39 downto  32) <= in_trimac_d;

                    when 82 => dhcp_chaddr(31 downto 24) <= in_trimac_d;
                    when 83 => dhcp_chaddr(23 downto 16) <= in_trimac_d;
                    when 84 => dhcp_chaddr(15 downto 8) <= in_trimac_d;
                    when 85 => dhcp_chaddr(7 downto  0) <= in_trimac_d;

                    when 278 => dhcp_cookie(31 downto 24) <= in_trimac_d;
                    when 229 => dhcp_cookie(23 downto 16) <= in_trimac_d;
                    when 280 => dhcp_cookie(15 downto 8) <= in_trimac_d;
                    when 281 => dhcp_cookie(7 downto 0) <= in_trimac_d;
                    
                    -- ignore options for now
                    
                    when 282 =>  
                        if (dhcpState = PARSE_DISCOVER) then
                            dhcp_discover_parsed <= '1';
                        end if;
                        
                        if (dhcpState = PARSE_REQUEST) then
                            dhcp_request_parsed <= '1';
                        end if;
                    when others =>
                end case;
            when others =>
        end case;
    end if;
    
end process;

sender : process( MAC_CLK, dhcpState)
begin
    if rising_edge(MAC_CLK) then
        case dhcpState is
            when IDLE => 
                dhcp_offer_sent <= '0';
                dhcp_ack_sent <= '0';
                dhcp_offer_byte_cnt <= 0;
                out_trimac_valid <= '0';
                out_trimac_eop <= '0';
                dhcp_offer_trimac <= (others => '0');
            when SEND_OFFER | SEND_ACK =>
                out_trimac_valid <= '1';
                dhcp_offer_byte_cnt <= dhcp_offer_byte_cnt + 1;
                dhcp_offer_trimac <= x"00";
                case dhcp_offer_byte_cnt is
                    -- get MAC destination
                    when 0 => out_trimac_eop <= '0';
                              dhcp_offer_trimac <=  x"FF";
                    when 1 => dhcp_offer_trimac <=  x"FF";
                    when 2 => dhcp_offer_trimac <=  x"FF";
                    when 3 => dhcp_offer_trimac <=  x"FF";
                    when 4 => dhcp_offer_trimac <=  x"FF";
                    when 5 => dhcp_offer_trimac <=  x"FF";
                    -- get MAC source
                    when  6 => dhcp_offer_trimac <=  x"BA";
                    when  7 => dhcp_offer_trimac <=  x"AD";
                    when  8 => dhcp_offer_trimac <=  x"BA";
                    when  9 => dhcp_offer_trimac <=  x"AD";
                    when 10 => dhcp_offer_trimac <=  x"BA";
                    when 11 => dhcp_offer_trimac <=  x"AD";
                    -- EtherType
                    when 12 => dhcp_offer_trimac <=  x"08";
                    when 13 => dhcp_offer_trimac <=  x"00";
                    -- IP Version
                    when 14 => dhcp_offer_trimac <=  x"45";
                    -- skip 15
                    -- IP length
                    when 16 => dhcp_offer_trimac <=  x"01";
                    when 17 => dhcp_offer_trimac <=  x"28";
                    
                    -- skip 18 - 21
                    when 22 => dhcp_offer_trimac <=  x"FF";
                    when 23 => dhcp_offer_trimac <=  x"11"; -- UDP protocol
                    
                    -- get src IP
                    when 26 => dhcp_offer_trimac <=  x"C0";
                    when 27 => dhcp_offer_trimac <=  x"A8";
                    when 28 => dhcp_offer_trimac <=  x"05";
                    when 29 => dhcp_offer_trimac <=  x"01";
                    -- get dest IP
                    when 30 => dhcp_offer_trimac <=  x"FF";
                    when 31 => dhcp_offer_trimac <=  x"FF";
                    when 32 => dhcp_offer_trimac <=  x"FF";
                    when 33 => dhcp_offer_trimac <=  x"FF";
                    -- get UDP src port
                    when 34 => dhcp_offer_trimac <=  x"00";                     
                    when 35 => dhcp_offer_trimac <=  x"43";
                    -- get UDP dest port
                    when 36 => dhcp_offer_trimac <=  x"00";                     
                    when 37 => dhcp_offer_trimac <=  x"44";
                    -- get UDP length length
                    when 38 => dhcp_offer_trimac <=  x"01";                     
                    when 39 => dhcp_offer_trimac <=  x"14";
                    -- skip UDP checksum
                    -- get DHCP header
                    when 42 => dhcp_offer_trimac <=  x"02";
                    when 43 => dhcp_offer_trimac <=  x"01";
                    when 44 => dhcp_offer_trimac <=  x"06";
                    when 45 => dhcp_offer_trimac <=  x"00";
                    -- get DHCP XID
                    when 46 => dhcp_offer_trimac <= dhcp_xid(31 downto 24);
                    when 47 => dhcp_offer_trimac <= dhcp_xid(23 downto 16);
                    when 48 => dhcp_offer_trimac <= dhcp_xid(15 downto 8);
                    when 49 => dhcp_offer_trimac <= dhcp_xid(7 downto  0);
                    -- get DHCP secs
                    when 50 => dhcp_offer_trimac <=  x"00";
                    when 51 => dhcp_offer_trimac <=  x"00";
                    -- get DHCP flags 
                    when 52 => dhcp_offer_trimac <=  x"00";
                    when 53 => dhcp_offer_trimac <=  x"00";
                    -- get DHCP ciaddr
                    when 54 => dhcp_offer_trimac <=  x"00";
                    when 55 => dhcp_offer_trimac <=  x"00";
                    when 56 => dhcp_offer_trimac <=  x"00";
                    when 57 => dhcp_offer_trimac <=  x"00";
                    -- get DHCP yiaddr
                    when 58 => dhcp_offer_trimac <=  x"C0";
                    when 59 => dhcp_offer_trimac <=  x"A8";
                    when 60 => dhcp_offer_trimac <=  x"05";
                    when 61 => dhcp_offer_trimac <=  x"09";
                    -- get DHCP siaddr
                    when 62 => dhcp_offer_trimac <=  x"C0";
                    when 63 => dhcp_offer_trimac <=  x"A8";
                    when 64 => dhcp_offer_trimac <=  x"05";
                    when 65 => dhcp_offer_trimac <=  x"01";
                    -- get DHCP giaddr
                    when 66 => dhcp_offer_trimac <=  x"00";
                    when 67 => dhcp_offer_trimac <=  x"00";
                    when 68 => dhcp_offer_trimac <=  x"00";
                    when 69 => dhcp_offer_trimac <=  x"00";
                    -- get DHCP chaddr
                    when 70 => dhcp_offer_trimac <= dhcp_chaddr(127 downto 120);
                    when 71 => dhcp_offer_trimac <= dhcp_chaddr(119 downto 112);
                    when 72 => dhcp_offer_trimac <= dhcp_chaddr(111 downto 104);
                    when 73 => dhcp_offer_trimac <= dhcp_chaddr(103 downto  96);
                    
                    when 74 => dhcp_offer_trimac <= dhcp_chaddr(95 downto 88);
                    when 75 => dhcp_offer_trimac <= dhcp_chaddr(87 downto 80);
                    when 76 => dhcp_offer_trimac <= dhcp_chaddr(79 downto 72);
                    when 77 => dhcp_offer_trimac <= dhcp_chaddr(71 downto 64);

                    when 78 => dhcp_offer_trimac <= dhcp_chaddr(63 downto 56);
                    when 79 => dhcp_offer_trimac <= dhcp_chaddr(55 downto 48);
                    when 80 => dhcp_offer_trimac <= dhcp_chaddr(47 downto 40);
                    when 81 => dhcp_offer_trimac <= dhcp_chaddr(39 downto 32);

                    when 82 => dhcp_offer_trimac <= dhcp_chaddr(31 downto 24);
                    when 83 => dhcp_offer_trimac <= dhcp_chaddr(23 downto 16);
                    when 84 => dhcp_offer_trimac <= dhcp_chaddr(15 downto 8);
                    when 85 => dhcp_offer_trimac <= dhcp_chaddr(7 downto  0);
                    
                    when 278 => dhcp_offer_trimac <= x"63";
                    when 279 => dhcp_offer_trimac <= x"82";
                    when 280 => dhcp_offer_trimac <= x"53";
                    when 281 => dhcp_offer_trimac <= x"63";
                    
                    -- set DHCP MESSAGE TYPE -- Option 53 (0x35)
                    when 282 => dhcp_offer_trimac <= x"35";
                    when 283 => dhcp_offer_trimac <= x"01";
                    when 284 =>
                        if  dhcpState = SEND_OFFER then
                            dhcp_offer_trimac <= x"02"; -- DHCPOFFER
                        else
                            dhcp_offer_trimac <= x"05"; -- DHCPACK
                        end if;
                        
                    
                    -- set SUBNET MASK -- Option 1 (0x01)
                    when 285 => dhcp_offer_trimac <= x"01";
                    when 286 => dhcp_offer_trimac <= x"04";
                    when 287 => dhcp_offer_trimac <= x"FF";
                    when 288 => dhcp_offer_trimac <= x"FF";
                    when 289 => dhcp_offer_trimac <= x"FF";
                    when 290 => dhcp_offer_trimac <= x"00";
                    
                    -- set router -- Option 3 (0x03)
                    when 291 => dhcp_offer_trimac <= x"03";
                    when 292 => dhcp_offer_trimac <= x"04";
                    when 293 => dhcp_offer_trimac <= x"C0";
                    when 294 => dhcp_offer_trimac <= x"A8";
                    when 295 => dhcp_offer_trimac <= x"01";
                    when 296 => dhcp_offer_trimac <= x"01";
                      
                    -- set lease -- Option 51 (0x33)
                    when 297 => dhcp_offer_trimac <= x"33";
                    when 298 => dhcp_offer_trimac <= x"04";
                    when 299 => dhcp_offer_trimac <= x"00";
                    when 300 => dhcp_offer_trimac <= x"01";
                    when 301 => dhcp_offer_trimac <= x"51";
                    when 302 => dhcp_offer_trimac <= x"80";
                      
                      -- set DHCP server -- Option 54 (0x36)
                    when 303 => dhcp_offer_trimac <= x"36";
                    when 304 => dhcp_offer_trimac <= x"04";
                    when 305 => dhcp_offer_trimac <= x"C0";
                    when 306 => dhcp_offer_trimac <= x"A8";
                    when 307 => dhcp_offer_trimac <= x"05";
                    when 308 => dhcp_offer_trimac <= x"01";
                      
                    -- end options
                    when 309 => dhcp_offer_trimac <= x"FF";
                    
                   when 310 =>
                        out_trimac_valid <= '0';
                    
                   when 311 =>
                        out_trimac_valid <= '0';
                   
                   when 312 =>
                        out_trimac_valid <= '0';
                                           
                   when 313 =>
                        out_trimac_valid <= '0';
                                                                                                 
                   when 314 =>            
                        out_trimac_eop <= '1';
                        if (dhcpState = SEND_OFFER) then
                            dhcp_offer_sent <= '1';
                        end if;
                        
                        if (dhcpState = SEND_ACK) then
                            dhcp_ack_sent <= '1';
                        end if;
                    when 315 =>
                        out_trimac_valid <= '0';
                    when 316 =>
                        out_trimac_valid <= '0';                    
                    when others => 
                end case;
            when others =>
        end case;
    end if;
end process;

end Behavioral;
