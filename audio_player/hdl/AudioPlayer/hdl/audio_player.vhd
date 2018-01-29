----------------------------------------------------------------------------------
--
-- Top level module with busses and other signals that connect all other
-- modules
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

library work ;
use work.logi_wishbone_pack.all ;
use work.logi_wishbone_peripherals_pack.all ;
use work.verilog_compat.all ;

entity audio_player is
port( OSC_FPGA : in std_logic;

		PB : in std_logic_vector(1 downto 0);
		SW : in std_logic_vector(1 downto 0);
		LED : out std_logic_vector(1 downto 0);	
		
		PMOD4 : inout std_logic_vector(7 downto 0); 
		
		PMOD3 : inout std_logic_vector(7 downto 0); 
		
		PMOD2 : inout std_logic_vector(7 downto 0); 
		
		PMOD1 : inout std_logic_vector(7 downto 0); 
		--i2c
		--SYS_SCL, SYS_SDA : inout std_logic ;
		
		SDRAM_CKE : out std_logic;
		SDRAM_CLK : out std_logic;
		SDRAM_nCAS : out std_logic;
		SDRAM_nRAS : out std_logic;
		SDRAM_nWE : out std_logic;
		SDRAM_BA : out std_logic_vector(1 downto 0);
		SDRAM_DQM : out std_logic_vector(1 downto 0);
		SDRAM_ADDR : out std_logic_vector(12 downto 0);
		SDRAM_DQ : inout std_logic_vector(15 downto 0);
		
		RP_GPIO_GEN2 : out std_logic;
		
		SYS_SPI_SCK, RP_SPI_CE0N, SYS_SPI_MOSI : in std_logic ;
		SYS_SPI_MISO : out std_logic
);
end audio_player;

architecture Behavioral of audio_player is

	-- Size is in 32-bit words, 4 MByte
	constant SDRAM_BUFFER_SIZE : std_logic_vector(23 downto 0) := X"100000";



	signal sys_reset, sys_resetn,sys_clk, clock_locked : std_logic ;
	signal clk_100Mhz, clk_100Mhz_pll, osc_buff, clkfb  : std_logic ;

	-- Raspberry PI SPI
	signal intercon_wrapper_wbm_address :  std_logic_vector(23 downto 0);
	signal intercon_wrapper_wbm_readdata :  std_logic_vector(15 downto 0);
	signal intercon_wrapper_wbm_writedata :  std_logic_vector(15 downto 0);
	signal intercon_wrapper_wbm_strobe :  std_logic;
	signal intercon_wrapper_wbm_write :  std_logic;
	signal intercon_wrapper_wbm_ack :  std_logic;
	signal intercon_wrapper_wbm_cycle :  std_logic;

	-- Internal registers (debugging)
	signal intercon_register_wbm_address :  std_logic_vector(23 downto 0);
	signal intercon_register_wbm_readdata :  std_logic_vector(15 downto 0);
	signal intercon_register_wbm_writedata :  std_logic_vector(15 downto 0);
	signal intercon_register_wbm_strobe :  std_logic;
	signal intercon_register_wbm_write :  std_logic;
	signal intercon_register_wbm_ack :  std_logic;
	signal intercon_register_wbm_cycle :  std_logic;
	
	-- SDRAM controller
	signal sdram_writedata :  std_logic_vector(31 downto 0);
	signal sdram_readdata :  std_logic_vector(31 downto 0);
	signal sdram_address :  std_logic_vector(31 downto 0);
	signal sdram_cycle : std_logic;
	signal sdram_strobe : std_logic;
	signal sdram_write : std_logic;
	signal sdram_ack : std_logic;
	signal sdram_stall : std_logic;
	signal sdram_bitmask : std_logic_vector(3 downto 0);
	
	-- Signals from ethernet to drive SDRAM
	signal eth_sdram_writedata :  std_logic_vector(31 downto 0);
	signal eth_sdram_address :  std_logic_vector(31 downto 0);
	signal eth_sdram_complete_address :  std_logic_vector(31 downto 0);
	signal eth_sdram_bitmask : std_logic_vector(3 downto 0);
	signal eth_sdram_cycle : std_logic;
	signal eth_sdram_strobe : std_logic;
	signal eth_sdram_ack : std_logic;
	signal eth_sdram_stall : std_logic;
	
	-- Signals from audio state machine to drive SDRAM
	signal dac_sdram_readdata :  std_logic_vector(31 downto 0);
	signal dac_sdram_address :  std_logic_vector(31 downto 0);
	signal dac_sdram_bitmask : std_logic_vector(3 downto 0);
	signal dac_sdram_cycle : std_logic;
	signal dac_sdram_strobe : std_logic;
	signal dac_sdram_ack : std_logic;
	signal dac_sdram_stall : std_logic;
	
	-- Signals from Raspberry PI to drive SDRAM (indirectly through debug registers)
	signal rpi_sdram_writedata :  std_logic_vector(31 downto 0);
	signal rpi_sdram_readdata :  std_logic_vector(31 downto 0);
	signal rpi_sdram_address :  std_logic_vector(31 downto 0);
	signal rpi_sdram_bitmask : std_logic_vector(3 downto 0);
	signal rpi_sdram_cycle : std_logic;
	signal rpi_sdram_strobe : std_logic;
	signal rpi_sdram_write : std_logic;
	signal rpi_sdram_ack : std_logic;
	signal rpi_sdram_stall : std_logic;
	
	
	
	signal dac_mute : std_logic;
	
	
	-- SDRAM wishbone bus arbiter
	type SDRAM_BUS_STATES is (IDLE, DAC, ETHERNET, RPI);
	signal sdram_bus_state : SDRAM_BUS_STATES := IDLE;
	
	
	-- Signals that are shared between ethernet and DAC, because
	-- they share the SDRAM buffer
	signal sdram_buffer_empty : std_logic;
	signal sdram_buffer_below_minimum : std_logic;
	signal sdram_size_avail : std_logic_vector(23 downto 0);
	
	
	-- Signals from ethernet to control other state machines
	signal cmd_mute : std_logic;
	signal cmd_pause : std_logic;
	signal cmd_reset_dac : std_logic;
	
	
	-- Signals from audio state machine to drive the DACs
	signal dac_clk_oe : std_logic;
	signal dac_bitclk_o : std_logic;
	signal dac_lrclk_o : std_logic;
	
	signal dac_left_tweeter_data : std_logic;
	signal dac_left_uppermid_data : std_logic;
	signal dac_left_lowmid_data : std_logic;
	signal dac_left_woofer_data : std_logic;
	signal dac_right_tweeter_data : std_logic;
	signal dac_right_uppermid_data : std_logic;
	signal dac_right_lowmid_data : std_logic;
	signal dac_right_woofer_data : std_logic;
	
	signal volume_left_woofer : std_logic_vector(8 downto 0);
	signal volume_left_lowmid : std_logic_vector(8 downto 0);
	signal volume_left_uppermid : std_logic_vector(8 downto 0);
	signal volume_left_tweeter : std_logic_vector(8 downto 0);
	signal volume_right_woofer : std_logic_vector(8 downto 0);
	signal volume_right_lowmid : std_logic_vector(8 downto 0);
	signal volume_right_uppermid : std_logic_vector(8 downto 0);
	signal volume_right_tweeter : std_logic_vector(8 downto 0);

	
	-- External audio clock (16MHz, 28MHz, etc)
	signal audioclk : std_logic;
	-- Generated 16MHz clock using PLL
	signal clk16Mgen : std_logic;
	-- Output from clock MUX, one of the above clocks
	signal audioclk_selected : std_logic;
	
	-- Monitoring the 16M clock to ensure that it is running
	signal audioclk_active, audioclk_active_reset, audioclk_warning_i, audioclk_warning_o, audioclk_warning_rst : std_logic;
	signal audioclk_active_count : std_logic_vector(7 downto 0);
	
	-- Misc signals
	signal reg_cs : std_logic ;
	
	signal user_sig, idle_sig : std_logic;
	signal idle_count : std_logic_vector(31 downto 0);
	
	signal zzdummy0, zzdummy1, zzdummy2, zzdummy3, zzdummy4, zzdummy5, zzdummy6, zzdummy7, zzdummy8, zzdummy9, zzdummy10, zzdummy11, zzdummy12, zzdummy13, zzdummy14, zzdummy15, zzdummy16, zzdummy17, zzdummy18, zzdummy19, zzdummy20, zzdummy21, zzdummy22 : std_logic_vector(15 downto 0);
	
	-- registers signals
	signal reg_sdram_data_o, reg_sdram_data_i, reg_sdram_addr_h, reg_sdram_addr_l, reg_sdram_ctl_o, reg_sdram_ctl_i : std_logic_vector(15 downto 0);
	signal dbg_eth_state, dbg_dac_state, dbg_sdram_bus_state : std_logic_vector(15 downto 0);
	signal dbg_sram_read_addr, dbg_sram_write_addr : std_logic_vector(15 downto 0);
	signal dbg_eth_next_sequence, dbg_ip_ident, dbg_ip_frag_offset, dbg_spi_readdata : std_logic_vector(15 downto 0);
	signal cmd_freq_select : std_logic_vector(2 downto 0);
begin

sys_reset <= NOT PB(0); 
sys_resetn <= NOT sys_reset ; -- for preipherals with active low reset

sys_clk <= clk_100Mhz;

LED(0) <= dac_mute;
--LED(1) <= '0';

dac_clk_oe <= SW(0);


process (audioclk, audioclk_active_reset)
begin
	if audioclk_active_reset = '1' then
		audioclk_active <= '0';
	elsif rising_edge(audioclk) then
		audioclk_active <= '1';
	end if;
end process;

process (sys_clk, sys_reset)
begin
	if sys_reset = '1' then
		audioclk_active_count <= (others => '0');
		audioclk_active_reset <= '0';
		audioclk_warning_i <= '0';
	elsif rising_edge(sys_clk) then
		
		audioclk_active_count <= audioclk_active_count + 1;
		
		audioclk_active_reset <= '0';
		audioclk_warning_i <= '0';
		
		if audioclk_active_count = X"00" then
			audioclk_active_reset <= '1';
		end if;
		
		if audioclk_active_count = X"FF" and audioclk_active = '0' then
			audioclk_warning_i <= '1';
		end if;
		
	end if;
end process;

intreg_clk16M_warning : entity work.interrupt_reg
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		int_i => audioclk_warning_i,
		int_o => audioclk_warning_o,
		rst_i => audioclk_warning_rst
	);


-- After 10 minutes of no data received, assert ~idle_sig
process (dac_lrclk_o, sys_reset)
begin
	if sys_reset = '1' then
		idle_count <= (others => '0');
	elsif (rising_edge(dac_lrclk_o)) then
		
		idle_sig <= '1';
		
		if dac_mute = '1' then
			idle_count <= idle_count + 1;
		else
			idle_count <= (others => '0');
		end if;
		
		-- 44100 * 60 secs * 10 mins
		if idle_count = X"193BF60" and dac_mute = '1' then
			idle_sig <= '0';
			idle_count <= idle_count;
		end if;
		
	end if;
end process;
	

-- Acts as an SPI slave device so that Raspberry PI can communicate with the FPGA (debugging)
spi_interface : spi_wishbone_wrapper
		port map(
			-- Global Signals
			gls_reset => sys_reset,
			gls_clk   => sys_clk,
			
			-- SPI signals
			mosi => SYS_SPI_MOSI,
			miso => SYS_SPI_MISO,
			sck => SYS_SPI_SCK,
			ss => RP_SPI_CE0N,
			
			  -- Wishbone interface signals
			wbm_address    => intercon_wrapper_wbm_address,  	-- Address bus
			wbm_readdata   => intercon_wrapper_wbm_readdata,  	-- Data bus for read access
			wbm_writedata 	=> intercon_wrapper_wbm_writedata,  -- Data bus for write access
			wbm_strobe     => intercon_wrapper_wbm_strobe,                      -- Data Strobe
			wbm_write      => intercon_wrapper_wbm_write,                      -- Write access
			wbm_ack        => intercon_wrapper_wbm_ack,                      -- acknowledge
			wbm_cycle      => intercon_wrapper_wbm_cycle                       -- bus cycle in progress
			);


-- Generating sdram_buffer_empty, sdram_size_avail, sdram_buffer_below_minimum signals
process(sys_clk)
begin
	
	if rising_edge(sys_clk) then
	
		sdram_buffer_empty <= '0';
		
		-- This must match the bits in SDRAM_BUFFER_SIZE exactly so it can wrap properly
		if dac_sdram_address(20 downto 0) = std_logic_vector(to_unsigned(to_integer(unsigned(SDRAM_BUFFER_SIZE)) - 1, 21)) and eth_sdram_complete_address(20 downto 0) = X"00000" then
			sdram_buffer_empty <= '1';
		elsif dac_sdram_address(20 downto 0) = (eth_sdram_complete_address(20 downto 0) - 1) then
			sdram_buffer_empty <= '1';
		end if;
		
		if dac_sdram_address(20 downto 0) >= eth_sdram_complete_address(20 downto 0) then
			sdram_size_avail <= std_logic_vector(to_unsigned(to_integer(unsigned(dac_sdram_address(20 downto 0))) - to_integer(unsigned(eth_sdram_complete_address(20 downto 0))), sdram_size_avail'length));
		else
			sdram_size_avail <= std_logic_vector(to_unsigned(to_integer(unsigned(SDRAM_BUFFER_SIZE)) - (to_integer(unsigned(eth_sdram_complete_address(20 downto 0))) - to_integer(unsigned(dac_sdram_address(20 downto 0)))), sdram_size_avail'length));
		end if;
		
		sdram_buffer_below_minimum <= '0';
		
		-- At least 0.5 second in buffer (SDRAM_BUFFER_SIZE - (44100 Hz * 8 channels * 1 word) / 2)
		-- Changed to be very small
		if sdram_size_avail > X"30000" then 
			sdram_buffer_below_minimum <= '1';
		end if;
		
	end if;
	
end process;





-- Register address space:
--  Top 2 bits are always "00", because they are used by SPI protocol
reg_cs <= '1';


-- Limit address range
intercon_register_wbm_address <= "0000000000000000" & intercon_wrapper_wbm_address(7 downto 0);
intercon_register_wbm_writedata <= intercon_wrapper_wbm_writedata ;
intercon_register_wbm_write <= intercon_wrapper_wbm_write and reg_cs ;
intercon_register_wbm_strobe <= intercon_wrapper_wbm_strobe and reg_cs ;
intercon_register_wbm_cycle <= intercon_wrapper_wbm_cycle and reg_cs ;		

intercon_wrapper_wbm_readdata	<= intercon_register_wbm_readdata when reg_cs = '1' else
											"1111111111111111";

intercon_wrapper_wbm_ack <= intercon_register_wbm_ack;




-- Lowest bit will be ignored
rpi_sdram_address <= reg_sdram_addr_h(14 downto 0) & reg_sdram_addr_l(15 downto 0) & "0";
rpi_sdram_bitmask <= "0011" when reg_sdram_addr_l(0) = '0' else "1100";
rpi_sdram_writedata <= reg_sdram_data_o & reg_sdram_data_o;



-- Generate SDRAM control signals based on debug registers
-- This is an indirect method of allowing the Raspberry PI to read/write SDRAM
process(sys_clk,sys_reset)
begin
	if sys_reset = '1' then
		reg_sdram_ctl_i <= X"0000";
		rpi_sdram_write <= '0';
		rpi_sdram_strobe <= '0';
		rpi_sdram_cycle <= '0';
	elsif rising_edge(sys_clk) then
		
		if reg_sdram_ctl_o(0) = '1' and reg_sdram_ctl_i(0) = '0' then
		
			rpi_sdram_write <= reg_sdram_ctl_o(1);
			rpi_sdram_strobe <= '1';
			rpi_sdram_cycle <= '1';
			
			reg_sdram_ctl_i(0) <= '1';
		
		elsif reg_sdram_ctl_o(0) = '0' and reg_sdram_ctl_i(0) = '1' then
		
			reg_sdram_ctl_i(0) <= '0';
		
		end if;
		
		if rpi_sdram_cycle = '1' and rpi_sdram_ack = '1' then
		
			if rpi_sdram_write = '0' then
				if reg_sdram_addr_l(0) = '0' then
					reg_sdram_data_i <= rpi_sdram_readdata(15 downto 0);
				else
					reg_sdram_data_i <= rpi_sdram_readdata(31 downto 16);
				end if;
			end if;
		
			rpi_sdram_write <= '0';
			rpi_sdram_strobe <= '0';
			rpi_sdram_cycle <= '0';
			
		end if;
		
	end if;
end process;





dac_sdram_readdata <= sdram_readdata;
rpi_sdram_readdata <= sdram_readdata;

-- SDRAM wishbone bus arbiter.  Since there is only one SDRAM controller,
-- this process arbitrates between the audio state machine, ethernet, and
-- Raspberry PI as to who can communicate with the SDRAM controller.
-- Audio gets highest priority, while RPi gets lowest.
process(sys_clk,sys_reset)
begin
	if sys_reset = '1' then
		sdram_bus_state <= IDLE;
		dbg_sdram_bus_state <= X"0000";
		sdram_writedata <= (others => '0');
		sdram_address <= (others => '0');
		sdram_cycle <= '0';
		sdram_strobe <= '0';
		sdram_write <= '0';
		dac_sdram_ack <= '0';
		eth_sdram_ack <= '0';
		rpi_sdram_ack <= '0';
	elsif rising_edge(sys_clk) then
	
		sdram_writedata <= X"DEADBEEF";
		--sdram_strobe <= '0';
		dac_sdram_ack <= '0';
		eth_sdram_ack <= '0';
		rpi_sdram_ack <= '0';
		
		case sdram_bus_state is
			
				when IDLE =>
					dbg_sdram_bus_state <= dac_sdram_cycle & eth_sdram_cycle & rpi_sdram_cycle & sdram_stall & sdram_strobe & sdram_ack & "00" & X"01";
					
					if dac_sdram_cycle = '1' then
						sdram_bus_state <= DAC;
						sdram_address <= dac_sdram_address(29 downto 0) & "00";
						sdram_bitmask <= dac_sdram_bitmask;
						sdram_cycle <= '1';
						sdram_strobe <= dac_sdram_strobe;
						sdram_write <= '0';
					elsif dac_sdram_cycle = '0' and eth_sdram_cycle = '1' then
						sdram_bus_state <= ETHERNET;
						sdram_address <= eth_sdram_address(29 downto 0) & "00";
						sdram_bitmask <= eth_sdram_bitmask;
						sdram_writedata <= eth_sdram_writedata;
						sdram_cycle <= '1';
						sdram_strobe <= eth_sdram_strobe;
						sdram_write <= '1';
					elsif dac_sdram_cycle = '0' and eth_sdram_cycle = '0' and rpi_sdram_cycle = '1' then
						sdram_bus_state <= RPI;
						sdram_address <= rpi_sdram_address;
						sdram_bitmask <= rpi_sdram_bitmask;
						sdram_writedata <= rpi_sdram_writedata;
						sdram_cycle <= '1';
						sdram_strobe <= rpi_sdram_strobe;
						sdram_write <= rpi_sdram_write;
					end if;
					
				when DAC =>
					dbg_sdram_bus_state <= dac_sdram_cycle & eth_sdram_cycle & rpi_sdram_cycle & sdram_stall & sdram_strobe & sdram_ack & "00" & X"02";
					
					sdram_strobe <= dac_sdram_strobe;
					sdram_address <= dac_sdram_address(29 downto 0) & "00";
					sdram_bitmask <= dac_sdram_bitmask;
					
					dac_sdram_ack <= sdram_ack;
					
					if dac_sdram_cycle = '0' then
						sdram_bus_state <= IDLE;
						sdram_cycle <= '0';
						sdram_strobe <= '0';
					end if;
				
				when ETHERNET =>
					dbg_sdram_bus_state <= dac_sdram_cycle & eth_sdram_cycle & rpi_sdram_cycle & sdram_stall & sdram_strobe & sdram_ack & "00" & X"03";
					
					sdram_strobe <= eth_sdram_strobe;
					sdram_address <= eth_sdram_address(29 downto 0) & "00";
					sdram_bitmask <= eth_sdram_bitmask;
					sdram_writedata <= eth_sdram_writedata;
					
					eth_sdram_ack <= sdram_ack;
				
					if eth_sdram_cycle = '0' then
						sdram_bus_state <= IDLE;
						sdram_cycle <= '0';
						sdram_strobe <= '0';
					end if;
				
				when RPI =>
					dbg_sdram_bus_state <= dac_sdram_cycle & eth_sdram_cycle & rpi_sdram_cycle & sdram_stall & sdram_strobe & sdram_ack & "00" & X"04";
				
					sdram_strobe <= rpi_sdram_strobe;
					sdram_address <= rpi_sdram_address;
					sdram_bitmask <= rpi_sdram_bitmask;
					sdram_writedata <= rpi_sdram_writedata;
					
					rpi_sdram_ack <= sdram_ack;
					
					if rpi_sdram_cycle = '0' then
						sdram_bus_state <= IDLE;
						sdram_cycle <= '0';
						sdram_strobe <= '0';
					end if;
				
	--			when others =>
				
	--				sdram_bus_state <= IDLE;
		
		end case;
		
	end if;
end process;

									      
										  
-- Debug registers that the Raspberry PI can read/write, that
-- are connected to various signals (mostly read-only)
register0 : wishbone_register
	generic map(nb_regs => 27)
	 port map
	 (
		  -- Syscon signals
		  gls_reset   => sys_reset ,
		  gls_clk     => sys_clk ,
		  -- Wishbone signals
		  wbs_address      =>  intercon_register_wbm_address(15 downto 0),
		  wbs_writedata => intercon_register_wbm_writedata,
		  wbs_readdata  => intercon_register_wbm_readdata,
		  wbs_strobe    => intercon_register_wbm_strobe,
		  wbs_cycle     => intercon_register_wbm_cycle,
		  wbs_write     => intercon_register_wbm_write,
		  wbs_ack       => intercon_register_wbm_ack,
		 
		  -- out signals
		  reg_out(0) => zzdummy0,
		  reg_out(1) => reg_sdram_data_o, -- sdram data
		  reg_out(2) => reg_sdram_addr_h, -- address high
		  reg_out(3) => reg_sdram_addr_l, -- address low
		  reg_out(4) => reg_sdram_ctl_o, -- control:  bit 1 = wren, bit 1 = go
		  reg_out(5) => zzdummy1,
		  reg_out(6) => zzdummy2,
		  reg_out(7) => zzdummy3,
		  reg_out(8) => zzdummy4,
		  reg_out(9) => zzdummy5,
		  reg_out(10) => zzdummy6,
		  reg_out(11) => zzdummy7,
		  reg_out(12) => zzdummy8,
		  reg_out(13) => zzdummy9,
		  reg_out(14) => zzdummy10,
		  reg_out(15) => zzdummy11,
		  reg_out(16) => zzdummy12,
		  reg_out(17) => zzdummy13,
		  reg_out(18) => zzdummy14,
		  reg_out(19) => zzdummy15,
		  reg_out(20) => zzdummy16,
		  reg_out(21) => zzdummy17,
		  reg_out(22) => zzdummy18,
		  reg_out(23) => zzdummy19,
		  reg_out(24) => zzdummy20,
		  reg_out(25) => zzdummy21,
		  reg_out(26) => zzdummy22,
		 
		  reg_in(0) => X"DEAD", -- Magic word to verify that the FPGA is loaded
		  reg_in(1) => reg_sdram_data_i,
		  reg_in(2) => reg_sdram_addr_h,
		  reg_in(3) => reg_sdram_addr_l,
		  reg_in(4) => reg_sdram_ctl_i,
		  reg_in(5) => dbg_eth_state,
		  reg_in(6) => eth_sdram_complete_address(31 downto 16),
		  reg_in(7) => eth_sdram_complete_address(15 downto 0),
		  reg_in(8) => sdram_buffer_empty & dbg_dac_state(14 downto 0),
		  reg_in(9) => dac_sdram_address(31 downto 16),
		  reg_in(10) => dac_sdram_address(15 downto 0),
		  reg_in(11) => dbg_sdram_bus_state,
		  reg_in(12) => X"00" & sdram_size_avail(23 downto 16),
		  reg_in(13) => sdram_size_avail(15 downto 0),
		  reg_in(14) => X"0000", -- Unused
		  reg_in(15) => X"0000", -- Unused
		  reg_in(16) => X"0000", -- Unused
		  reg_in(17) => X"0000", -- Unused
		  reg_in(18) => X"0000", -- Unused
		  reg_in(19) => dbg_sram_read_addr,
		  reg_in(20) => dbg_sram_write_addr,
		  reg_in(21) => dbg_eth_next_sequence,
		  reg_in(22) => X"0000", -- Unused
		  reg_in(23) => dbg_ip_ident,
		  reg_in(24) => dbg_ip_frag_offset,
		  reg_in(25) => X"0000", -- Unused
		  reg_in(26) => X"0000"  -- Unused
	 );


-- SDRAM addressing is 25 bits total... HOWEVER

-- Lowest bit is always ignored by controller
-- (did they want addresses to represent 8 bytes at a time?)

-- Second bit is always ignored by controller for same reason

-- The rest of the bits are your normal addresses

-- If using 16-bit data, caller needs to check addr(1) and
-- if so, present data at 31:16, setting bitmask to "1100"

sdram_controller : sdram
	port map(
		clk_i => sys_clk,
		rst_i => sys_reset,
		stb_i => sdram_strobe,
		we_i => sdram_write,
		sel_i => sdram_bitmask,
		cyc_i => sdram_cycle,
		addr_i => sdram_address,
		data_i => sdram_writedata,
		data_o => sdram_readdata,
		stall_o => sdram_stall,
		ack_o => sdram_ack,
		
		sdram_clk_o => SDRAM_CLK,
		sdram_cke_o => SDRAM_CKE,
		sdram_cs_o => open,
		sdram_ras_o => SDRAM_nRAS,
		sdram_cas_o => SDRAM_nCAS,
		sdram_we_o => SDRAM_nWE,
		sdram_dqm_o => SDRAM_DQM,
		sdram_addr_o => SDRAM_ADDR,
		sdram_ba_o => SDRAM_BA,
		sdram_data_io => SDRAM_DQ
	);



ethernet_controller : entity work.ethernet
   generic map(
	   SDRAM_BUFFER_SIZE => SDRAM_BUFFER_SIZE
	)
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		
		spi_clk => PMOD1(3),
		spi_mosi => PMOD1(1),
		spi_miso => PMOD1(2),
		spi_cs => PMOD1(0),
		eth_int_i => PMOD1(4),
		
		sdram_cycle => eth_sdram_cycle,
		sdram_strobe => eth_sdram_strobe,
		sdram_writedata => eth_sdram_writedata,
		sdram_address => eth_sdram_address,
		sdram_bitmask => eth_sdram_bitmask,
		sdram_ack => eth_sdram_ack,
		
		sdram_complete_address => eth_sdram_complete_address,
		sdram_size_avail => sdram_size_avail,
		sdram_empty => sdram_buffer_empty,
		
		cmd_mute => cmd_mute,
		cmd_pause => cmd_pause,
		cmd_reset_dac => cmd_reset_dac,
		cmd_user_sig => user_sig,
		cmd_freq_select => cmd_freq_select,
		
		volume_left_woofer_o => volume_left_woofer,
		volume_left_lowmid_o => volume_left_lowmid,
		volume_left_uppermid_o => volume_left_uppermid,
		volume_left_tweeter_o => volume_left_tweeter,
		volume_right_woofer_o => volume_right_woofer,
		volume_right_lowmid_o => volume_right_lowmid,
		volume_right_uppermid_o => volume_right_uppermid,
		volume_right_tweeter_o => volume_right_tweeter,
		
		audioclk_warning => audioclk_warning_o,
		audioclk_warning_rst => audioclk_warning_rst,
		
		dbg_state => dbg_eth_state,
		dbg_next_sequence => dbg_eth_next_sequence,
		dbg_ip_ident => dbg_ip_ident,
		dbg_ip_frag_offset => dbg_ip_frag_offset,
		
		led_o => LED(1),
		
		use_dhcp_i => SW(1)
	);



dac_controller : entity work.dac_controller
   generic map(
	   SDRAM_BUFFER_SIZE => SDRAM_BUFFER_SIZE,
		SRAM_ADDR_SIZE => 13
	)
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		
		dac_clk_oe => dac_clk_oe,
		audioclk => audioclk_selected,
		
		bitclk_o => dac_bitclk_o,
		lrclk_o => dac_lrclk_o,
		
		dac_left_tweeter_o => dac_left_tweeter_data,
		dac_left_uppermid_o => dac_left_uppermid_data,
		dac_left_lowmid_o => dac_left_lowmid_data,
		dac_left_woofer_o => dac_left_woofer_data,
		dac_right_tweeter_o => dac_right_tweeter_data,
		dac_right_uppermid_o => dac_right_uppermid_data,
		dac_right_lowmid_o => dac_right_lowmid_data,
		dac_right_woofer_o => dac_right_woofer_data,
		
		sdram_cycle => dac_sdram_cycle,
		sdram_strobe => dac_sdram_strobe,
		sdram_readdata => dac_sdram_readdata,
		sdram_address => dac_sdram_address,
		sdram_bitmask => dac_sdram_bitmask,
		sdram_ack => dac_sdram_ack,
		
		mute_o => dac_mute,
		sdram_buffer_empty => sdram_buffer_empty,
		sdram_buffer_below_minimum => sdram_buffer_below_minimum,
		
		cmd_mute => cmd_mute,
		cmd_pause => cmd_pause,
		cmd_reset_dac => cmd_reset_dac,
		cmd_freq_select => cmd_freq_select,
		
		volume_left_woofer_i => volume_left_woofer,
		volume_left_lowmid_i => volume_left_lowmid,
		volume_left_uppermid_i => volume_left_uppermid,
		volume_left_tweeter_i => volume_left_tweeter,
		volume_right_woofer_i => volume_right_woofer,
		volume_right_lowmid_i => volume_right_lowmid,
		volume_right_uppermid_i => volume_right_uppermid,
		volume_right_tweeter_i => volume_right_tweeter,
		
		dbg_state => dbg_dac_state,
		dbg_sram_read_addr => dbg_sram_read_addr,
		dbg_sram_write_addr => dbg_sram_write_addr
	);


-- Connecting signals to ports
PMOD4(0) <= dac_lrclk_o;
PMOD4(1) <= dac_bitclk_o;

PMOD4(4) <= dac_mute;
PMOD4(5) <= user_sig;
PMOD4(6) <= idle_sig;
PMOD4(7) <= not audioclk_warning_o;

PMOD3(0) <= dac_left_woofer_data;
PMOD3(1) <= dac_right_woofer_data;
PMOD3(2) <= dac_left_lowmid_data;
PMOD3(3) <= dac_right_lowmid_data;
PMOD3(4) <= dac_left_uppermid_data;
PMOD3(5) <= dac_right_uppermid_data;
PMOD3(6) <= dac_left_tweeter_data;
PMOD3(7) <= dac_right_tweeter_data;

-- PMOD1_10_ARD_D5
BUFG_16m : BUFG port map (O => audioclk,    I => PMOD1(7));

clk16M_mux : BUFGMUX
generic map (
	CLK_SEL_TYPE => "SYNC"  -- Glitchles ("SYNC") or fast ("ASYNC") clock switch-over
)
port map (
	O => audioclk_selected,   -- 1-bit output: Clock buffer output
	I0 => clk16Mgen, -- 1-bit input: Clock buffer input (S=0)
	I1 => audioclk, -- 1-bit input: Clock buffer input (S=1)
	S => dac_clk_oe    -- 1-bit input: Clock buffer select
);

audio_clkgen : entity work.audio_clkgen
port map (
  clk_in => osc_buff,
  cllk_16m => clk16Mgen,
  sys_reset => sys_reset,
  pll_locked => open
 );

	
PLL_BASE_inst : PLL_BASE generic map (
      BANDWIDTH      => "OPTIMIZED",        -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT  => 12 ,                 -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output (0.0-360.0).
      CLKIN_PERIOD   => 20.00,              -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 6,       CLKOUT1_DIVIDE =>1,
      CLKOUT2_DIVIDE => 1,       CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,       CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5, CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5, CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5, CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE => 0.0,      CLKOUT1_PHASE => 0.0, -- Capture clock
      CLKOUT2_PHASE => 0.0,      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,      CLKOUT5_PHASE => 0.0,
      
      CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
      REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
   ) port map (
      CLKFBOUT => clkfb, -- 1-bit output: PLL_BASE feedback output
      -- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      CLKOUT0 => clk_100Mhz_pll,      CLKOUT1 => open,
      CLKOUT2 => open,      CLKOUT3 => open,
      CLKOUT4 => open,      CLKOUT5 => open,
      LOCKED  => clock_locked,  -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => clkfb, -- 1-bit input: Feedback clock input
      CLKIN   => osc_buff,  -- 1-bit input: Clock input
      RST     => '0'    -- 1-bit input: Reset input
   );

    -- Buffering of clocks
	BUFG_1 : BUFG port map (O => osc_buff,    I => OSC_FPGA);
	BUFG_2 : BUFG port map (O => clk_100Mhz,    I => clk_100Mhz_pll);
	

end Behavioral;

