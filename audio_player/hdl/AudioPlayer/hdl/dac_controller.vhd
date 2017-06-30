----------------------------------------------------------------------------------
--
-- This file contains two state machines:
--
-- 1. The state machine to read from SDRAM and write to SRAM (lower down)
--
-- 2. The stae machine to read from SRAM and generate the audio signals for
--    the DAC.
--
-- There is also lots of signal synchronization going on because we have two
-- clock domains here, the 100MHz system clock and the 16MHz audio clock.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_controller is
    generic (SRAM_ADDR_SIZE : positive := 14);
    Port ( sys_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
			  
           clk16M : in  STD_LOGIC;
           dac_clk_oe : in  STD_LOGIC;
			  
			  bitclk_o : out   STD_LOGIC;
			  lrclk_o : out   STD_LOGIC;
			  
           dac_left_tweeter_o : out  STD_LOGIC;
           dac_left_uppermid_o : out  STD_LOGIC;
           dac_left_lowmid_o : out  STD_LOGIC;
           dac_left_woofer_o : out  STD_LOGIC;
           dac_right_tweeter_o : out  STD_LOGIC;
           dac_right_uppermid_o : out  STD_LOGIC;
           dac_right_lowmid_o : out  STD_LOGIC;
           dac_right_woofer_o : out  STD_LOGIC;
			  mute_o : out  STD_LOGIC;
			  
           sdram_cycle : out STD_LOGIC;
           sdram_strobe : out STD_LOGIC;
           sdram_readdata : in STD_LOGIC_VECTOR (31 downto 0);
           sdram_address : out STD_LOGIC_VECTOR (31 downto 0);
			  sdram_bitmask : out STD_LOGIC_VECTOR(3 downto 0);
           sdram_ack : in  STD_LOGIC;
			  
			  sdram_buffer_empty : in STD_LOGIC;
			  sdram_buffer_below_minimum : in STD_LOGIC;
			  
			  cmd_mute : in STD_LOGIC;
			  cmd_pause : in STD_LOGIC;
			  
			  dbg_state : out STD_LOGIC_VECTOR(15 downto 0);
			  dbg_sram_read_addr : out STD_LOGIC_VECTOR(15 downto 0);
			  dbg_sram_write_addr : out STD_LOGIC_VECTOR(15 downto 0)
			  
			  );
end dac_controller;

architecture Behavioral of dac_controller is

	-- 2MB (multiply value by 4 because 32-bit aligned)
	constant SDRAM_BUFFER_SIZE : std_logic_vector(23 downto 0) := X"080000";
	

	signal sram_read_reset_i : std_logic;
	signal sram_read_reset_o : std_logic;
	

	signal clk16M_count : std_logic_vector(8 downto 0);
	
	signal lrclk_i : std_logic;
	signal bitclk_i : std_logic;
	
	

	signal need_mute : std_logic;
	
	signal left_tweeter_load_reg : std_logic_vector(19 downto 0);
	signal left_lowmid_load_reg : std_logic_vector(19 downto 0);
	signal left_uppermid_load_reg : std_logic_vector(19 downto 0);
	signal left_woofer_load_reg : std_logic_vector(19 downto 0);
	signal right_tweeter_load_reg : std_logic_vector(19 downto 0);
	signal right_lowmid_load_reg : std_logic_vector(19 downto 0);
	signal right_uppermid_load_reg : std_logic_vector(19 downto 0);
	signal right_woofer_load_reg : std_logic_vector(19 downto 0);
	
	signal left_tweeter_shift_reg : std_logic_vector(19 downto 0);
	signal left_lowmid_shift_reg : std_logic_vector(19 downto 0);
	signal left_uppermid_shift_reg : std_logic_vector(19 downto 0);
	signal left_woofer_shift_reg : std_logic_vector(19 downto 0);
	signal right_tweeter_shift_reg : std_logic_vector(19 downto 0);
	signal right_lowmid_shift_reg : std_logic_vector(19 downto 0);
	signal right_uppermid_shift_reg : std_logic_vector(19 downto 0);
	signal right_woofer_shift_reg : std_logic_vector(19 downto 0);
	
	signal sram_write_addr : std_logic_vector(SRAM_ADDR_SIZE-1 downto 0) := (others => '0');
	signal sram_write_addr_16m : std_logic_vector(SRAM_ADDR_SIZE-1 downto 0) := (others => '0');
	signal sram_read_addr : std_logic_vector(SRAM_ADDR_SIZE-1 downto 0) := (others => '1');
	signal sram_read : std_logic;
	signal sram_write : std_logic;
	
	signal sram_data_in : std_logic_vector(31 downto 0);
	signal sram_data_out : std_logic_vector(31 downto 0);
	
	signal sram_buff_need_more_i : std_logic;
	signal sram_buff_need_more_16_i : std_logic;
	signal sram_buff_need_more_o : std_logic;
	signal sram_buff_need_more_rst : std_logic;
	
	signal sdram_read_ptr : std_logic_vector(23 downto 0) := SDRAM_BUFFER_SIZE - 1;
	signal sdram_data_reg : std_logic_vector(31 downto 0);
	
	signal sdram_timeout_counter : std_logic_vector(7 downto 0);
	
	signal dbg_count : std_logic_vector(7 downto 0);
	
	type BUFFER_STATES is (
		INIT, INIT_WAIT_ACK,
		INIT_SRAM_WRITE, INIT_SRAM_WRITE_DONE,
		INIT_NEXT_SDRAM_READ, INIT_WAIT_SDRAM_FILL,
		INIT_WAIT_SRAM_STARTING,
		
		IDLE, SDRAM_START_READ, SDRAM_HAVE_ACK,
		SRAM_WRITE_DONE, SDRAM_NOT_EMPTY,
		
		ERROR
	);
	
	signal buffer_state : BUFFER_STATES := INIT;
	
	
	type DAC_REG is (
		LEFT_WOOFER, RIGHT_WOOFER,
		LEFT_LOWMIDRANGE, RIGHT_LOWMIDRANGE,
		LEFT_UPPERMIDRANGE, RIGHT_UPPERMIDRANGE,
		LEFT_TWEETER, RIGHT_TWEETER
	);
	
	constant NUMBER_OF_CHANNELS : integer := 8;
	
	signal next_dac_load_reg : DAC_REG := LEFT_WOOFER;
	
	signal sample_count_in_frame : integer range 0 to 7;
	
	
	signal sram_buffer_empty_16m : std_logic;
	signal sram_buffer_empty_100m : std_logic;
	
	signal cmd_pause_16m : std_logic;
	
	signal sys_clk_slow : std_logic;
	signal clk16M_slow : std_logic;

begin
	
	-- Conditions for when we should output zeros to the DACs (and used for an LED)
	need_mute <= '1' when cmd_mute = '1' or cmd_pause = '1' or sram_buffer_empty_16m = '1' else '0';

	mute_o <= need_mute;
	
	--dbg_sram_read_addr <= "00" & sram_read_addr_100m;
	dbg_sram_read_addr <= X"0000";
	dbg_sram_write_addr <= "00" & sram_write_addr;
	
	-- Slower versions of clocks to help with signal synchronizer circuits
	process (sys_clk)
	begin
		if rising_edge(sys_clk) then
			sys_clk_slow <= not sys_clk_slow;
		end if;
	end process;
	
	process (clk16M)
	begin
		if rising_edge(clk16M) then
			clk16M_slow <= not clk16M_slow;
		end if;
	end process;
	
	--
	-- Signal synchronizers
	--
	
	-- TODO: A bus version of this?
	--syncsignal_sram_write_addr_16m : entity work.syncsignal
	--port map(
	--	target_clk => clk16M,
	--	sys_reset => sys_reset,
	--	sig_i => sram_write_addr,
	--	sig_o => sram_write_addr_16m
	--);
	
	process (clk16M)
	begin
		if rising_edge(clk16M) then
			sram_write_addr_16m <= sram_write_addr;
		end if;
	end process;

	syncsignal_cmd_pause_16m : entity work.syncsignal
	port map(
		target_clk => clk16M,
		sys_reset => sys_reset,
		sig_i => cmd_pause,
		sig_o => cmd_pause_16m
	);

	syncsignal_read_reset : entity work.syncsignal
	port map(
		target_clk => clk16M,
		sys_reset => sys_reset,
		sig_i => sram_read_reset_i,
		sig_o => sram_read_reset_o
	);

	syncsignal_sram_buff_need_more_i : entity work.syncsignal
	port map(
		target_clk => sys_clk_slow,
		sys_reset => sys_reset,
		sig_i => sram_buff_need_more_16_i,
		sig_o => sram_buff_need_more_i
	);

	syncsignal_sram_buffer_empty_100m : entity work.syncsignal
	port map(
		target_clk => sys_clk_slow,
		sys_reset => sys_reset,
		sig_i => sram_buffer_empty_16m,
		sig_o => sram_buffer_empty_100m
	);




	-- Synchronous comparison of sram_read and write pointers
	-- to genenerate sram_buffer_empty signal
	process(clk16M)
	begin
		if rising_edge(clk16M) then
			if sram_read_addr = (sram_write_addr_16m - 1) then
				sram_buffer_empty_16m <= '1';
			else
				sram_buffer_empty_16m <= '0';
			end if;
		end if;
	end process;
	
	
	
	
	bitclk_o <= bitclk_i;
	lrclk_o <= lrclk_i;
	
	-- AND gates on the final output data lines to DACs
	dac_left_tweeter_o <= '0' when need_mute = '1' else left_tweeter_shift_reg(19);
	dac_left_uppermid_o <= '0' when need_mute = '1' else left_uppermid_shift_reg(19);
	dac_left_lowmid_o <= '0' when need_mute = '1' else left_lowmid_shift_reg(19);
	dac_left_woofer_o <= '0' when need_mute = '1' else left_woofer_shift_reg(19);
	dac_right_tweeter_o <= '0' when need_mute = '1' else right_tweeter_shift_reg(19);
	dac_right_uppermid_o <= '0' when need_mute = '1' else right_uppermid_shift_reg(19);
	dac_right_lowmid_o <= '0' when need_mute = '1' else right_lowmid_shift_reg(19);
	dac_right_woofer_o <= '0' when need_mute = '1' else right_woofer_shift_reg(19);
	



	-- Main state machine to generate audio signals.
	-- 
	-- 1. Reduce 16.9344 MHz input clock down to bitclk and lrclk
	-- 2. Reads data from SRAM and loads in to shift registers at the right time
	-- 3. Shifts data out of shift registers in synch with bitclk and lrclk
	-- 
	process(clk16M, sys_reset)
	begin

		if sys_reset = '1' then
			clk16M_count <= (others => '0');
			bitclk_i <= '0';
			lrclk_i <= '0';
			left_tweeter_shift_reg <= (others => '0');
			left_uppermid_shift_reg <= (others => '0');
			left_woofer_shift_reg <= (others => '0');
			right_tweeter_shift_reg <= (others => '0');
			right_uppermid_shift_reg <= (others => '0');
			right_woofer_shift_reg <= (others => '0');
			left_tweeter_load_reg <= (others => '0');
			left_uppermid_load_reg <= (others => '0');
			left_lowmid_load_reg <= (others => '0');
			left_woofer_load_reg <= (others => '0');
			right_tweeter_load_reg <= (others => '0');
			right_uppermid_load_reg <= (others => '0');
			right_lowmid_load_reg <= (others => '0');
			right_woofer_load_reg <= (others => '0');
			sram_read <= '0';
			sram_read_addr <= (others => '1');
			sram_buff_need_more_16_i <= '0';
			next_dac_load_reg <= LEFT_WOOFER;
		elsif rising_edge(clk16M) then
			
			-- By default don't read from SRAM
			sram_read <= '0';
			
			sram_buff_need_more_16_i <= '0';
			
			if clk16M_count = 383 then
				clk16M_count <= (others => '0');
			else
				clk16M_count <= clk16M_count + 1;
			end if;
			
			-- bitclk
			if (clk16M_count(3 downto 0) = 0) then
				bitclk_i <= '0';
			end if;
			if (clk16M_count(3 downto 0) = 8) then
				bitclk_i <= '1';
			end if;
			
			-- lrclk
			if (clk16M_count = 192) then
				lrclk_i <= '1';
			end if;
			if (clk16M_count = 0) then
				lrclk_i <= '0';
			end if;
			
			-- Held in synchronous 'reset' state by the other state machine below
			if sram_read_reset_o = '1' then
				
				left_woofer_shift_reg <= (others => '0');
				right_woofer_shift_reg <= (others => '0');
				left_lowmid_shift_reg <= (others => '0');
				right_lowmid_shift_reg <= (others => '0');
				left_uppermid_shift_reg <= (others => '0');
				right_uppermid_shift_reg <= (others => '0');
				left_tweeter_shift_reg <= (others => '0');
				right_tweeter_shift_reg <= (others => '0');
				
				sram_read <= '0';
				sram_read_addr <= (others => '1');
				
			else
			
				-- Shift register shifts on falling edge of bitclk
				if clk16M_count = 80 or clk16M_count = 96 or clk16M_count = 112 or clk16M_count = 128
					or clk16M_count = 144 or clk16M_count = 160 or clk16M_count = 176
					or clk16M_count = 192 or clk16M_count = 208 or clk16M_count = 224
					or clk16M_count = 240 or clk16M_count = 256 or clk16M_count = 272
					or clk16M_count = 288 or clk16M_count = 304 or clk16M_count = 320
					or clk16M_count = 336 or clk16M_count = 352 or clk16M_count = 368 then
					
					left_woofer_shift_reg(19 downto 0) <= left_woofer_shift_reg(18 downto 0) & "0";
					right_woofer_shift_reg(19 downto 0) <= right_woofer_shift_reg(18 downto 0) & "0";
					left_lowmid_shift_reg(19 downto 0) <= left_lowmid_shift_reg(18 downto 0) & "0";
					right_lowmid_shift_reg(19 downto 0) <= right_lowmid_shift_reg(18 downto 0) & "0";
					left_uppermid_shift_reg(19 downto 0) <= left_uppermid_shift_reg(18 downto 0) & "0";
					right_uppermid_shift_reg(19 downto 0) <= right_uppermid_shift_reg(18 downto 0) & "0";
					left_tweeter_shift_reg(19 downto 0) <= left_tweeter_shift_reg(18 downto 0) & "0";
					right_tweeter_shift_reg(19 downto 0) <= right_tweeter_shift_reg(18 downto 0) & "0";
					
				end if; -- Shift registers
				
				
				-- Generate SRAM read signal and increment read address
				if cmd_pause_16m = '0' and sram_buffer_empty_16m = '0' and clk16M_count < 8 then
					
					-- Get next data from sram
					sram_read_addr <= sram_read_addr + 1;
					sram_read <= '1';
					
					-- TODO: this could be signaled one cycle earlier, considering the addr+1 above
					--if sram_read_addr(SRAM_ADDR_SIZE-2 downto 0) = std_logic_vector(to_unsigned(0, SRAM_ADDR_SIZE-1)) then
					if sram_read_addr(SRAM_ADDR_SIZE-2 downto 0) = X"0000" then
						sram_buff_need_more_16_i <= '1';
					end if;
						
				end if; -- SRAM read strobe and address
				
				
				-- Capture output of SRAM
				if cmd_pause_16m = '0' and sram_buffer_empty_16m = '0' and clk16M_count > 0 and clk16M_count < 9 then
					
					if next_dac_load_reg = LEFT_WOOFER or sram_data_out(31) = '1' then
						
						left_woofer_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= RIGHT_WOOFER;
						
						-- When this state machine first starts, it will read SRAM address zero
						-- where the left woofer sample should be stored.  The line below will
						-- have no effect because count will be set to 2 as well.
						-- If the state machine below and this one get out of sync, then
						-- this line will force this state machine to get back in sync.
						clk16M_count <= std_logic_vector(to_unsigned(2, clk16M_count'length));
					
					elsif next_dac_load_reg = RIGHT_WOOFER then
						
						right_woofer_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= LEFT_LOWMIDRANGE;
					
					elsif next_dac_load_reg = LEFT_LOWMIDRANGE then
						
						left_lowmid_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= RIGHT_LOWMIDRANGE;
					
					elsif next_dac_load_reg = RIGHT_LOWMIDRANGE then
						
						right_lowmid_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= LEFT_UPPERMIDRANGE;
					
					elsif next_dac_load_reg = LEFT_UPPERMIDRANGE then
						
						left_uppermid_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= RIGHT_UPPERMIDRANGE;
					
					elsif next_dac_load_reg = RIGHT_UPPERMIDRANGE then
						
						right_uppermid_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= LEFT_TWEETER;
					
					elsif next_dac_load_reg = LEFT_TWEETER then
						
						left_tweeter_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= RIGHT_TWEETER;
					
					elsif next_dac_load_reg = RIGHT_TWEETER then
						
						right_tweeter_load_reg <= sram_data_out(23 downto 4);
						next_dac_load_reg <= LEFT_WOOFER;
					
					end if;
					
				end if; -- SRAM read capture
				
				
				-- TODO: Technically this is 1 clock cycle later than we should,
				-- as bitclk changes at 8 above
				
				-- Load shift registers.  Could also be state 64, which would cause
				-- zeros to be shifted in at first rather than repeating the MSB
				if clk16M_count = 9 then
					
					left_woofer_shift_reg <= left_woofer_load_reg;
					right_woofer_shift_reg <= right_woofer_load_reg;
					left_lowmid_shift_reg <= left_lowmid_load_reg;
					right_lowmid_shift_reg <= right_lowmid_load_reg;
					left_uppermid_shift_reg <= left_uppermid_load_reg;
					right_uppermid_shift_reg <= right_uppermid_load_reg;
					left_tweeter_shift_reg <= left_tweeter_load_reg;
					right_tweeter_shift_reg <= right_tweeter_load_reg;
					
				end if;
				
			end if; -- not read_reset
			
		end if;

	end process;
	
	
	
	
	
	sdram_address <= "000000" & sdram_read_ptr & "00";
	sdram_bitmask <= "1111";
	
	
	-- Main state machine to read data from SDRAM and write to SRAM
	process(sys_clk, sys_reset)
	begin
		if sys_reset = '1' then
			buffer_state <= INIT;
			dbg_state <= X"0000";
			sdram_read_ptr <= SDRAM_BUFFER_SIZE - 1;
			sdram_data_reg <= X"00000000";
			sram_write <= '0';
			sram_write_addr <= (others => '0');
			sram_data_in <= (others => '0');
			sram_read_reset_i <= '1';
			sram_buff_need_more_rst <= '0';
			dbg_count <= (others => '0');
			sample_count_in_frame <= 0;
		elsif rising_edge(sys_clk) then
			
			sram_buff_need_more_rst <= '0';
			
			dbg_state(14) <= sram_buffer_empty_100m;
			dbg_state(7 downto 0) <= dbg_count;
			
			case buffer_state is
			
				when INIT =>
					-- Need to fill entire buffer
					dbg_state(11 downto 8) <= X"1";
					
					dbg_count <= dbg_count + 1;
					
					sram_write_addr <= (others => '0');
					sram_read_reset_i <= '1';
					
					sdram_cycle <= '0';
					
					if sdram_buffer_below_minimum = '0' then
						-- Start read
						sdram_cycle <= '1';
						sdram_strobe <= '1';
						
						buffer_state <= INIT_WAIT_ACK;
					end if;
				
				when INIT_WAIT_ACK =>
					dbg_state(11 downto 8) <= X"2";
				
					if sdram_ack = '1' then
						
						-- Capture result
						sdram_data_reg <= sdram_readdata;
						
						buffer_state <= INIT_SRAM_WRITE;
						
					end if;
					
				when INIT_SRAM_WRITE =>
					dbg_state(11 downto 8) <= X"3";
					
					-- Done read
					sdram_cycle <= '0';
					sdram_strobe <= '0';
					
					-- Next address for later
					sdram_read_ptr <= sdram_read_ptr + 1;
					
					if sdram_read_ptr = (SDRAM_BUFFER_SIZE-1) then
						sdram_read_ptr <= X"000000";
					end if;
					
					sram_write <= '1';
					
					sram_data_in <= sdram_data_reg;
					
					-- SDRAM(31) is set at the start of the data stream, so update
					-- our sample_count to match.
					-- Likewise, when sample_count is zero we set SRAM(31) so that
					-- the reader state machine can sync to the left woofer register
					if sdram_data_reg(31) = '1' or sample_count_in_frame = 0 then
						sample_count_in_frame <= 1;
						sram_data_in(31) <= '1';
					elsif sample_count_in_frame = NUMBER_OF_CHANNELS-1 then
						sample_count_in_frame <= 0;
					else
						sample_count_in_frame <= sample_count_in_frame + 1;
					end if;
					
					buffer_state <= INIT_SRAM_WRITE_DONE;
					
				when INIT_SRAM_WRITE_DONE =>
					dbg_state(11 downto 8) <= X"4";
					
					sram_write <= '0';
					sram_write_addr <= sram_write_addr + 1;
					
					-- Stop when we wrap hit address 7FFD
					-- (7FFE after the increment above)
					-- (we need to be 2 addresses back because we always write 2 words at at time)
					if sram_write_addr(SRAM_ADDR_SIZE-1 downto 0) = std_logic_vector(to_unsigned((2**SRAM_ADDR_SIZE)-3, SRAM_ADDR_SIZE)) then
						buffer_state <= INIT_WAIT_SDRAM_FILL;
					else
						buffer_state <= INIT_NEXT_SDRAM_READ;
					end if;
					
				when INIT_NEXT_SDRAM_READ =>
					dbg_state(11 downto 8) <= X"7";
					
					if sdram_buffer_empty = '0' then
						-- Start read
						sdram_cycle <= '1';
						sdram_strobe <= '1';
						
						buffer_state <= INIT_WAIT_ACK;
					end if;
					
				when INIT_WAIT_SDRAM_FILL =>
					dbg_state(11 downto 8) <= X"8";
					
					if sdram_buffer_below_minimum = '0' then
						sram_read_reset_i <= '0';
						buffer_state <= INIT_WAIT_SRAM_STARTING;
					end if;
					
				when INIT_WAIT_SRAM_STARTING =>
					-- Now the lrclk is running and sram_read_addr is 7FFF
					-- The first read will cause it to be 0000, which will trigger
					-- sram_buff_need_more.  We need to ignore that the first time
					-- since we know that we just filled the SRAM.
				
					dbg_state(11 downto 8) <= X"9";
					
					if sram_buff_need_more_o = '1' then
						sram_buff_need_more_rst <= '1';
						buffer_state <= IDLE;
					end if;
					
					
					
					
					
				when IDLE =>
					dbg_state(11 downto 8) <= X"A";
					
					sdram_cycle <= '0';
				
					-- If sram was emptied, then reset the SRAM buffer and reload it completely
					if sram_buffer_empty_100m = '1' then
						sram_read_reset_i <= '1';
						buffer_state <= INIT;
					-- More data available in SDRAM and SRAM pointer wrapped around to next half
					elsif sdram_buffer_empty = '0' and sram_buff_need_more_o = '1' then
						sram_buff_need_more_rst <= '1';
						sdram_timeout_counter <= (others => '0');
						buffer_state <= SDRAM_START_READ;
					end if;
					
				when SDRAM_START_READ =>
					dbg_state(11 downto 8) <= X"B";
					
					-- Start read
					sdram_cycle <= '1';
					sdram_strobe <= '1';
					
					if sdram_ack = '1' then
						
						-- Capture result
						sdram_data_reg <= sdram_readdata;
						
						buffer_state <= SDRAM_HAVE_ACK;
						
					end if;
					
					--sdram_timeout_counter <= sdram_timeout_counter + 1;
					
					--if sdram_timeout_counter = X"FF" then
					--	sram_read_reset_i <= '1';
					--	sdram_cycle <= '0';
					--	sdram_strobe <= '0';
					--	buffer_state <= INIT;
					--end if;
					
				when SDRAM_HAVE_ACK =>
					dbg_state(11 downto 8) <= X"C";
					
					-- Done read
					sdram_strobe <= '0';
					
					-- Next address for later
					sdram_read_ptr <= sdram_read_ptr + 1;
					
					if sdram_read_ptr = (SDRAM_BUFFER_SIZE-1) then
						sdram_read_ptr <= X"000000";
					end if;
					
					sram_write <= '1';
					
					sram_data_in <= sdram_data_reg;
					
					-- SDRAM(31) is set at the start of the data stream, so update
					-- our sample_count to match.
					-- Likewise, when sample_count is zero we set SRAM(31) so that
					-- the reader state machine can sync to the left woofer register
					if sdram_data_reg(31) = '1' or sample_count_in_frame = 0 then
						sample_count_in_frame <= 1;
						sram_data_in(31) <= '1';
					elsif sample_count_in_frame = NUMBER_OF_CHANNELS-1 then
						sample_count_in_frame <= 0;
					else
						sample_count_in_frame <= sample_count_in_frame + 1;
					end if;
					
					buffer_state <= SRAM_WRITE_DONE;
					
				when SRAM_WRITE_DONE =>
					dbg_state(11 downto 8) <= X"D";
					
					sram_write <= '0';
					
					sram_write_addr <= sram_write_addr + 1;
					
					-- Since we are reading 32-bit values, we have one less address
					-- line to check
					if sram_write_addr(SRAM_ADDR_SIZE-2 downto 0) = std_logic_vector(to_unsigned(2**(SRAM_ADDR_SIZE-1)-3, SRAM_ADDR_SIZE-1)) then
						
						-- Done with SDRAM
						sdram_cycle <= '0';
						
						buffer_state <= IDLE;
						
					else
						
						sdram_timeout_counter <= (others => '0');
						
						buffer_state <= SDRAM_NOT_EMPTY;
						
					end if;
					
				when SDRAM_NOT_EMPTY =>
					dbg_state(11 downto 8) <= X"E";
					
					-- It takes one extra cycle for sdram_buffer_empty to be updated, so we
					-- cannot check it in the state above
					
					if sdram_buffer_empty = '0' then
						sdram_timeout_counter <= (others => '0');
						buffer_state <= SDRAM_START_READ;
					else
						-- Release SDRAM so it can be filled again
						sdram_cycle <= '0';
					end if;
					
					-- If SDRAM doesn't fill in time then abort
					if sram_buffer_empty_100m = '1' then
						sram_read_reset_i <= '1';
						sdram_cycle <= '0';
						sdram_strobe <= '0';
						buffer_state <= INIT;
					end if;
					
					
				when ERROR =>
					
					dbg_state <= X"FFFF";
					
	--			when others =>
	--				dbg_state <= X"FFFF";
				
	--				buffer_state <= INIT;

			end case;
			
		end if;
	end process;
	
	
	-- Dual port SRAM
	sram_audio_data : entity work.dpram
	generic map (
		DATA_WIDTH => 32,
		RAM_WIDTH => SRAM_ADDR_SIZE
	)
	port map(
		wr_clk => sys_clk,
		rd_clk => clk16M,
		rst => sys_reset,
		din => sram_data_in,
		wr_en => sram_write,
		rd_en => sram_read,
		wr_addr => sram_write_addr,
		rd_addr => sram_read_addr,
		dout => sram_data_out
	);
	
	intreg_sram : entity work.interrupt_reg
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		int_i => sram_buff_need_more_i,
		int_o => sram_buff_need_more_o,
		rst_i => sram_buff_need_more_rst
	);
	
	

end Behavioral;

