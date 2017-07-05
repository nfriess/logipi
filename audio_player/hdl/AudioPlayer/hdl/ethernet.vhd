----------------------------------------------------------------------------------
--
-- State machine to drive ethernet chip.  Implements necessary parts of ethernet
-- protocol, TCP/IP, and DHCP.  Implements a custom autio protocol to communicate
-- with a PC on the local network, storing the received audio data in SDRAM.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet is
    Port (	sys_clk : in  STD_LOGIC;
				sys_reset : in  STD_LOGIC;
				
				
				spi_clk : out STD_LOGIC;
				spi_mosi : out STD_LOGIC;
				spi_miso : in STD_LOGIC;
				spi_cs : out STD_LOGIC;
				eth_int_i : in STD_LOGIC;
				
				
				sdram_cycle : out STD_LOGIC;
				sdram_strobe : out STD_LOGIC;
				sdram_writedata : out STD_LOGIC_VECTOR(31 downto 0);
				sdram_address : out STD_LOGIC_VECTOR(31 downto 0);
				sdram_bitmask : out STD_LOGIC_VECTOR(3 downto 0);
				sdram_ack : in STD_LOGIC;
				
				-- Address where all fragments have been reassembled, so this
				-- is where audio data is available to
				sdram_complete_address : out STD_LOGIC_VECTOR(31 downto 0);
				
				sdram_size_avail : in STD_LOGIC_VECTOR(23 downto 0);
				sdram_empty : in STD_LOGIC;
				
				
				cmd_mute : out STD_LOGIC;
				cmd_pause : out STD_LOGIC;
				cmd_reset_dac : out STD_LOGIC;
				cmd_user_sig : out STD_LOGIC;
				
				volume_left_woofer_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_left_lowmid_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_left_uppermid_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_left_tweeter_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_right_woofer_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_right_lowmid_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_right_uppermid_o : out STD_LOGIC_VECTOR(8 downto 0);
				volume_right_tweeter_o : out STD_LOGIC_VECTOR(8 downto 0);
				
				
				clk16Mwarning : in STD_LOGIC;
				clk16Mwarning_rst : out STD_LOGIC;
				
				
				dbg_state : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_rx_current_packet : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_rx_next_packet : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_rx_next_rxtail : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_pkt_len : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_next_sequence : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_audio_cmd : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_spi_state : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_ip_ident : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_ip_frag_offset : out STD_LOGIC_VECTOR(15 downto 0);
				dbg_spi_readdata : out STD_LOGIC_VECTOR(15 downto 0);
				
				led_o : out STD_LOGIC;
				
				use_dhcp_i : in STD_LOGIC
				
			  );
end ethernet;

architecture Behavioral of ethernet is

	constant IPPROTO_UDP : std_logic_vector(7 downto 0) := X"11";
	
	constant UDP_PORT_DHCPS : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(67, 16));
	constant UDP_PORT_DHCPC : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(68, 16));
	constant UDP_PORT_AUDIO : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(9000, 16));
	constant UDP_PORT_STATUS : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(9001, 16));

	constant CMD_WRITE_ERXRDPT : std_logic_vector(7 downto 0) := X"64";
	constant CMD_READ_ERXDATA : std_logic_vector(7 downto 0) := X"2C";
	
	constant CMD_WRITE_EGPWRPT : std_logic_vector(7 downto 0) := X"6C";
	constant CMD_WRITE_EGPDATA : std_logic_vector(7 downto 0) := X"2A";

	constant CMD_READ_REG_UNBANKED : std_logic_vector(7 downto 0) := X"20";
	constant CMD_WRITE_REG_UNBANKED : std_logic_vector(7 downto 0) := X"22";
	constant CMD_BIT_SET_UNBANKED : std_logic_vector(7 downto 0) := X"24";
	constant CMD_BIT_CLR_UNBANKED : std_logic_vector(7 downto 0) := X"26";

	constant CMD_SETETHRST : std_logic_vector(7 downto 0) := X"CA";
	constant CMD_SETPKTDEC : std_logic_vector(7 downto 0) := X"CC";
	constant CMD_SETTXRTS : std_logic_vector(7 downto 0) := X"D4";
	constant CMD_ENABLERX : std_logic_vector(7 downto 0) := X"E8";
	constant CMD_DISABLERX : std_logic_vector(7 downto 0) := X"EA";
	constant CMD_SETEIE : std_logic_vector(7 downto 0) := X"EC";
	constant CMD_CLREIE : std_logic_vector(7 downto 0) := X"EE";
	
	
	
	constant REG_ETXSTL : std_logic_vector(7 downto 0) := X"00";
	constant REG_ETXSTH : std_logic_vector(7 downto 0) := X"01";
	
	constant REG_ETXLENL : std_logic_vector(7 downto 0) := X"02";
	constant REG_ETXLENH : std_logic_vector(7 downto 0) := X"03";
	
	constant REG_ERXSTL : std_logic_vector(7 downto 0) := X"04";
	constant REG_ERXSTH : std_logic_vector(7 downto 0) := X"05";
	
	constant REG_ERXTAILL : std_logic_vector(7 downto 0) := X"06";
	constant REG_ERXTAILH : std_logic_vector(7 downto 0) := X"07";
	
	constant REG_EUDASTL : std_logic_vector(7 downto 0) := X"16";
	constant REG_EUDASTH : std_logic_vector(7 downto 0) := X"17";
	
	constant REG_ESTATL : std_logic_vector(7 downto 0) := X"1A";
	constant REG_ESTATH : std_logic_vector(7 downto 0) := X"1B";
	
	constant REG_EIRL : std_logic_vector(7 downto 0) := X"1C";
	constant REG_EIRH : std_logic_vector(7 downto 0) := X"1D";
	
	constant REG_ECON1L : std_logic_vector(7 downto 0) := X"1E";
	constant REG_ECON1H : std_logic_vector(7 downto 0) := X"1F";
	
	constant REG_ERXFCONL : std_logic_vector(7 downto 0) := X"34";
	constant REG_ERXFCONH : std_logic_vector(7 downto 0) := X"35";
	
	constant REG_MACON2L : std_logic_vector(7 downto 0) := X"42";
	constant REG_MACON2H : std_logic_vector(7 downto 0) := X"43";
	
	constant REG_MABBIPGL : std_logic_vector(7 downto 0) := X"44";
	constant REG_MABBIPGH : std_logic_vector(7 downto 0) := X"45";
	
	constant REG_MICMDL : std_logic_vector(7 downto 0) := X"52";
	constant REG_MICMDH : std_logic_vector(7 downto 0) := X"53";
	
	constant REG_MIREGADRL : std_logic_vector(7 downto 0) := X"54";
	constant REG_MIREGADRH : std_logic_vector(7 downto 0) := X"55";
	
	constant REG_MAADR3L : std_logic_vector(7 downto 0) := X"60";
	constant REG_MAADR3H : std_logic_vector(7 downto 0) := X"61";
	constant REG_MAADR2L : std_logic_vector(7 downto 0) := X"62";
	constant REG_MAADR2H : std_logic_vector(7 downto 0) := X"63";
	constant REG_MAADR1L : std_logic_vector(7 downto 0) := X"64";
	constant REG_MAADR1H : std_logic_vector(7 downto 0) := X"65";
	
	constant REG_MIRDL : std_logic_vector(7 downto 0) := X"68";
	constant REG_MIRDH : std_logic_vector(7 downto 0) := X"69";
	
	constant REG_MISTATL : std_logic_vector(7 downto 0) := X"6A";
	constant REG_MISTATH : std_logic_vector(7 downto 0) := X"6B";
	
	constant REG_ECON2L : std_logic_vector(7 downto 0) := X"6E";
	constant REG_ECON2H : std_logic_vector(7 downto 0) := X"6F";
	
	constant REG_EIEL : std_logic_vector(7 downto 0) := X"72";
	constant REG_EIEH : std_logic_vector(7 downto 0) := X"73";
	
	constant PREG_PHSTAT1 : std_logic_vector(7 downto 0) := X"01";
	
	constant ARP_REPLY_ADDR : std_logic_vector(15 downto 0) := X"0000";
	-- Leaves 128 bytes for ARP packets
	constant UDP_STATUS_ADDR : std_logic_vector(15 downto 0) := X"0080";
	-- Where the data part of the packet is: (after dst mac, ethertype, iphdr, udp hdr)
	constant UDP_STATUS_DATA_ADDR : std_logic_vector(15 downto 0) := (UDP_STATUS_ADDR + 20 + 8 + 6 + 2);
	-- Leaves 128 bytes for UDP status packets
	constant DHCP_PKT_ADDR : std_logic_vector(15 downto 0) := X"0100";
	
	-- Transmit buffer is 0 to this number, receive is this to 5FFF
	constant RX_BUFFER_ADDR : std_logic_vector(15 downto 0) := X"0800"; -- 2K tx, 22K rx

	-- 8MB (multiply value below by 4 because 32-bit aligned)
	constant SDRAM_BUFFER_SIZE : std_logic_vector(23 downto 0) := X"080000";
	
	type ETHERNET_STATES is (
		
		-- State 0:
		INIT_WR_EUDAST, INIT_RD_EUDAST, INIT_CMP_EUDAST, INIT_READ_CLKRDY,
		INIT_POLL_CLKRDY, INIT_DO_RESET, INIT_RESET_WAIT, INIT_CONFIRM_RESET,
		INIT_CMP_EUDAST_AGAIN, INIT_SET_ERXST, INIT_SET_TXMAC, INIT_GET_MACADDR_1,
		INIT_GET_MACADDR_2, INIT_INTERRUPTS,
		
		INT_DISABLE_INTERRUPTS, INT_READ_INT_REG, INT_CHECK_INTERRUPT,
		INT_ENABLE_INTERRUPTS,
		
		LINK_RD_LINK_STAT, LINK_WR_DUPLEX, LINK_WR_MABBIPG,
		LINK_RXEN, LINK_RXDISABLE, LINK_CLEAR_INTERRUPT,
		
		RX_SET_READ_PTR, RX_READ_NEXT_PTR, RX_READ_RSV_1,
		RX_READ_DST_ADDR_1, RX_READ_DST_ADDR_2_SRC_ADDR_1, RX_READ_SRC_ADDR_2,
		RX_READ_ETHERTYPE, RX_READ_DATA_1,
		
		RX_ARP_READ_TYPE, RX_ARP_READ_LEN_OPER, RX_ARP_READ_SHA_1,
		RX_ARP_READ_SHA_2, RX_ARP_READ_SPA, RX_ARP_READ_THA,
		RX_ARP_READ_TPA, RX_ARP_REPLY_PTR, RX_ARP_REPLY_DST_ADDR_1,
		RX_ARP_REPLY_DST_ADDR_2, RX_ARP_REPLY_ETHERTYPE, RX_ARP_REPLY_HTYPE_PTYPE,
		RX_ARP_REPLY_HPLEN_OPER, RX_ARP_REPLY_SHA_1, RX_ARP_REPLY_SHA_2,
		RX_ARP_REPLY_SPA, RX_ARP_REPLY_THA_1, RX_ARP_REPLY_THA_2, RX_ARP_REPLY_TPA,
		RX_ARP_REPLY_SET_TXST, RX_ARP_REPLY_SET_TXLEN, RX_ARP_REPLY_DO_TXRTS,
		
		RX_IP_HEADER_1, RX_IP_HEADER_2, RX_IP_HEADER_3, RX_IP_SRC_ADDR,
		RX_IP_DEST_ADDR, RX_IP_DEST_ADDR_SAVE, RX_IP_HDR_OPTIONS,
		RX_IP_CHECK_FRAGMENT_PROTO,
		
		RX_UDP_LEN_CHECKSUM, RX_UDP_DATA_1, RX_AUDIO_HDR_1,
		RX_AUDIO_HDR_2, RX_AUDIO_DATA_SAVE, RX_AUDIO_DATA_WAIT_SDRAM,
		RX_AUDIO_DATA_SDRAM_COMPLETE, RX_UDP_RESUME_FRAGMENT,
		RX_UDP_RESUME_FRAGMENT_FROM_REG,
		
		RX_VOLUME_1, RX_VOLUME_2, RX_VOLUME_3, RX_VOLUME_4,
		
		RX_SET_ERXTAIL, RX_DECPKT,
		
		TX_STATUS_PTR, TX_STATUS_DST_ADDR_1, TX_STATUS_DST_ADDR_2,
		TX_STATUS_ETHERTYPE, TX_STATUS_IPHDR_1, TX_STATUS_IPHDR_2,
		TX_STATUS_IPHDR_3, TX_STATUS_IPHDR_4, TX_STATUS_IPHDR_5,
		TX_STATUS_UDPHDR_1, TX_STATUS_UDPHDR_2, TX_STATUS_UDPHDR_3,
		TX_STATUS_SEQUENCE, TX_STATUS_WINDOW, TX_STATUS_STATUS,
		TX_STATUS_SET_TXST, TX_STATUS_SET_TXLEN, TX_STATUS_DO_TXRTS,
		
		IDLE, STARTSPI, WAITACK, WAITCOUNT, ERROR,
		
		DHCP_DISCOVER_PTR, DHCP_DISCOVER_DST_ADDR_1, DHCP_DISCOVER_DST_ADDR_2,
		DHCP_DISCOVER_ETHERTYPE, DHCP_DISCOVER_IPHDR_1, DHCP_DISCOVER_IPHDR_2,
		DHCP_DISCOVER_IPHDR_3, DHCP_DISCOVER_IPHDR_4, DHCP_DISCOVER_IPHDR_5,
		DHCP_DISCOVER_UDPHDR_1, DHCP_DISCOVER_UDPHDR_2, DHCP_DISCOVER_UDPHDR_3,
		DHCP_DISCOVER_DHCP_HDR, DHCP_DISCOVER_DHCP_XID, DHCP_DISCOVER_DHCP_SECS_FLAGS,
		DHCP_DISCOVER_DHCP_CIADDR, DHCP_DISCOVER_DHCP_YIADDR, DHCP_DISCOVER_DHCP_SIADDR,
		DHCP_DISCOVER_DHCP_GIADDR, DHCP_DISCOVER_DHCP_CHADDR_1, DHCP_DISCOVER_DHCP_CHADDR_2,
		DHCP_DISCOVER_DHCP_CHADDR_3, DHCP_DISCOVER_DHCP_CHADDR_4, DHCP_DISCOVER_DHCP_SNAME_FILE,
		DHCP_DISCOVER_DHCP_COOKIE, DHCP_DISCOVER_DHCP_OPT_1, DHCP_DISCOVER_DHCP_OPT_2,
		DHCP_DISCOVER_DHCP_OPT_3, DHCP_DISCOVER_DHCP_OPT_4,
		DHCP_DISCOVER_SET_TXST, DHCP_DISCOVER_SET_TXLEN, DHCP_DISCOVER_DO_TXRTS,
		
		RX_DHCP_HDR, RX_DHCP_XID, RX_DHCP_SECS_FLAGS, RX_DHCP_CIADDR, RX_DHCP_YIADDR,
		RX_DHCP_SIADDR, RX_DHCP_GIADDR, RX_DHCP_CHADDR_1, RX_DHCP_CHADDR_2,
		RX_DHCP_CHADDR_3, RX_DHCP_CHADDR_4, RX_DHCP_SNAME_FILE, RX_DHCP_COOKIE,
		RX_DHCP_OPT_TAG, RX_DHCP_OPT_DATA,
		
		RX_DHCP_SET_ERXTAIL, RX_DHCP_DECPKT, DHCP_INT_ENABLE_INTERRUPTS,
		
		DHCP_REQUEST_PTR, DHCP_REQUEST_DST_ADDR_1, DHCP_REQUEST_DST_ADDR_2,
		DHCP_REQUEST_ETHERTYPE, DHCP_REQUEST_IPHDR_1, DHCP_REQUEST_IPHDR_2,
		DHCP_REQUEST_IPHDR_3, DHCP_REQUEST_IPHDR_4, DHCP_REQUEST_IPHDR_5,
		DHCP_REQUEST_UDPHDR_1, DHCP_REQUEST_UDPHDR_2, DHCP_REQUEST_UDPHDR_3,
		DHCP_REQUEST_DHCP_HDR, DHCP_REQUEST_DHCP_XID, DHCP_REQUEST_DHCP_SECS_FLAGS,
		DHCP_REQUEST_DHCP_CIADDR, DHCP_REQUEST_DHCP_YIADDR, DHCP_REQUEST_DHCP_SIADDR,
		DHCP_REQUEST_DHCP_GIADDR, DHCP_REQUEST_DHCP_CHADDR_1, DHCP_REQUEST_DHCP_CHADDR_2,
		DHCP_REQUEST_DHCP_CHADDR_3, DHCP_REQUEST_DHCP_CHADDR_4, DHCP_REQUEST_DHCP_SNAME_FILE,
		DHCP_REQUEST_DHCP_COOKIE, DHCP_REQUEST_DHCP_OPT_1, DHCP_REQUEST_DHCP_OPT_2,
		DHCP_REQUEST_DHCP_OPT_3, DHCP_REQUEST_DHCP_OPT_4,
		DHCP_REQUEST_SET_TXST, DHCP_REQUEST_SET_TXLEN, DHCP_REQUEST_DO_TXRTS
		
		--DBG_DUMP_PACKET_1, DBG_DUMP_PACKET_2, DBG_DUMP_PACKET_3,
		--DBG_DUMP_PACKET_4, DBG_DUMP_PACKET_5, DBG_DUMP_PACKET_6,
		--DBG_DUMP_PACKET_7, DBG_DUMP_PACKET_8, DBG_DUMP_PACKET_9,
		--DBG_DUMP_PACKET_10, DBG_DUMP_PACKET_11, DBG_DUMP_PACKET_12,
		--DBG_DUMP_PACKET_13,
		
		--DBG_FLAG_1, DBG_FLAG_2, DBG_FLAG_3,
		
		--DBG_DUMP_PACKET_WAIT
		
		);
	
	signal state : ETHERNET_STATES := INIT_WR_EUDAST;
	-- The next state to go to after an SPI operation
	signal next_state : ETHERNET_STATES := IDLE;
	
	signal eth_int_o : std_logic;
	
	-- Signals to SPI master
	signal spi_cycle : STD_LOGIC;
	signal spi_strobe : STD_LOGIC;
	signal spi_writedata : STD_LOGIC_VECTOR(31 downto 0);
	signal spi_readdata : STD_LOGIC_VECTOR(31 downto 0);
	signal spi_datacount : STD_LOGIC_VECTOR(2 downto 0);
	signal spi_ack : STD_LOGIC;
	
	-- Set to '1' to make spi_cycle '0' after SPI operation (used by WAITACK)
	signal spi_auto_disable : std_logic;
	
	-- Set to '1' when in the error state (ERROR)
	signal have_error : std_logic;
	
	-- Will be set to '1' if ethernet using full duplex mode
	signal duplex : std_logic;
	
	-- Will be set to '1' when a link is established
	signal link_status : std_logic;
	
	-- A counter for wait states, and the value to stop counting at (used by WAITCOUNT)
	signal counter : std_logic_vector(23 downto 0);
	signal counter_stop_wait : std_logic_vector(15 downto 0);
	
	-- A counter just to blink the LEDs on error
	signal blink_counter : std_logic_vector(25 downto 0);
	
	-- A counter to transmit a status broadcast packet every 10ms
	signal ten_hz_counter  : std_logic_vector(23 downto 0) := X"000000";
	-- 100mhz is 10ns, so we need to count to 1,000,000 to get 10ms
	constant TEN_HZ_PERIOD : std_logic_vector(23 downto 0) := X"989680";
	
	-- When the SDRAM is empty (the audio system is idle), only transmit every 1s
	signal one_hz_counter  : std_logic_vector(23 downto 0) := X"000000";
	-- At 10ms, count to 100 to get 1s
	constant ONE_HZ_PERIOD : std_logic_vector(7 downto 0) := X"0A";
	
	--Pointer to circular write buffer
	signal sdram_write_ptr : std_logic_vector(23 downto 0) := X"000000";
	signal sdram_complete_ptr : std_logic_vector(23 downto 0) := X"000000";
	signal sdram_writedata_reg : std_logic_vector(31 downto 0);
	
	-- Pointer to SRAM address of receive packet to be processed
	signal rx_current_packet : std_logic_vector(15 downto 0) := RX_BUFFER_ADDR;
	-- Pointer to SRAM address of next packet
	signal rx_next_packet : std_logic_vector(15 downto 0);
	-- Pointer to SRAM address of rxtail after we finish
	signal rx_next_rxtail : std_logic_vector(15 downto 0) := X"5FFE";
	
	-- Our local MAC address
	signal local_macaddr : std_logic_vector(47 downto 0);
	-- Destination address of received packet (either local_mac or broadcast)
	signal dest_macaddr : std_logic_vector(47 downto 0);
	-- Source address of received packet
	signal src_macaddr : std_logic_vector(47 downto 0);
	-- Ethernet packet length, including src_mac, dest_mac, ethertype, padding, and crc
	signal pkt_len : std_logic_vector(15 downto 0);
	
	signal local_ipaddr : std_logic_vector(31 downto 0);
	
	-- IP header length
	signal ip_hdr_len : std_logic_vector(3 downto 0);
	-- IP total length
	signal ip_pkt_len : std_logic_vector(15 downto 0);
	-- IP identification
	signal ip_ident : std_logic_vector(15 downto 0);
	-- IP flag More Fragments
	signal ip_more_fragments : std_logic;
	-- IP current fragment offset
	signal ip_frag_offset : std_logic_vector(12 downto 0);
	-- IP protocol
	signal ip_proto : std_logic_vector(7 downto 0);
	-- Source IP address
	signal ip_src_addr : std_logic_vector(31 downto 0);
	-- Source IP address
	signal ip_dest_addr : std_logic_vector(31 downto 0);
	-- Used to compute header checksum
	signal ip_checksum : std_logic_vector(31 downto 0);
	-- UDP destination port
	signal udp_dest_port : std_logic_vector(15 downto 0);
	-- UDP data length
	signal udp_len : std_logic_vector(15 downto 0);
	
	-- IP next expected fragment offset
	signal ip_next_frag_offset : std_logic_vector(12 downto 0);
	-- IP identification of last fragment
	signal ip_last_ident : std_logic_vector(15 downto 0);
	
	
	-- Data saved from arp packet
	signal arp_sha : std_logic_vector(47 downto 0);
	signal arp_spa : std_logic_vector(31 downto 0);
	signal arp_tpa : std_logic_vector(31 downto 0);
	
	-- Data saved from audio packet
	signal audio_cmd : std_logic_vector(31 downto 0);
	signal audio_sequence : std_logic_vector(31 downto 0);
	signal audio_next_sequence : std_logic_vector(31 downto 0);
	signal audio_tmp_sequence : std_logic_vector(31 downto 0);
	
	
	signal volume_left_woofer : std_logic_vector(8 downto 0);
	signal volume_left_lowmid : std_logic_vector(8 downto 0);
	signal volume_left_uppermid : std_logic_vector(8 downto 0);
	signal volume_left_tweeter : std_logic_vector(8 downto 0);
	signal volume_right_woofer : std_logic_vector(8 downto 0);
	signal volume_right_lowmid : std_logic_vector(8 downto 0);
	signal volume_right_uppermid : std_logic_vector(8 downto 0);
	signal volume_right_tweeter : std_logic_vector(8 downto 0);
	
	
	-- How long to wait for DHCP response (seconds)
	signal dhcp_resp_timeout : std_logic_vector(3 downto 0);
	-- How many retries to send
	signal dhcp_retries_left : std_logic_vector(1 downto 0);
	-- DHCP client IP (our IP if we accept)
	signal dhcp_client_ip : std_logic_vector(31 downto 0);
	-- DHCP server IP (to send responses to)
	signal dhcp_server_ip : std_logic_vector(31 downto 0);
	-- DHCP option type
	signal dhcp_opt_type : std_logic_vector(7 downto 0);
	-- DHCP option length
	signal dhcp_opt_len : std_logic_vector(7 downto 0);
	-- DHCP server ID
	signal dhcp_server_id : std_logic_vector(31 downto 0);
	-- How many seconds before we need to send a renewal request
	signal dhcp_renew_timeout : std_logic_vector(31 downto 0);
	-- How many seconds before we need to send a renewal request
	signal dhcp_renew_left : std_logic_vector(31 downto 0);
	
	type DHCP_STATES is (
		NEED_DISCOVER,
		SENT_DISCOVER,
		HAVE_OFFER,
		SENT_REQUEST,
		HAVE_ACK,
		COMPLETE,
		NEED_RENEW,
		SENT_RENEW
		);
	
	signal dhcp_state : DHCP_STATES := NEED_DISCOVER;
	
	signal sdram_cycle_s : std_logic;
	signal sdram_strobe_s : std_logic;
	signal sdram_write_complete : std_logic;
	
	signal eth_needs_restart : std_logic;
	
	signal len_remaining : std_logic_vector(15 downto 0);
	
	-- Holds audio sample data for samples that cross packet boundary
	signal inter_packet_data_reg : std_logic_vector(15 downto 0);
	signal inter_packet_data_len : std_logic_vector(1 downto 0);
	
	signal ten_hz_int_i : std_logic;
	signal ten_hz_int_o : std_logic;
	signal ten_hz_int_rst : std_logic;
	
	signal dbg_skip_fragment : std_logic_vector(7 downto 0);
	signal dbg_skip_sequence : std_logic_vector(7 downto 0);
	
	--signal dbg_ip_hdr_data : std_logic_vector(255 downto 0);
	
	
	-- Next sample received is the beginning of a frame
	signal start_of_frame : std_logic;
	
	
begin

	led_o <= blink_counter(25) when have_error = '1' else
		'1' when link_status = '1' and dhcp_state = COMPLETE else '0';
	
	cmd_mute <= audio_cmd(0);
	cmd_pause <= audio_cmd(2);
	
	sdram_address <= "000000" & sdram_write_ptr & "00";
	sdram_complete_address <= "000000" & sdram_complete_ptr & "00";
	sdram_bitmask <= "1111";
	sdram_writedata <= sdram_writedata_reg;
	
	sdram_cycle <= sdram_cycle_s;
	sdram_strobe <= sdram_strobe_s;
	
	volume_left_woofer_o <= volume_left_woofer;
	volume_left_lowmid_o <= volume_left_lowmid;
	volume_left_uppermid_o <= volume_left_uppermid;
	volume_left_tweeter_o <= volume_left_tweeter;
	volume_right_woofer_o <= volume_right_woofer;
	volume_right_lowmid_o <= volume_right_lowmid;
	volume_right_uppermid_o <= volume_right_uppermid;
	volume_right_tweeter_o <= volume_right_tweeter;

	
	dbg_rx_current_packet <= rx_current_packet;
	dbg_rx_next_packet <= rx_next_packet;
	dbg_rx_next_rxtail <= rx_next_rxtail;
	dbg_pkt_len <= pkt_len;
	dbg_next_sequence <= audio_next_sequence(15 downto 0);
	dbg_audio_cmd <= dbg_skip_fragment & dbg_skip_sequence;
	
	dbg_ip_ident <= ip_ident;
	dbg_ip_frag_offset <= ip_frag_offset & "000";
	dbg_spi_readdata <= sdram_writedata_reg(23 downto 8);
	
process(sys_clk)
begin
	if rising_edge(sys_clk) then
		blink_counter <= blink_counter + 1;
	end if;
end process;

process(sys_clk,sys_reset)
begin
	if sys_reset = '1' then
		state <= INIT_WR_EUDAST;
		dhcp_state <= NEED_DISCOVER;
		dhcp_retries_left <= (others => '1');
		dhcp_opt_type <= (others => '0');
		dhcp_opt_len <= (others => '0');
		dhcp_renew_left <= (others => '0');
		cmd_reset_dac <= '1';
		spi_cycle <= '0';
		spi_strobe <= '0';
		spi_auto_disable <= '1';
		duplex <= '0';
		link_status <= '0';
		dbg_state <= (others => '0');
		ip_hdr_len <= (others => '0');
		pkt_len <= (others => '0');
		ip_pkt_len <= (others => '0');
		ip_ident <= (others => '0');
		ip_more_fragments <= '0';
		ip_frag_offset <= (others => '0');
		ip_proto <= (others => '0');
		ip_dest_addr <= (others => '0');
		ip_last_ident <= (others => '0');
		ip_next_frag_offset <= (others => '0');
		arp_sha <= (others => '0');
		arp_spa <= (others => '0');
		arp_tpa <= (others => '0');
		counter <= (others => '0');
		have_error <= '0';
		sdram_cycle_s <= '0';
		sdram_strobe_s <= '0';
		sdram_writedata_reg <= (others => '0');
		sdram_write_ptr <= (others => '0');
		sdram_complete_ptr <= (others => '0');
		rx_current_packet <= RX_BUFFER_ADDR;
		rx_next_rxtail <= X"5FFE";
		ten_hz_int_rst <= '0';
		one_hz_counter <= (others => '0');
		audio_cmd <= X"00000005"; -- PAUSE | MUTE
		audio_sequence <= X"00000000";
		audio_next_sequence <= X"00000000";
		audio_tmp_sequence <= X"00000000";
		sdram_write_complete <= '0';
		eth_needs_restart <= '0';
		len_remaining <= (others => '0');
		inter_packet_data_reg <= (others => '0');
		inter_packet_data_len <= (others => '0');
		dbg_skip_fragment <= (others => '0');
		dbg_skip_sequence <= (others => '0');
		--dbg_ip_hdr_data <= (others => '0');
		start_of_frame <= '1';
		cmd_user_sig <= '0';
		clk16Mwarning_rst <= '0';
		volume_left_woofer <= (others => '1');
		volume_left_lowmid <= (others => '1');
		volume_left_uppermid <= (others => '1');
		volume_left_tweeter <= (others => '1');
		volume_right_woofer <= (others => '1');
		volume_right_lowmid <= (others => '1');
		volume_right_uppermid <= (others => '1');
		volume_right_tweeter <= (others => '1');
	elsif rising_edge(sys_clk) then
	
		ten_hz_int_rst <= '0';
		cmd_reset_dac <= '0';
		clk16Mwarning_rst <= '0';
		
		case state is
		
			when INIT_WR_EUDAST =>
				-- Page 77, Reset sequence
				-- Step 1: Write 1234h to EUDAST
				
				dbg_state <= X"0001";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_EUDASTL & X"34" & X"12";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= INIT_RD_EUDAST;
				state <= STARTSPI;
								
			when INIT_RD_EUDAST =>
				-- Step 2: Read EUDAST and see if it is still 1234h
				
				dbg_state <= X"0002";
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_EUDASTL & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= INIT_CMP_EUDAST;
				state <= STARTSPI;
				
			when INIT_CMP_EUDAST =>

				dbg_state <= X"0003";
				--dbg_state <= spi_readdata(15 downto 0);
				
				if spi_readdata(15 downto 0) = X"3412" then
					counter <= (others => '0');
					state <= INIT_READ_CLKRDY;
				else
					state <= ERROR;
				end if;
				
			when INIT_READ_CLKRDY =>
				-- Step 3: Poll CLKRDY and wait for it to become set
			
				dbg_state <= X"0004";
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_ESTATH & X"00" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= INIT_POLL_CLKRDY;
				state <= STARTSPI;
				
			when INIT_POLL_CLKRDY =>
			
				dbg_state <= X"0005";
				
				counter <= counter + 1;
				
				if spi_readdata(4) = '1' then
					state <= INIT_DO_RESET;
				else
				
					if counter = X"00FF" then
						state <= ERROR;
					else
						state <= INIT_READ_CLKRDY;
					end if;
					
				end if;
				
			when INIT_DO_RESET =>
				-- Step 4: Issue System Reset by setting ETHRST (ECON2<4>)
				
				dbg_state <= X"0005";
				
				spi_writedata <= CMD_SETETHRST & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= INIT_RESET_WAIT;
				state <= STARTSPI;
				
			when INIT_RESET_WAIT =>
				-- Step 5: Wait at least 25 us for Reset to take place
				
				dbg_state <= X"0006";
				
				-- With a 10ns clock need 2,500 = 9C4, but we round up a bit
				counter <= (others => '0');
				counter_stop_wait <= X"09CF";
				next_state <= INIT_CONFIRM_RESET;
				state <= WAITCOUNT;
				
			when INIT_CONFIRM_RESET =>
				-- Step 6: Read EUDAST to confirm System Reset, should be 0000h
				
				dbg_state <= X"0007";
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_EUDASTL & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= INIT_CMP_EUDAST_AGAIN;
				state <= STARTSPI;
				
			when INIT_CMP_EUDAST_AGAIN =>

				dbg_state <= X"0008";
				
				if spi_readdata(15 downto 0) = X"0000" then
					-- Step 7: Wait at least 256us for PHY registers and PHY status bits to become available
					
					-- With a 10ns clock need 25,600 = 6400, but we round up a bit
					counter <= (others => '0');
					counter_stop_wait <= X"64FF";
					next_state <= INIT_SET_ERXST;
					state <= WAITCOUNT;
					
				else
					state <= ERROR;
				end if;
				
			when INIT_SET_ERXST =>
				-- Page 77, 8.3: Load ERXST register to setup receive buffer memory
				
				dbg_state <= X"0009";
				
				-- Also set current packet pointer to start reading from the same address
				rx_current_packet <= RX_BUFFER_ADDR;
				rx_next_rxtail <= X"5FFE";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ERXSTL & RX_BUFFER_ADDR(7 downto 0) & RX_BUFFER_ADDR(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= INIT_SET_TXMAC;
				state <= STARTSPI;
				
				
			-- ERXTAIL is set to 5FFE by default, which should be okay
				
				
			-- Page 78, 8.7, need to write 0x05E1 to PHANA register.  Default value
			-- is okay, but doesn't advertise any flow control.

			-- If we do this, do we need to enable flow control? (AUTOFC) See 11.2.2
			
			
			
				
			-- Since we need to wait for auto negotiation to complete, now is a good time to
			-- do any other preparation work...
			
			when INIT_SET_TXMAC =>
				-- Automatically insert source MAC address into packets
				
				dbg_state <= X"000A";
				
				spi_writedata <= CMD_BIT_SET_UNBANKED & REG_ECON2H & X"20" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= INIT_GET_MACADDR_1;
				state <= STARTSPI;
				
			when INIT_GET_MACADDR_1 =>
				-- Read MAC address from the device for use later
				
				dbg_state <= X"000B";
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_MAADR3L & X"00" & X"00";
				spi_datacount <= "110";
				spi_auto_disable <= '0';
				
				next_state <= INIT_GET_MACADDR_2;
				state <= STARTSPI;
				
			when INIT_GET_MACADDR_2 =>
				
				dbg_state <= X"000C";
				
				local_macaddr(31 downto 0) <= spi_readdata(15 downto 0) & spi_readdata(31 downto 16);
					
				spi_datacount <= "010";
				spi_auto_disable <= '1';
				
				next_state <= INIT_INTERRUPTS;
				state <= STARTSPI;
				
				
			-- Page 77, 8.5: Set up receive filters, see page 97
			-- Default is 59, 00: CRCEN, RUNTEN, UCEN, BCEN
			-- This is what we want already, so we skip this step
			
			-- 12.2: Auto-negotiation is set by default
			
			
			when INIT_INTERRUPTS =>
				-- Enable interrupts
				
				dbg_state <= X"002A";
				
				-- Continued from INIT_GET_MACADDR_2, save result
				local_macaddr(47 downto 32) <= spi_readdata(15 downto 0);
				
				spi_writedata <= CMD_BIT_SET_UNBANKED & REG_EIEL & X"40" & X"88";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= IDLE;
				state <= STARTSPI;
				
				-- NOTE: EIR register sets LINKF flag by default, which means
				-- that an interrupt will fire immediately after this command
				
				
				
				
				
				
			when IDLE =>
			
				--dbg_state(15) <= '1';
			
				state <= IDLE;
				
				if eth_int_o = '0' then
				
					--dbg_state(15) <= '0';
					
					state <= INT_DISABLE_INTERRUPTS;
					
				elsif link_status = '1' and ten_hz_int_o = '1' then
					
					ten_hz_int_rst <= '1';
					
					one_hz_counter <= one_hz_counter + 1;
					
					if one_hz_counter = (ONE_HZ_PERIOD-1) then
						
						one_hz_counter <= (others => '0');
						
						if dhcp_renew_left /= X"00000000" then
							dhcp_renew_left <= dhcp_renew_left - 1;
						end if;
						
						if dhcp_state = NEED_DISCOVER then
							
							state <= DHCP_DISCOVER_PTR;
							dhcp_retries_left <= (others => '1');
							
						elsif dhcp_state = SENT_DISCOVER or dhcp_state = SENT_REQUEST or dhcp_state = SENT_RENEW then
							
							dhcp_resp_timeout <= dhcp_resp_timeout + 1;
							if dhcp_resp_timeout = X"F" then
								if dhcp_retries_left = 0 then
									
									-- Abort DHCP and use 169.254/16 address
									dhcp_state <= COMPLETE;
									dhcp_renew_left <= (others => '0');
									dhcp_renew_timeout <= (others => '0');
									
									local_ipaddr(31 downto 16) <= X"A9FE";
									
									local_ipaddr(7 downto 0) <= local_macaddr(39 downto 32) xor local_macaddr(15 downto 8) xor local_macaddr(31 downto 24);
									
									if (local_macaddr(47 downto 40) xor local_macaddr(23 downto 16) xor local_macaddr(7 downto 0))
										= X"0000" then
											
											local_ipaddr(15 downto 8) <= X"01";
											
									elsif (local_macaddr(47 downto 40) xor local_macaddr(23 downto 16) xor local_macaddr(7 downto 0))
										= X"FFFF" then
											
											local_ipaddr(15 downto 8) <= X"FE";
											
									else
											
											local_ipaddr(15 downto 8) <= (local_macaddr(47 downto 40) xor local_macaddr(23 downto 16) xor local_macaddr(7 downto 0));
											
									end if;
									
								else
									dhcp_retries_left <= dhcp_retries_left - 1;
									if dhcp_state = SENT_DISCOVER then
										state <= DHCP_DISCOVER_PTR;
									else -- SENT_REQUEST or SENT_RENEW
										state <= DHCP_REQUEST_PTR;
									end if;
								end if;
							end if;
							
						elsif dhcp_state = COMPLETE then
						
							if dhcp_renew_timeout /= X"00000000" and dhcp_renew_left = X"00000000" then
								
								state <= DHCP_REQUEST_PTR;
								dhcp_state <= NEED_RENEW;
								dhcp_retries_left <= (others => '1');
								
							else
								
								-- Sends status updates at 1hz when sdram is empty, but
								-- also serves for the else case below when sdram is full
								-- and we hit ONE_HZ_PERIOD
								state <= TX_STATUS_PTR;
								
							end if;
							
						end if;
						
					elsif dhcp_state = COMPLETE and sdram_empty = '0' then
						-- Sends status updates at 10hz while streaming audio
						state <= TX_STATUS_PTR;
					end if;
					
				end if;
			
				
-------------------------------------------------------------------
-- Interrupt service routine
-------------------------------------------------------------------
				
			when INT_DISABLE_INTERRUPTS =>
				-- Disable interrupts while we are handling one
				
				spi_writedata <= CMD_CLREIE & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= INT_READ_INT_REG;
				state <= STARTSPI;
				
				
			when INT_READ_INT_REG =>
				-- Read interrupt flags register
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_EIRL & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= INT_CHECK_INTERRUPT;
				state <= STARTSPI;
				
			when INT_CHECK_INTERRUPT =>
				-- Decide which interrupt to service
				
				-- Register is little endian
				if spi_readdata(3) = '1' then
					--ten_hz_int_rst <= '1';
					state <= LINK_RD_LINK_STAT;
				elsif spi_readdata(14) = '1' then
					state <= RX_SET_READ_PTR;
				else
					state <= ERROR;
				end if;
				
			when INT_ENABLE_INTERRUPTS =>
				-- Enable interrupts now that handling is complete
				
				--dbg_state(12) <= '1';
				
				spi_writedata <= CMD_SETEIE & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= IDLE;
				state <= STARTSPI;
				
				
-------------------------------------------------------------------
-- Link status changed interrupt
-------------------------------------------------------------------
				
			when LINK_RD_LINK_STAT =>
				-- Read ethernet status register to check PHYLNK
				
				dbg_state <= X"0A01";
				
				spi_writedata <= CMD_READ_REG_UNBANKED & REG_ESTATH & X"00" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= LINK_WR_DUPLEX;
				state <= STARTSPI;
				
			when LINK_WR_DUPLEX =>
				-- Check PHYLNK, set FULDPX (MACON2<0>) to match PHYDPX (ESTAT<10>)
				
				dbg_state <= X"0A02";
				
				-- Check PHYLNK, little endian, so bit 8 is 0
				if spi_readdata(0) = '0' or spi_readdata(6) = '0' then
					link_status <= '0';
					state <= LINK_RXDISABLE;
				else
					
					link_status <= '1';
					
					-- Reset DHCP status
					if use_dhcp_i = '1' then
						dhcp_state <= NEED_DISCOVER;
						dhcp_retries_left <= (others => '1');
						dhcp_renew_left <= (others => '0');
					else
						-- Skip straight to chosing a link-local address
						dhcp_state <= SENT_DISCOVER;
						dhcp_resp_timeout <= X"F";
						dhcp_retries_left <= (others => '0');
						dhcp_renew_left <= (others => '0');
					end if;
					
					duplex <= spi_readdata(2);
					
					spi_datacount <= "011";
					spi_auto_disable <= '1';
					
					if spi_readdata(2) = '1' then
						spi_writedata <= CMD_BIT_SET_UNBANKED & REG_MACON2L & X"01" & X"00";
					else
						spi_writedata <= CMD_BIT_CLR_UNBANKED & REG_MACON2L & X"01" & X"00";
					end if;
					
					next_state <= LINK_WR_MABBIPG;
					state <= STARTSPI;
					
				end if;
				
			when LINK_WR_MABBIPG =>
				-- Set MABBIPG to 12h for half duplex or 15h for full
				
				dbg_state <= X"0A03";
				
				if duplex = '1' then
					spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_MABBIPGL & X"15" & X"00";
				else
					spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_MABBIPGL & X"12" & X"00";
				end if;
				
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= LINK_RXEN;
				state <= STARTSPI;
				
			when LINK_RXEN =>
				-- Enable receive packets
				
				dbg_state <= X"0A04";
				
				spi_writedata <= CMD_ENABLERX & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= LINK_CLEAR_INTERRUPT;
				state <= STARTSPI;
				
			when LINK_RXDISABLE =>
				-- Disable receive packets
				
				dbg_state <= X"0A05";
				
				spi_writedata <= CMD_DISABLERX & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= LINK_CLEAR_INTERRUPT;
				state <= STARTSPI;
				
			when LINK_CLEAR_INTERRUPT =>
				-- Clear interrupt flag
				
				--dbg_state <= X"0A06";
				
				spi_writedata <= CMD_BIT_CLR_UNBANKED & REG_EIRH & X"08" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= INT_ENABLE_INTERRUPTS;
				state <= STARTSPI;
				
				
				
				
				
				
				
-------------------------------------------------------------------
-- Packet received interrupt
-------------------------------------------------------------------
			
-- Not used.  At one point there seemed to be extra interrupts and
-- this would prevent reading data when there was none.
			
			when RX_SET_READ_PTR =>
				
				dbg_state <= X"00CF";
				
				-- Set RX pointer to next packet address
				
				spi_writedata <= CMD_WRITE_ERXRDPT & rx_current_packet(7 downto 0) & rx_current_packet(15 downto 8) & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= RX_READ_NEXT_PTR;
				state <= STARTSPI;
				
			when RX_READ_NEXT_PTR =>
				-- Page 89: Read at rx_current_packet and pkt_len
				
				dbg_state <= X"00C2";
				
				spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
				spi_datacount <= "101";
				spi_auto_disable <= '0';
				
				next_state <= RX_READ_RSV_1;
				state <= STARTSPI;
				
			when RX_READ_RSV_1 =>
				-- Save rx_current_packet and pkt_len
				
				dbg_state <= X"00C3";
				
				rx_next_packet <= spi_readdata(23 downto 16) & spi_readdata(31 downto 24);
				
				pkt_len <= spi_readdata(7 downto 0) & spi_readdata(15 downto 8);
				
				-- Store rxtail now so we can use it later
				if (spi_readdata(23 downto 16) & spi_readdata(31 downto 24)) = RX_BUFFER_ADDR then
					rx_next_rxtail <= X"5FFE"; -- end of SRAM
				else
					rx_next_rxtail <= (spi_readdata(23 downto 16) & spi_readdata(31 downto 24)) - 2;
				end if;
				
				-- Sanity check
				if spi_readdata(23 downto 16) & spi_readdata(31 downto 24) < RX_BUFFER_ADDR then
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= ERROR;
				else
					
					-- Read 4 bytes of status vector
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_READ_DST_ADDR_1;
					state <= STARTSPI;
					
				end if;
				
			when RX_READ_DST_ADDR_1 =>
				-- Ignore rest of status vector
				
				dbg_state <= X"00C5";
				
				-- Read 4 bytes of dest addr
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_READ_DST_ADDR_2_SRC_ADDR_1;
				state <= STARTSPI;
				
			when RX_READ_DST_ADDR_2_SRC_ADDR_1 =>
				-- Save dest addr
				
				dbg_state <= X"00C6";
				
				dest_macaddr(47 downto 16) <= spi_readdata;
				
				-- Read 2 bytes of dest addr, 2 bytes of src addr
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_READ_SRC_ADDR_2;
				state <= STARTSPI;
				
			when RX_READ_SRC_ADDR_2 =>
				-- Save src addr
				
				dbg_state <= X"00C8";
				
				dest_macaddr(15 downto 0) <= spi_readdata(31 downto 16);
				
				src_macaddr(47 downto 32) <= spi_readdata(15 downto 0);
				
				-- Read 4 bytes of src addr
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_READ_ETHERTYPE;
				state <= STARTSPI;
				
			when RX_READ_ETHERTYPE =>
				-- Save src addr
				
				dbg_state <= X"00C9";
				
				src_macaddr(31 downto 0) <= spi_readdata;
				
				-- Read 2 bytes of ether type
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '1';
				
				next_state <= RX_READ_DATA_1;
				state <= STARTSPI;

			when RX_READ_DATA_1 =>
				-- Check ethertype
				
				dbg_state <= X"00CA";
				
				if spi_readdata(15 downto 0) = X"0800" then
					-- IPv4
					state <= RX_IP_HEADER_1;
				elsif spi_readdata(15 downto 0) = X"0806" then
					-- ARP
					state <= RX_ARP_READ_TYPE;
				else
					state <= RX_SET_ERXTAIL;
				end if;
			
			
			
			
				
			when RX_ARP_READ_TYPE =>
				-- Check packet length
				
				dbg_state <= X"0100";
				
				if pkt_len < (6 + 6 + 2 + 28) then
					state <= RX_SET_ERXTAIL;
				else
					-- Read 2 bytes of HTYPE and 2 bytes of PTYPE
					
					spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
					spi_datacount <= "101";
					spi_auto_disable <= '0';
					
					next_state <= RX_ARP_READ_LEN_OPER;
					state <= STARTSPI;
				end if;
				
			when RX_ARP_READ_LEN_OPER =>
				-- Check htype and ptype
				
				dbg_state <= X"0101";
				
				if spi_readdata = X"00010800" then
					-- Read 4 bytes of hlen, plen, and oper
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_ARP_READ_SHA_1;
					state <= STARTSPI;
					
				else
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				end if;
				
				dbg_state <= X"0102";
				
			when RX_ARP_READ_SHA_1 =>
				-- Check hlen, plen, and oper
				
				-- Must be 6 (MAC), 4 (IPv4) and OPER=request
				if spi_readdata = X"06040001" then
					
					-- Read 4 bytes of sender hardware address
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_ARP_READ_SHA_2;
					state <= STARTSPI;
					
				else
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				end if;
				
			when RX_ARP_READ_SHA_2 =>
				-- Save 4 bytes of sender hardware address
				
				dbg_state <= X"0103";
				
				arp_sha(47 downto 16) <= spi_readdata;
				
				-- Read 2 bytes of sender hardware address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_READ_SPA;
				state <= STARTSPI;
				
			when RX_ARP_READ_SPA =>
				-- Save 2 bytes of sender hardware address
				
				dbg_state <= X"0104";
				
				arp_sha(15 downto 0) <= spi_readdata(15 downto 0);
				
				-- Read 4 bytes of sender protocol address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_READ_THA;
				state <= STARTSPI;
				
			when RX_ARP_READ_THA =>
				-- Save sender protocol address
				
				dbg_state <= X"0105";
				
				arp_spa <= spi_readdata;
				
				-- Read 6 bytes of target hardware address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "110";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_READ_TPA;
				state <= STARTSPI;
				
			when RX_ARP_READ_TPA =>
				-- Ignore target hardware address
				
				dbg_state <= X"0106";
				
				-- Read 4 bytes of target protocol address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_ARP_REPLY_PTR;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_PTR =>
				-- Save target protocol address
				
				dbg_state <= X"0107";
				
				arp_tpa <= spi_readdata;
				
				-- Sender is looking for us
				if spi_readdata = local_ipaddr then
					
					-- Set write ptr
					
					spi_writedata <= CMD_WRITE_EGPWRPT & ARP_REPLY_ADDR(7 downto 0) & ARP_REPLY_ADDR(15 downto 8) & X"00";
					spi_datacount <= "011";
					spi_auto_disable <= '1';
					
					next_state <= RX_ARP_REPLY_DST_ADDR_1;
					state <= STARTSPI;
					
				else
					state <= RX_SET_ERXTAIL;
				end if;
				
				
			when RX_ARP_REPLY_DST_ADDR_1 =>
				-- Write 3 bytes of dest mac addr
				
				dbg_state <= X"0108";
				
				spi_writedata <= CMD_WRITE_EGPDATA & src_macaddr(47 downto 24);
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_DST_ADDR_2;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_DST_ADDR_2 =>
				-- Write 3 bytes of dest mac addr
				
				dbg_state <= X"0109";
				
				spi_writedata <= src_macaddr(23 downto 0) & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_ETHERTYPE;
				state <= STARTSPI;

			when RX_ARP_REPLY_ETHERTYPE =>
				-- Write ethertype
				
				dbg_state <= X"010A";
				
				spi_writedata <= X"0806" & X"00" & X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_HTYPE_PTYPE;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_HTYPE_PTYPE =>
				-- Write HTYPE and PTYPE
				
				dbg_state <= X"010B";
				
				spi_writedata <= X"0001" & X"0800";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_HPLEN_OPER;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_HPLEN_OPER =>
				-- Write HLEN, PLEN and OPER
				
				dbg_state <= X"010D";
				
				spi_writedata <= X"0604" & X"0002";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_SHA_1;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_SHA_1 =>
				-- Write 4 bytes of sender hardware address
				
				dbg_state <= X"010F";
				
				spi_writedata <= local_macaddr(47 downto 16);
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_SHA_2;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_SHA_2 =>
				-- Write 2 bytes of sender hardware address
				
				dbg_state <= X"0110";
				
				spi_writedata <= local_macaddr(15 downto 0) & X"00" & X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_SPA;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_SPA =>
				-- Write sender protocol address
				
				dbg_state <= X"0111";
				
				spi_writedata <= local_ipaddr;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_THA_1;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_THA_1 =>
				-- Write 4 bytes of target hardware address
				
				dbg_state <= X"0114";
				
				spi_writedata <= arp_sha(47 downto 16);
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_THA_2;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_THA_2 =>
				-- Write 3 bytes of target hardware address
				
				dbg_state <= X"0115";
				
				spi_writedata <= arp_sha(15 downto 0) & X"00" & X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= RX_ARP_REPLY_TPA;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_TPA =>
				-- Write target protocol address
				
				dbg_state <= X"0116";
				
				spi_writedata <= arp_spa;
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_ARP_REPLY_SET_TXST;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_SET_TXST =>
				-- Set TXST to start address of packet
				
				dbg_state <= X"0119";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXSTL & ARP_REPLY_ADDR(7 downto 0) & ARP_REPLY_ADDR(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_ARP_REPLY_SET_TXLEN;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_SET_TXLEN =>
				-- Set TXLEN to length of packet
				
				dbg_state <= X"011A";
				
				-- ARP packet is 28 bytes, plus 2 ethertype, plus 6 dest MAC addr
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXLENL & X"24" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_ARP_REPLY_DO_TXRTS;
				state <= STARTSPI;
				
			when RX_ARP_REPLY_DO_TXRTS =>
				-- Set TXRTS bit to start transmitting
				
				dbg_state <= X"011B";
				
				spi_writedata <= CMD_SETTXRTS & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				-- Done with packet
				next_state <= RX_SET_ERXTAIL;
				state <= STARTSPI;

				
				
				
				
				
				
			when RX_IP_HEADER_1 =>
				-- Check packet length
				
				dbg_state <= X"0201";
				
				if pkt_len < (6 + 6 + 2 + 20) then
					state <= RX_SET_ERXTAIL;
				else
					-- Read 4 bytes of Version, header len, DSCP, ECN, and total length
					
					spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
					spi_datacount <= "101";
					spi_auto_disable <= '0';
					
					next_state <= RX_IP_HEADER_2;
					state <= STARTSPI;
				end if;
				
				
			when RX_IP_HEADER_2 =>
				-- Check version, header len, and total len
				
				dbg_state <= X"0202";
				
				ip_checksum <= (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				ip_hdr_len <= spi_readdata(27 downto 24);
				ip_pkt_len <= spi_readdata(15 downto 0);
				
				-- IP version must be 4
				-- ethernet pkt_len must be >= ip_pkt_len + ethernet headers
				-- ip_hdr_len*4 must be <= ip_pkt_len
				if spi_readdata(31 downto 28) /= X"4" or ((spi_readdata(15 downto 0) + 6 + 6 + 2) > pkt_len)
						or ((spi_readdata(27 downto 24) & "00") > spi_readdata(15 downto 0)) then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes of identification (x2), flags, frag offset
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_IP_HEADER_3;
					state <= STARTSPI;
					
				end if;
				
			when RX_IP_HEADER_3 =>
				-- Check ident, fragment bits
				
				dbg_state <= X"0203";
				
				ip_checksum <= ip_checksum + (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				-- Save ident to compare other fragments later
				ip_ident <= spi_readdata(31 downto 16);
				
				-- Save fragment offset
				ip_frag_offset <= spi_readdata(12 downto 0);
				
				-- Save More Fragments flag for later
				ip_more_fragments <= spi_readdata(13);
				
				-- Read 4 bytes of TTL, Protocol, Header checksum
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_IP_SRC_ADDR;
				state <= STARTSPI;
				
			when RX_IP_SRC_ADDR =>
				-- Save Protocol, include checksum in calculation
				
				dbg_state <= X"0204";
				
				ip_checksum <= ip_checksum + (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				ip_proto <= spi_readdata(23 downto 16);
				
				-- Read source IP address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_IP_DEST_ADDR;
				state <= STARTSPI;
				
			when RX_IP_DEST_ADDR =>
				-- Save source IP address
				
				dbg_state <= X"0205";
				
				ip_checksum <= ip_checksum + (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				ip_src_addr <= spi_readdata;
				
				-- Read destination IP address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_IP_DEST_ADDR_SAVE;
				state <= STARTSPI;
				
			when RX_IP_DEST_ADDR_SAVE =>
				-- Save destination IP address
				
				dbg_state <= X"0206";
				
				ip_checksum <= ip_checksum + (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				ip_dest_addr <= spi_readdata;
				
				if spi_readdata /= local_ipaddr and spi_readdata /= X"FFFFFFFF" then
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				elsif ip_hdr_len /= "0101" then -- Min size of IP hdr is 5*4 bytes
					
					-- Size of IP options
					len_remaining <= "000000000000" & (ip_hdr_len - 5);
				
					state <= RX_IP_HDR_OPTIONS;
				else
					state <= RX_IP_CHECK_FRAGMENT_PROTO;
				end if;
				
			when RX_IP_HDR_OPTIONS =>
				-- Skip header options
				
				dbg_state <= X"0207";
				
				ip_checksum <= ip_checksum + (X"0000" & spi_readdata(31 downto 16)) + (X"0000" & spi_readdata(15 downto 0));
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				if len_remaining /= X"0000" then
					len_remaining <= len_remaining - 1;
					next_state <= RX_IP_HDR_OPTIONS;
				else
					next_state <= RX_IP_CHECK_FRAGMENT_PROTO;
				end if;
				
				state <= STARTSPI;
				
				-- TODO: Figure out if this triggering at all
				spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
				pkt_len <= X"000" & ip_hdr_len;
				state <= ERROR;
			
			when RX_IP_CHECK_FRAGMENT_PROTO =>
				-- Now check that fragment matches expected ident, position, etc
				
				dbg_state <= X"0208";
				
				if (ip_checksum(31 downto 16) + ip_checksum(15 downto 0)) /= X"FFFF" then
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					--state <= RX_SET_ERXTAIL;
					dbg_state <= (ip_checksum(31 downto 16) + ip_checksum(15 downto 0));
					state <= ERROR;
				elsif ip_proto = IPPROTO_UDP then
					
					if ip_frag_offset = "0000000000000" then
						
						-- Continue to check port numbers before deciding what to do
						spi_writedata <= X"00" & X"00" & X"00" & X"00";
						spi_datacount <= "100";
						spi_auto_disable <= '1';
						
						next_state <= RX_UDP_LEN_CHECKSUM;
						state <= STARTSPI;
						
					elsif ip_frag_offset = ip_next_frag_offset and ip_ident = ip_last_ident then
						
						-- Save next expected offset for later
						-- next_offset = offset + (ip_pkt_len/8) - (ip_hdr_len/2)
						ip_next_frag_offset <= ip_frag_offset + ip_pkt_len(15 downto 3) - ip_hdr_len(3 downto 1);
						
						state <= RX_UDP_RESUME_FRAGMENT;
						
					else
						spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
						state <= RX_SET_ERXTAIL;
						--state <= DBG_FLAG_1;
					end if;
					
				else
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				end if;
			
			when RX_UDP_LEN_CHECKSUM =>
				
				dbg_state <= X"0302";
				
				udp_dest_port <= spi_readdata(15 downto 0);
				
				-- Read length and checksum
				
				spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
				spi_datacount <= "101";
				spi_auto_disable <= '1';
				
				next_state <= RX_UDP_DATA_1;
				state <= STARTSPI;
			
			when RX_UDP_DATA_1 =>
				-- Save length and ignore checksum
				
				dbg_state <= X"0303";
				
				-- If another fragment was in progress, then back the write pointer
				-- up to last complete packet
				sdram_write_ptr <= sdram_complete_ptr;
				audio_tmp_sequence <= audio_next_sequence;
				
				ip_last_ident <= ip_ident;
				
				-- Save next expected offset for later
				-- next_offset = offset + (ip_pkt_len/8) - (ip_hdr_len/2)
				ip_next_frag_offset <= ip_frag_offset + ip_pkt_len(15 downto 3) - ip_hdr_len(3 downto 1);
				
				-- Save UDP length - 8 byte UDP header
				udp_len <= spi_readdata(31 downto 16) - 8;
				
				-- Amount of data in this fragment, taking off IP and UDP header length
				len_remaining <= ip_pkt_len - (ip_hdr_len & "00") - 8;
				
				-- UDP data must be a multiple of 6 bytes (2*24 bit samples)
				-- Note that we don't check udp_len because it might be split across
				-- multiple IP fragments
				-- TODO: How to check this in VHDL?
				--if spi_readdata(17 downto 16) /= "00" then
				--	ip_next_frag_offset <= (others => '0'); -- Force next fragment to be 0
				--	spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
				--	state <= RX_SET_ERXTAIL;
				--else
					
				if udp_dest_port = UDP_PORT_AUDIO then
					
					-- Read 4 bytes for command
					
					spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
					spi_datacount <= "101";
					--spi_writedata <= X"00" & X"00" & X"00" & X"00";
					--spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_AUDIO_HDR_1;
					state <= STARTSPI;
					
				elsif udp_dest_port = UDP_PORT_DHCPC then
					
					-- Read 4 bytes for DHCP data
					
					spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
					spi_datacount <= "101";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_HDR;
					state <= STARTSPI;
					
				else
					ip_next_frag_offset <= (others => '0'); -- Force next fragment to be 0
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				end if;
				
				
			when RX_AUDIO_HDR_1 =>
				-- Save command
				
				dbg_state <= X"0304";
				
				-- TODO: Reset entire system?
				
				-- data(31) => '1' means no audio samples
				-- data(8) => '1' means reset dac controller (sdram buffer is ignored)
				-- data(1) => '1' means a new data stream, so reset seq
				-- data(0) => '1' means mute on, '0' means mute off
				
				audio_cmd <= spi_readdata;
				
				start_of_frame <= start_of_frame or spi_readdata(1);
				
				-- 4 bytes for command
				len_remaining <= len_remaining - 4;
				
				-- Read 4 bytes for sequence
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_AUDIO_HDR_2;
				state <= STARTSPI;
				
			when RX_AUDIO_HDR_2 =>
				-- Save sequence number
				
				dbg_state <= X"0305";
					
				audio_sequence <= spi_readdata;
				
				-- 4 bytes for sequence
				len_remaining <= len_remaining - 4;
				
				if audio_cmd(1) = '1' then
					audio_next_sequence <= spi_readdata;
					audio_tmp_sequence <= spi_readdata;
				end if;
				
				if audio_cmd(8) = '1' then
					cmd_reset_dac <= '1';
					sdram_write_ptr <= (others => '0');
					sdram_complete_ptr <= (others => '0');
				end if;
				
				if audio_cmd(16) = '1' then
					cmd_user_sig <= '0';
				elsif audio_cmd(17) = '1' then
					cmd_user_sig <= '1';
				end if;
				
				
				if audio_cmd(30) = '1' then
					
					-- Read 4 bytes of volume levels
					
					-- TODO: Check packet length
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_VOLUME_1;
					state <= STARTSPI;
					
					
				elsif audio_cmd(31) = '0' and (audio_cmd(1) = '1' or audio_next_sequence = spi_readdata) then
				
					-- First fragment so always assume there was no audio data in between
					inter_packet_data_len <= (others => '0');
					
					-- Read 3 bytes of audio data
					
					eth_needs_restart <= '0';
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "011";
					spi_auto_disable <= '0';
					
					next_state <= RX_AUDIO_DATA_SAVE;
					state <= STARTSPI;
					
				else
					
					dbg_skip_sequence <= dbg_skip_sequence + 1;
					
					ip_next_frag_offset <= (others => '0'); -- Force next fragment to be 0
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
				end if;
			
			when RX_AUDIO_DATA_SAVE =>
				-- Set SDRAM data
				
				dbg_state <= X"0306";
				
				-- 3 bytes of audio data
				len_remaining <= len_remaining - 3;
				
				if len_remaining = X"0001" or len_remaining = X"0002" then
					
					-- len is less than a full 3-byte audio sample
					-- Special case to save in a register and quit no
					
					-- audio_tmp_sequence is not updated as it will be done later

					-- Last fragment is done, so all data is available for audio
					--if ip_more_fragments = '0' then
					--      sdram_complete_ptr <= sdram_write_ptr;
					--      audio_next_sequence <= audio_tmp_sequence;
					--end if;
					
					-- NOTE: Since we tried to read 3 bytes, the last 1 or 2 bytes will
					-- be garbage
					
					inter_packet_data_reg <= spi_readdata(23 downto 8);
					
					inter_packet_data_len <= len_remaining(1 downto 0);
					
					state <= RX_SET_ERXTAIL;
					
					
				elsif len_remaining = X"0003" then
					
					-- There was 3 bytes left before we subtracted above,
					-- so now we are done.  Don't read from ethernet, just
					-- wait for the SDRAM write above to finish
					
					audio_tmp_sequence <= audio_tmp_sequence + 3;
					
					sdram_write_complete <= '0';
				
					sdram_cycle_s <= '1';
					sdram_strobe_s <= '1';
					
					-- Also pass sequence start of frame to dac controller to sync the beginning of a frame
					sdram_writedata_reg <= start_of_frame & "0000000" & spi_readdata(23 downto 0);
					
					state <= RX_AUDIO_DATA_WAIT_SDRAM;
					
					-- No longer the first sample in a frame
					start_of_frame <= '0';
					
				else
					
					audio_tmp_sequence <= audio_tmp_sequence + 3;
				
					sdram_write_complete <= '0';

					sdram_cycle_s <= '1';
					sdram_strobe_s <= '1';
					
					-- Also pass sequence start of frame to dac controller to sync the beginning of a frame
					sdram_writedata_reg <= start_of_frame & "0000000" & spi_readdata(23 downto 0);
					
					-- Start another read from ethernet
					
					-- If needed we will send CMD_READ_ERXDATA now
					eth_needs_restart <= '0';
					
					if eth_needs_restart = '1' then
						spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
						spi_datacount <= "100";
					else
						spi_writedata <= X"00" & X"00" & X"00" & X"00";
						spi_datacount <= "011";
					end if;
					
					spi_auto_disable <= '0';
					
					next_state <= RX_AUDIO_DATA_WAIT_SDRAM;
					state <= STARTSPI;
					
					-- No longer the first sample in a frame
					start_of_frame <= '0';
					
				end if;
				
				
			when RX_AUDIO_DATA_WAIT_SDRAM =>
				-- Wait for SDRAM complete or ack
				
				dbg_state <= X"037" & "0" & sdram_cycle_s & sdram_strobe_s & sdram_ack;
				
				-- If sdram_complete is set, then we can start another cycle right away
				-- otherwise we need to stop the spi cycle because we won't be ready to
				-- do another read in time (sdram is busy with i2s reading)
				
				if sdram_write_complete = '1' then
				
					state <= RX_AUDIO_DATA_SDRAM_COMPLETE;
					
				else -- complete = '0'
					
					-- Stop SPI for now
					spi_cycle <= '0';
					
					-- Signal that next read will need to send CMD_READ_ERXDATA again
					eth_needs_restart <= '1';
					
					if sdram_ack = '1' then
						
						sdram_cycle_s <= '0';
						sdram_strobe_s <= '0';
						
						state <= RX_AUDIO_DATA_SDRAM_COMPLETE;
						
					end if;
					
				end if;
				
				
			when RX_AUDIO_DATA_SDRAM_COMPLETE =>
				-- SDRAM was already completed, so move on
				
				dbg_state <= X"0308";
				
				sdram_write_ptr <= sdram_write_ptr + 1;
				
				if sdram_write_ptr = (SDRAM_BUFFER_SIZE-1) then
					sdram_write_ptr <= X"000000";
				end if;
				
				if len_remaining = X"0000" then
					
					-- No more data left
					
					inter_packet_data_len <= (others => '0');
					
					-- Last fragment is done, so all data is available for audio
					if ip_more_fragments = '0' then
						audio_next_sequence <= audio_tmp_sequence;
						sdram_complete_ptr <= sdram_write_ptr + 1;
						if sdram_write_ptr = (SDRAM_BUFFER_SIZE-1) then
							sdram_complete_ptr <= X"000000";
						end if;
					end if;
					
					state <= RX_SET_ERXTAIL;
					
					dbg_state <= X"038" & "0" & sdram_cycle_s & sdram_strobe_s & sdram_ack;
					
				else
					
					-- Write the data to sdram that is already in spi_readdata
					state <= RX_AUDIO_DATA_SAVE;
					
				end if;
				
			when RX_UDP_RESUME_FRAGMENT =>
				-- Special case for a subsequent IP fragment
				-- We don't read the UDP headers or audio cmd/seq
				-- instead we just set up to read the audio data
				
				-- TODO: This may be flaky because we just finished 2 states
				--       where we didn't do an SPI command but held spi_cycle
				--       so we may miss the timing for the next spi_clk
				
				dbg_state <= X"030A";
					
				-- Amount of data in this fragment, taking off IP header length
				-- No UDP header on subsequent fragments
				len_remaining <= ip_pkt_len - (ip_hdr_len & "00");
				
				-- No audio data left from the last fragment
				if inter_packet_data_len = "00" then

					-- Read 3 bytes of audio data
					spi_datacount <= "011";
					next_state <= RX_AUDIO_DATA_SAVE;

				elsif inter_packet_data_len = "01" then

					-- Only read what we need to finish this off
					spi_datacount <= "010";
					next_state <= RX_UDP_RESUME_FRAGMENT_FROM_REG;

				elsif inter_packet_data_len = "10" then

					-- Only read what we need to finish this off
					--spi_datacount <= std_logic_vector(to_unsigned(3 - to_integer(unsigned(inter_packet_data_len)), spi_datacount'length));
					spi_datacount <= "001";
					next_state <= RX_UDP_RESUME_FRAGMENT_FROM_REG;

				end if;
				
				eth_needs_restart <= '0';
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_auto_disable <= '0';
				
				state <= STARTSPI;
				
					
				
				
			when RX_UDP_RESUME_FRAGMENT_FROM_REG =>

				-- Special case to resume fragment when part
				-- of the data is coming from the register

				dbg_state <= X"030B";

				audio_tmp_sequence <= audio_tmp_sequence + 3;

				-- NOTE: Unlike RX_AUDIO_DATA_SAVE, we assume that the next fragment will never
				-- contain less than 3 bytes of audio data.
				
				sdram_write_complete <= '0';

				-- Write to sdram
				sdram_cycle_s <= '1';
				sdram_strobe_s <= '1';

				if inter_packet_data_len = "01" then

					len_remaining <= len_remaining - 2; -- == len - (3 - inter_packet_data_len)
					sdram_writedata_reg <= start_of_frame & "0000000" & inter_packet_data_reg(15 downto 8) & spi_readdata(15 downto 0);

					-- No longer the first sample in a frame
					start_of_frame <= '0';
					
				else -- "10"

					len_remaining <= len_remaining - 1; -- == len - (3 - inter_packet_data_len)
					sdram_writedata_reg <= start_of_frame & "0000000" & inter_packet_data_reg(15 downto 0) & spi_readdata(7 downto 0);

					-- No longer the first sample in a frame
					start_of_frame <= '0';
					
				end if;

				-- Start another read from ethernet

				-- If needed we will send CMD_READ_ERXDATA now
				eth_needs_restart <= '0';

				if eth_needs_restart = '1' then
					spi_writedata <= CMD_READ_ERXDATA & X"00" & X"00" & X"00";
					spi_datacount <= "100";
				else
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "011";
				end if;

				spi_auto_disable <= '0';

				next_state <= RX_AUDIO_DATA_WAIT_SDRAM;
				state <= STARTSPI;
				
				
				
			when RX_VOLUME_1 =>
				-- First two 9-bit channel volume controls
				
				volume_left_woofer <= spi_readdata(24 downto 16);
				volume_left_lowmid <= spi_readdata(8 downto 0);
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_VOLUME_2;
				state <= STARTSPI;
				
			when RX_VOLUME_2 =>
				-- Next two 9-bit channel volume controls
				
				volume_left_uppermid <= spi_readdata(24 downto 16);
				volume_left_tweeter <= spi_readdata(8 downto 0);
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_VOLUME_3;
				state <= STARTSPI;
				
			when RX_VOLUME_3 =>
				-- Next two 9-bit channel volume controls
				
				volume_right_woofer <= spi_readdata(24 downto 16);
				volume_right_lowmid <= spi_readdata(8 downto 0);
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_VOLUME_4;
				state <= STARTSPI;
				
			when RX_VOLUME_4 =>
				-- Last two 9-bit channel volume controls
				
				volume_right_uppermid <= spi_readdata(24 downto 16);
				volume_right_tweeter <= spi_readdata(8 downto 0);
				
				state <= RX_SET_ERXTAIL;				
				
				
				
				
			when RX_DHCP_HDR =>
				-- Check header: expect op=2, htype=1, hlen=6, hops=0
				
				dbg_state <= X"0500";
				
				-- TODO: Check UDP data len
				
				if spi_readdata /= X"02010600" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes for transaction ID
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_XID;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_XID =>
				-- Check transaction ID
				
				dbg_state <= X"0501";
				
				if spi_readdata /= X"DEADBEEF" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes for secs and flags
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_SECS_FLAGS;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_SECS_FLAGS =>
				-- Ignore seconds and flags
				
				dbg_state <= X"0502";
				
				-- Read 4 bytes for client IP
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_DHCP_CIADDR;
				state <= STARTSPI;
				
			when RX_DHCP_CIADDR =>
				-- Ignore client IP
				
				dbg_state <= X"0503";
				
				-- Read 4 bytes for your IP
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_DHCP_YIADDR;
				state <= STARTSPI;
				
			when RX_DHCP_YIADDR =>
				-- Save your IP
				
				dbg_state <= X"0504";
				
				dhcp_client_ip <= spi_readdata;
				
				-- Read 4 bytes for server IP
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_DHCP_SIADDR;
				state <= STARTSPI;
				
			when RX_DHCP_SIADDR =>
				-- Save server IP
				
				dbg_state <= X"0505";
				
				dhcp_server_ip <= spi_readdata;
				
				-- Read 4 bytes for gateway IP
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_DHCP_GIADDR;
				state <= STARTSPI;
				
			when RX_DHCP_GIADDR =>
				-- Ignore gateway IP
				
				dbg_state <= X"0506";
				
				-- Read 4 bytes for client hardware address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= RX_DHCP_CHADDR_1;
				state <= STARTSPI;
				
			when RX_DHCP_CHADDR_1 =>
				-- Check client hardware address

				dbg_state <= X"0507";
				
				if spi_readdata /= local_macaddr(47 downto 16) then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes for client hardware address
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_CHADDR_2;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_CHADDR_2 =>
				-- Check client hardware address

				dbg_state <= X"0508";
				
				if spi_readdata /= local_macaddr(15 downto 0) & X"0000" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes for client hardware address
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_CHADDR_3;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_CHADDR_3 =>
				-- Check client hardware address

				dbg_state <= X"0509";
				
				if spi_readdata /= X"00000000" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 4 bytes for client hardware address
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_CHADDR_4;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_CHADDR_4 =>
				-- Check client hardware address

				dbg_state <= X"050A";
				
				if spi_readdata /= X"00000000" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- Read 192 bytes for sname and file
					
					len_remaining <= std_logic_vector(to_unsigned(192, len_remaining'length));
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "100";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_SNAME_FILE;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_SNAME_FILE =>
				-- Skip sname and file
				
				dbg_state <= X"050B";
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				state <= STARTSPI;
				
				len_remaining <= len_remaining - 4;
				if len_remaining = 4 then
					next_state <= RX_DHCP_COOKIE;
				end if;
				
			when RX_DHCP_COOKIE =>
				-- Check magic cookie from RFC

				dbg_state <= X"050C";
				
				if spi_readdata /= X"63825363" then
					
					spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
					state <= RX_SET_ERXTAIL;
					
				else
					
					-- TODO: Check UDP data len before reading more
					
					-- Read 2 bytes for option type and length
					
					-- TODO: This doesn't handle END and PADDING properly,
					-- which both have no length indicator
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "010";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_OPT_TAG;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_OPT_TAG =>
				-- Decode option type and length
				
				dbg_state <= X"050D";
				
				dhcp_opt_type <= spi_readdata(15 downto 8);
				dhcp_opt_len <= spi_readdata(7 downto 0);

				-- END
				if spi_readdata(15 downto 8) = X"FF" then
					
					if dhcp_state = HAVE_OFFER then
						
						spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
						state <= RX_DHCP_SET_ERXTAIL;
						
					elsif dhcp_state = HAVE_ACK then
						
						local_ipaddr <= dhcp_client_ip;
						dhcp_state <= COMPLETE;
						dhcp_renew_left <= dhcp_renew_timeout;
						
						spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
						state <= RX_SET_ERXTAIL;
						
					end if;
					
				else
					
					-- Read up to 4 bytes for option data
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_auto_disable <= '0';
					
					-- TODO: Check UDP data len before reading more
					
					if spi_readdata(7 downto 0) = X"00" then
						
						spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
						state <= RX_SET_ERXTAIL;
						
					elsif spi_readdata(7 downto 2) /= "000000" then
						spi_datacount <= "100";
					else
						spi_datacount <= "0" & spi_readdata(1 downto 0);
					end if;
					
					next_state <= RX_DHCP_OPT_DATA;
					state <= STARTSPI;
					
				end if;
				
			when RX_DHCP_OPT_DATA =>
				-- Decode option type and length
				
				dbg_state <= X"050E";
				
				dhcp_opt_len <= dhcp_opt_len - 4;
				
				-- Done with data
				if dhcp_opt_len < 5 then
					
					-- TODO: Check UDP data len before reading more
					
					-- Read 2 bytes for option type and length
					
					-- TODO: This doesn't handle END and PADDING properly,
					-- which both have no length indicator
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_datacount <= "010";
					spi_auto_disable <= '0';
					
					next_state <= RX_DHCP_OPT_TAG;
					state <= STARTSPI;
					
					
					-- Message type
					if dhcp_opt_type = X"35" then
						if dhcp_state = SENT_DISCOVER and spi_readdata(7 downto 0) = X"02" then
							
							dhcp_state <= HAVE_OFFER;
							
						elsif (dhcp_state = SENT_REQUEST or dhcp_state = SENT_RENEW) and spi_readdata(7 downto 0) = X"05" then
							
							dhcp_state <= HAVE_ACK;
							
						else
							
							spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
							state <= RX_SET_ERXTAIL;
							
						end if;
						
					-- Server ID
					elsif dhcp_opt_type = X"36" then
						
						dhcp_server_id <= spi_readdata;
						
					-- Renewal time
					elsif dhcp_opt_type = X"3A" then
						
						dhcp_renew_timeout <= spi_readdata;
						
					end if;
					
				else
					
					-- Read up to 4 bytes for option data
					
					spi_writedata <= X"00" & X"00" & X"00" & X"00";
					spi_auto_disable <= '0';
					
					if spi_readdata(7 downto 0) = X"00" then
						
						spi_cycle <= '0'; -- Since auto_disable was 0 in prev state
						state <= RX_SET_ERXTAIL;
						
					elsif spi_readdata(7 downto 2) /= "000000" then
						spi_datacount <= "100";
					else
						spi_datacount <= "0" & spi_readdata(1 downto 0);
					end if;
					
					next_state <= RX_DHCP_OPT_DATA;
					state <= STARTSPI;
					
				end if;
				

				
				
				
				
				
			when RX_SET_ERXTAIL =>
				-- Set ERXTAIL to indicate that we are done with
				-- the buffer space
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ERXTAILL & rx_next_rxtail(7 downto 0) & rx_next_rxtail(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_DECPKT;
				state <= STARTSPI;
				
			when RX_DECPKT =>
				-- Decrement packet counter and update rx_current_packet
				
				rx_current_packet <= rx_next_packet;
				
				spi_writedata <= CMD_SETPKTDEC & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= INT_ENABLE_INTERRUPTS;
				state <= STARTSPI;
				
				
				
			when RX_DHCP_SET_ERXTAIL =>
				-- Set ERXTAIL to indicate that we are done with
				-- the buffer space
				
				dbg_state <= X"050F";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ERXTAILL & rx_next_rxtail(7 downto 0) & rx_next_rxtail(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= RX_DHCP_DECPKT;
				state <= STARTSPI;
				
			when RX_DHCP_DECPKT =>
				-- Decrement packet counter and update rx_current_packet
				
				dbg_state <= X"0510";
				
				rx_current_packet <= rx_next_packet;
				
				spi_writedata <= CMD_SETPKTDEC & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_INT_ENABLE_INTERRUPTS;
				state <= STARTSPI;
				
			when DHCP_INT_ENABLE_INTERRUPTS =>
				-- Enable interrupts now that handling is complete
				
				dbg_state <= X"0511";
				
				spi_writedata <= CMD_SETEIE & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_REQUEST_PTR;
				state <= STARTSPI;

				
				
				
				
				
				
			when TX_STATUS_PTR =>
				-- Set ptr to UDP_REPLY packet area
				
				spi_writedata <= CMD_WRITE_EGPWRPT & UDP_STATUS_ADDR(7 downto 0) & UDP_STATUS_ADDR(15 downto 8) & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= TX_STATUS_DST_ADDR_1;
				state <= STARTSPI;
				
			when TX_STATUS_DST_ADDR_1 =>
				-- Write 3 bytes of dest mac addr
				
				spi_writedata <= CMD_WRITE_EGPDATA & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_DST_ADDR_2;
				state <= STARTSPI;
				
			when TX_STATUS_DST_ADDR_2 =>
				-- Write 3 bytes of dest mac addr
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_ETHERTYPE;
				state <= STARTSPI;

			when TX_STATUS_ETHERTYPE =>
				-- Write ethertype
				
				spi_writedata <= X"0800" & X"00"& X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_IPHDR_1;
				state <= STARTSPI;
				
			when TX_STATUS_IPHDR_1 =>
				-- Write 4 bytes of IP header: (Ver, IHL), (DSCP, ECN), Total Len (x2)
				
				ip_checksum <= X"00004500" + X"00000028";
				
				-- Length = 20 (IP hdr) + 8 (UDP hdr) + 12 (data) = 0x0028
				spi_writedata <= X"45" & X"00" & X"0028";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_IPHDR_2;
				state <= STARTSPI;
				
			when TX_STATUS_IPHDR_2 =>
				-- Write 4 bytes of IP header: ID (x2), Flags, Offset
				
				ip_checksum <= ip_checksum + X"00000000" + X"00004000" +
					(X"000040" & IPPROTO_UDP) + X"00000000" + (X"0000" & local_ipaddr(31 downto 16)) +
					(X"0000" & local_ipaddr(15 downto 0)) + X"0000FFFF" + X"0000FFFF";
				
				spi_writedata <= X"0000" & X"40" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_IPHDR_3;
				state <= STARTSPI;
				
			when TX_STATUS_IPHDR_3 =>
				-- Write 4 bytes of IP header: TTL, Proto, Header checksum (x2)
				
				spi_writedata <= X"40" & IPPROTO_UDP & ((ip_checksum(31 downto 16) + ip_checksum(15 downto 0)) xor X"FFFF");
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_IPHDR_4;
				state <= STARTSPI;
				
			when TX_STATUS_IPHDR_4 =>
				-- Write 4 bytes of IP header: Src IP
				
				spi_writedata <= local_ipaddr;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_IPHDR_5;
				state <= STARTSPI;
				
			when TX_STATUS_IPHDR_5 =>
				-- Write 4 bytes of IP header: Dest IP
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_UDPHDR_1;
				state <= STARTSPI;
				
			when TX_STATUS_UDPHDR_1 =>
				-- Write 4 bytes of UDP header: Src port, Dest port
				
				spi_writedata <= UDP_PORT_STATUS & UDP_PORT_STATUS;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_UDPHDR_2;
				state <= STARTSPI;
				
			when TX_STATUS_UDPHDR_2 =>
				-- Write 4 bytes of UDP header: Dest port, Length, Checksum
				
				-- UDP hdr = 8, UDP data = 12, total 20 bytes
				-- Checksum 0 means ignore
				spi_writedata <= X"0014" & X"0000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_SEQUENCE;
				state <= STARTSPI;
				
			when TX_STATUS_SEQUENCE =>
				-- Write 4 bytes of current sequence number
				
				--dbg_state <= X"0410";
				
				spi_writedata <= audio_next_sequence;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_WINDOW;
				state <= STARTSPI;
				
			when TX_STATUS_WINDOW =>
				-- Write 4 bytes of window size
				
				--dbg_state <= X"0420";
				
				spi_writedata <= "000000" & sdram_size_avail & "00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= TX_STATUS_STATUS;
				state <= STARTSPI;
				
			when TX_STATUS_STATUS =>
				-- Write 4 bytes of status bitmask
				
				--dbg_state <= X"0420";
				
				clk16Mwarning_rst <= '1';
				
				spi_writedata <= X"0000000" & "000" & clk16Mwarning;
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= TX_STATUS_SET_TXST;
				state <= STARTSPI;
				
			when TX_STATUS_SET_TXST =>
				-- Set TXST to start address of packet
				
				--dbg_state <= X"0440";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXSTL & UDP_STATUS_ADDR(7 downto 0) & UDP_STATUS_ADDR(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= TX_STATUS_SET_TXLEN;
				state <= STARTSPI;
				
			when TX_STATUS_SET_TXLEN =>
				-- Set TXLEN to length of packet
				
				--dbg_state <= X"0450";
				
				-- IP/UDP header is 28 bytes, 12 bytes data, plus 2 ethertype, plus 6 dest MAC addr
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXLENL & X"34" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= TX_STATUS_DO_TXRTS;
				state <= STARTSPI;
				
			when TX_STATUS_DO_TXRTS =>
				-- Set TXRTS bit to start transmitting
				
				--dbg_state <= X"0460";
				
				spi_writedata <= CMD_SETTXRTS & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				-- Done with packet
				next_state <= IDLE;
				state <= STARTSPI;
				
				
				
				
				
			when DHCP_DISCOVER_PTR =>
				-- Set ptr to DHCP discover packet area
				
				spi_writedata <= CMD_WRITE_EGPWRPT & DHCP_PKT_ADDR(7 downto 0) & DHCP_PKT_ADDR(15 downto 8) & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_DISCOVER_DST_ADDR_1;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DST_ADDR_1 =>
				-- Write 3 bytes of dest mac addr
				
				spi_writedata <= CMD_WRITE_EGPDATA & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DST_ADDR_2;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DST_ADDR_2 =>
				-- Write 3 bytes of dest mac addr
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_ETHERTYPE;
				state <= STARTSPI;

			when DHCP_DISCOVER_ETHERTYPE =>
				-- Write ethertype
				
				spi_writedata <= X"0800" & X"00"& X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_IPHDR_1;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_IPHDR_1 =>
				-- Write 4 bytes of IP header: (Ver, IHL), (DSCP, ECN), Total Len (x2)
				
				-- Length = 20 (IP hdr) + 8 (UDP hdr) + 240 (DHCP data) + 16 (DHCP options) = 0x011C
				spi_writedata <= X"45" & X"00" & X"011C";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_IPHDR_2;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_IPHDR_2 =>
				-- Write 4 bytes of IP header: ID (x2), Flags, Offset
				
				spi_writedata <= X"0000" & X"40" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_IPHDR_3;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_IPHDR_3 =>
				-- Write 4 bytes of IP header: TTL, Proto, Header checksum (x2)
				
				spi_writedata <= X"40" & IPPROTO_UDP & X"39D2";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_IPHDR_4;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_IPHDR_4 =>
				-- Write 4 bytes of IP header: Src IP
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_IPHDR_5;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_IPHDR_5 =>
				-- Write 4 bytes of IP header: Dest IP
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_UDPHDR_1;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_UDPHDR_1 =>
				-- Write 4 bytes of UDP header: Src port, Dest port
				
				spi_writedata <= UDP_PORT_DHCPC & UDP_PORT_DHCPS;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_UDPHDR_2;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_UDPHDR_2 =>
				-- Write 4 bytes of UDP header: Dest port, Length, Checksum
				
				-- UDP hdr = 8, UDP data = 256, total 264 bytes
				-- Checksum 0 means ignore
				spi_writedata <= X"0108" & X"0000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_HDR;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_HDR =>
				-- Write 4 bytes of DHCP header: op, htype, hlen, hops
				
				-- op=request, htype=ethernet, hlen=MAC addr len, hops=0
				spi_writedata <= X"01" & X"01" & X"06" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_XID;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_XID =>
				-- Write 4 bytes of DHCP header: transaction ID
				
				spi_writedata <= X"DEADBEEF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_SECS_FLAGS;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_SECS_FLAGS =>
				-- Write 4 bytes of DHCP header: seconds elapsed, flags
				
				-- flags = broadcast
				spi_writedata <= X"0000" & X"8000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_CIADDR;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_CIADDR =>
				-- Write 4 bytes of Client IP
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_YIADDR;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_YIADDR =>
				-- Write 4 bytes of Your IP
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_SIADDR;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_SIADDR =>
				-- Write 4 bytes of Server IP
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_GIADDR;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_GIADDR =>
				-- Write 4 bytes of Gateway IP
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_CHADDR_1;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_CHADDR_1 =>
				-- Write 4 bytes of client hardware address
				
				spi_writedata <= local_macaddr(47 downto 16);
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_CHADDR_2;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_CHADDR_2 =>
				-- Write 4 bytes of client hardware address
				
				spi_writedata <= local_macaddr(15 downto 0) & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_CHADDR_3;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_CHADDR_3 =>
				-- Write 4 bytes of client hardware address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_CHADDR_4;
				state <= STARTSPI;

			when DHCP_DISCOVER_DHCP_CHADDR_4 =>
				-- Write 4 bytes of client hardware address
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				-- How many zeros are needed for sname and file
				len_remaining <= std_logic_vector(to_unsigned(192, len_remaining'length));
				
				next_state <= DHCP_DISCOVER_DHCP_SNAME_FILE;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_SNAME_FILE =>
				-- Write lots of zeros for sname and file fields
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				len_remaining <= len_remaining - 4;
				if len_remaining = 4 then
					next_state <= DHCP_DISCOVER_DHCP_COOKIE;
				end if;
				
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_COOKIE =>
				-- Write 4 bytes of cookie to start options
				
				-- This is just a magic number defined in the RFC
				spi_writedata <= X"63825363";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_OPT_1;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_OPT_1 =>
				-- Write 4 bytes of options
				
				-- options:
				-- 53 1 1 -- dhcp discover type
				-- 12 3 a m p - host name
				-- 55 4 1 28 3 12 -- request params: subnet mask, broadcast, router, host name
				-- 255 - end
				-- 0 - padding
				spi_writedata <= X"35" & X"01" & X"01" & X"0C";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_OPT_2;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_OPT_2 =>
				-- Write 4 bytes of options

				spi_writedata <= X"03" & X"61" & X"6D" & X"70";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_OPT_3;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_OPT_3 =>
				-- Write 4 bytes of options

				spi_writedata <= X"37" & X"04" & X"01" & X"1C";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_DISCOVER_DHCP_OPT_4;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DHCP_OPT_4 =>
				-- Write 4 bytes of options

				spi_writedata <= X"03" & X"0C" & X"FF" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_DISCOVER_SET_TXST;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_SET_TXST =>
				-- Set TXST to start address of packet
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXSTL & DHCP_PKT_ADDR(7 downto 0) & DHCP_PKT_ADDR(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_DISCOVER_SET_TXLEN;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_SET_TXLEN =>
				-- Set TXLEN to length of packet
				
				-- IP/UDP header is 28 bytes, 256 bytes data, plus 2 ethertype, plus 6 dest MAC addr
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXLENL & X"24" & X"01";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_DISCOVER_DO_TXRTS;
				state <= STARTSPI;
				
			when DHCP_DISCOVER_DO_TXRTS =>
				-- Set TXRTS bit to start transmitting
				
				dhcp_state <= SENT_DISCOVER;
				dhcp_resp_timeout <= (others => '0');
				
				spi_writedata <= CMD_SETTXRTS & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				-- Done with packet
				next_state <= IDLE;
				state <= STARTSPI;
				
				
				
				
				
			when DHCP_REQUEST_PTR =>
				-- Set ptr to DHCP request packet area
				
				dbg_state <= X"0700";
				
				spi_writedata <= CMD_WRITE_EGPWRPT & DHCP_PKT_ADDR(7 downto 0) & DHCP_PKT_ADDR(15 downto 8) & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_REQUEST_DST_ADDR_1;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DST_ADDR_1 =>
				-- Write 3 bytes of dest mac addr
				
				dbg_state <= X"0701";
				
				spi_writedata <= CMD_WRITE_EGPDATA & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DST_ADDR_2;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DST_ADDR_2 =>
				-- Write 3 bytes of dest mac addr
				
				dbg_state <= X"0702";
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"00";
				spi_datacount <= "011";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_ETHERTYPE;
				state <= STARTSPI;

			when DHCP_REQUEST_ETHERTYPE =>
				-- Write ethertype
				
				dbg_state <= X"0703";
				
				spi_writedata <= X"0800" & X"00"& X"00";
				spi_datacount <= "010";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_IPHDR_1;
				state <= STARTSPI;
				
			when DHCP_REQUEST_IPHDR_1 =>
				-- Write 4 bytes of IP header: (Ver, IHL), (DSCP, ECN), Total Len (x2)
				
				dbg_state <= X"0704";
				
				-- Length = 20 (IP hdr) + 8 (UDP hdr) + 240 (DHCP data) + 16 (DHCP options) = 0x011C
				spi_writedata <= X"45" & X"00" & X"011C";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_IPHDR_2;
				state <= STARTSPI;
				
			when DHCP_REQUEST_IPHDR_2 =>
				-- Write 4 bytes of IP header: ID (x2), Flags, Offset
				
				dbg_state <= X"0705";
				
				spi_writedata <= X"0000" & X"40" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_IPHDR_3;
				state <= STARTSPI;
				
			when DHCP_REQUEST_IPHDR_3 =>
				-- Write 4 bytes of IP header: TTL, Proto, Header checksum (x2)
				
				dbg_state <= X"0706";
				
				spi_writedata <= X"40" & IPPROTO_UDP & X"39D2";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_IPHDR_4;
				state <= STARTSPI;
				
			when DHCP_REQUEST_IPHDR_4 =>
				-- Write 4 bytes of IP header: Src IP
				
				dbg_state <= X"0707";
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_IPHDR_5;
				state <= STARTSPI;
				
			when DHCP_REQUEST_IPHDR_5 =>
				-- Write 4 bytes of IP header: Dest IP
				
				dbg_state <= X"0708";
				
				spi_writedata <= X"FF" & X"FF" & X"FF" & X"FF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_UDPHDR_1;
				state <= STARTSPI;
				
			when DHCP_REQUEST_UDPHDR_1 =>
				-- Write 4 bytes of UDP header: Src port, Dest port
				
				dbg_state <= X"0709";
				
				spi_writedata <= UDP_PORT_DHCPC & UDP_PORT_DHCPS;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_UDPHDR_2;
				state <= STARTSPI;
				
			when DHCP_REQUEST_UDPHDR_2 =>
				-- Write 4 bytes of UDP header: Dest port, Length, Checksum
				
				dbg_state <= X"070A";
				
				-- UDP hdr = 8, UDP data = 256, total 264 bytes
				-- Checksum 0 means ignore
				spi_writedata <= X"0108" & X"0000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_HDR;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_HDR =>
				-- Write 4 bytes of DHCP header: op, htype, hlen, hops
				
				dbg_state <= X"070B";
				
				-- op=request, htype=ethernet, hlen=MAC addr len, hops=0
				spi_writedata <= X"01" & X"01" & X"06" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_XID;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_XID =>
				-- Write 4 bytes of DHCP header: transaction ID
				
				dbg_state <= X"070C";
				
				spi_writedata <= X"DEADBEEF";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_SECS_FLAGS;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_SECS_FLAGS =>
				-- Write 4 bytes of DHCP header: seconds elapsed, flags
				
				dbg_state <= X"070D";
				
				-- flags = broadcast
				spi_writedata <= X"0000" & X"8000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_CIADDR;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_CIADDR =>
				-- Write 4 bytes of Client IP
				
				dbg_state <= X"070E";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= dhcp_client_ip;
				else
					spi_writedata <= X"00000000";
				end if;
				
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_YIADDR;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_YIADDR =>
				-- Write 4 bytes of Your IP
				
				dbg_state <= X"070F";
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_SIADDR;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_SIADDR =>
				-- Write 4 bytes of Server IP
				
				dbg_state <= X"0710";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= X"00000000";
				else
					spi_writedata <= dhcp_server_ip;
				end if;
				
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_GIADDR;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_GIADDR =>
				-- Write 4 bytes of Gateway IP
				
				dbg_state <= X"0711";
				
				spi_writedata <= X"00000000";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_CHADDR_1;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_CHADDR_1 =>
				-- Write 4 bytes of client hardware address
				
				dbg_state <= X"0712";
				
				spi_writedata <= local_macaddr(47 downto 16);
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_CHADDR_2;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_CHADDR_2 =>
				-- Write 4 bytes of client hardware address
				
				dbg_state <= X"0713";
				
				spi_writedata <= local_macaddr(15 downto 0) & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_CHADDR_3;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_CHADDR_3 =>
				-- Write 4 bytes of client hardware address
				
				dbg_state <= X"0714";
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_CHADDR_4;
				state <= STARTSPI;

			when DHCP_REQUEST_DHCP_CHADDR_4 =>
				-- Write 4 bytes of client hardware address
				
				dbg_state <= X"0715";
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				-- How many zeros are needed for sname and file
				len_remaining <= std_logic_vector(to_unsigned(192, len_remaining'length));
				
				next_state <= DHCP_REQUEST_DHCP_SNAME_FILE;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_SNAME_FILE =>
				-- Write lots of zeros for sname and file fields
				
				dbg_state <= X"0716";
				
				spi_writedata <= X"00" & X"00" & X"00" & X"00";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				len_remaining <= len_remaining - 4;
				if len_remaining = 4 then
					next_state <= DHCP_REQUEST_DHCP_COOKIE;
				end if;
				
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_COOKIE =>
				-- Write 4 bytes of cookie to start options
				
				dbg_state <= X"0717";
				
				-- This is just a magic number defined in the RFC
				spi_writedata <= X"63825363";
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_OPT_1;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_OPT_1 =>
				-- Write 4 bytes of options
				
				dbg_state <= X"0718";
				
				-- options for request:
				-- 53 1 3 -- dhcp request type
				-- 54 4 a.b.c.d - DHCP server ID
				-- 50 4 a.b.c.d - IP address requested
				-- 255 - end
				
				-- options for renew:
				-- 53 1 3 -- dhcp request type
				-- 255 - end
				-- 0 0 0.0.0.0 - not used
				-- 0 0 0 0 0 0 - not used
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= X"35" & X"01" & X"03" & X"FF";
				else
					spi_writedata <= X"35" & X"01" & X"03" & X"36";
				end if;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_OPT_2;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_OPT_2 =>
				-- Write 4 bytes of options

				dbg_state <= X"0719";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= X"00000000";
				else
					spi_writedata <= X"04" & dhcp_server_id(31 downto 8);
				end if;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_OPT_3;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_OPT_3 =>
				-- Write 4 bytes of options

				dbg_state <= X"071A";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= X"00000000";
				else
					spi_writedata <= dhcp_server_id(7 downto 0) & X"32" & X"04" & dhcp_client_ip(31 downto 24);
				end if;
				spi_datacount <= "100";
				spi_auto_disable <= '0';
				
				next_state <= DHCP_REQUEST_DHCP_OPT_4;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DHCP_OPT_4 =>
				-- Write 4 bytes of options

				dbg_state <= X"071B";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					spi_writedata <= X"00000000";
				else
					spi_writedata <= dhcp_client_ip(23 downto 0) & X"FF";
				end if;
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_REQUEST_SET_TXST;
				state <= STARTSPI;
				
			when DHCP_REQUEST_SET_TXST =>
				-- Set TXST to start address of packet
				
				dbg_state <= X"071C";
				
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXSTL & DHCP_PKT_ADDR(7 downto 0) & DHCP_PKT_ADDR(15 downto 8);
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_REQUEST_SET_TXLEN;
				state <= STARTSPI;
				
			when DHCP_REQUEST_SET_TXLEN =>
				-- Set TXLEN to length of packet
				
				dbg_state <= X"071D";
				
				-- IP/UDP header is 28 bytes, 256 bytes data, plus 2 ethertype, plus 6 dest MAC addr
				spi_writedata <= CMD_WRITE_REG_UNBANKED & REG_ETXLENL & X"24" & X"01";
				spi_datacount <= "100";
				spi_auto_disable <= '1';
				
				next_state <= DHCP_REQUEST_DO_TXRTS;
				state <= STARTSPI;
				
			when DHCP_REQUEST_DO_TXRTS =>
				-- Set TXRTS bit to start transmitting
				
				dbg_state <= X"071E";
				
				if dhcp_state = NEED_RENEW or dhcp_state = SENT_RENEW then
					dhcp_state <= SENT_RENEW;
				else
					dhcp_state <= SENT_REQUEST;
				end if;
				
				dhcp_resp_timeout <= (others => '0');
				
				spi_writedata <= CMD_SETTXRTS & X"00" & X"00" & X"00";
				spi_datacount <= "001";
				spi_auto_disable <= '1';
				
				-- Done with packet
				next_state <= IDLE;
				state <= STARTSPI;
				
				
				
				
				
			when STARTSPI =>
				
				--dbg_state(13) <= '0';
				--dbg_state(12) <= '0';
				
				if spi_ack = '0' then
					--dbg_state(14) <= '0';
			
					spi_cycle <= '1';
					spi_strobe <= '1';
					state <= WAITACK;
				end if;

				-- For writing to sdram while reading from ethernet
				if sdram_ack = '1' then
					
					sdram_cycle_s <= '0';
					sdram_strobe_s <= '0';
					sdram_write_complete <= '1';
					
				end if;
				
			when WAITACK =>
				
				--if spi_ack = '1' then
				--	dbg_state(14) <= '0';
				--end if;
				
				if spi_ack = '1' and spi_auto_disable = '1' then
					--dbg_state(12) <= '0';
					spi_cycle <= '0';
					spi_strobe <= '0';
					state <= next_state;
				elsif spi_ack = '1' and spi_auto_disable = '0' then
					--dbg_state(12) <= '0';
					spi_strobe <= '0';
					state <= next_state;
				end if;
				
				-- For writing to sdram while reading from ethernet
				if sdram_ack = '1' then
					
					sdram_cycle_s <= '0';
					sdram_strobe_s <= '0';
					sdram_write_complete <= '1';
					
				end if;
				
			when WAITCOUNT =>
				
				counter <= counter + 1;
				
				if counter = counter_stop_wait then
					state <= next_state;
				end if;
				
			when ERROR =>
				
				have_error <= '1';
			
				state <= ERROR;
				
			when others =>
			
				--dbg_state <= X"FEFE";
				state <= ERROR;
			
		end case;
		
	end if;
end process;


	process(sys_clk,sys_reset)
	begin
		if sys_reset = '1' then
			ten_hz_int_i <= '0';
			ten_hz_counter <= (others => '0');
		elsif rising_edge(sys_clk) then
		
			ten_hz_int_i <= '0';
		
			ten_hz_counter <= ten_hz_counter + 1;
			if ten_hz_counter = (TEN_HZ_PERIOD-1) then
				ten_hz_int_i <= '1';
				ten_hz_counter <= (others => '0');
			end if;
			
		end if;
		
	end process;


	syncsignal_eth_int : entity work.syncsignal
	port map(
		target_clk => sys_clk,
		sys_reset => sys_reset,
		sig_i => eth_int_i,
		sig_o => eth_int_o
	);

	
	
	intreg_tx_status : entity work.interrupt_reg
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		int_i => ten_hz_int_i,
		int_o => ten_hz_int_o,
		rst_i => ten_hz_int_rst
	);

	ethspi_interface : entity work.spimaster
		port map(
			sys_clk => sys_clk,
			sys_reset => sys_reset,
			cyc_i => spi_cycle,
			stb_i => spi_strobe,
			data_i => spi_writedata,
			data_o => spi_readdata,
			data_cnt_i => spi_datacount,
			ack_o => spi_ack,
			
			spi_clk => spi_clk,
			spi_mosi => spi_mosi,
			spi_miso => spi_miso,
			spi_cs => spi_cs,
			
			dbg_state => dbg_spi_state
		);
	
end Behavioral;

