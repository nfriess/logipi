----------------------------------------------------------------------------------
-- 
-- SPI master controller
--
-- Generates signals to follow SPI protocol, such as to drive another chip.
-- The internal interface is a wishbone-style bus where the other module will
-- act as a master.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity spimaster is
    Port ( sys_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
           data_i : in  STD_LOGIC_VECTOR (31 downto 0);
           data_o : out  STD_LOGIC_VECTOR (31 downto 0);
           data_cnt_i : in  STD_LOGIC_VECTOR (2 downto 0);
           cyc_i : in  STD_LOGIC;
			  stb_i : in  STD_LOGIC;
           ack_o : out  STD_LOGIC;
			  
			  spi_clk : out STD_LOGIC;
			  spi_miso : in STD_LOGIC;
			  spi_mosi : out STD_LOGIC;
			  spi_cs : out STD_LOGIC;
			  
			  dbg_state : out STD_LOGIC_VECTOR(15 downto 0)
			  
			);
end spimaster;

architecture Behavioral of spimaster is

	signal shift_in : STD_LOGIC_VECTOR (31 downto 0);
	signal shift_out : STD_LOGIC_VECTOR (31 downto 0);
	signal clk_count : STD_LOGIC_VECTOR(1 downto 0);
	signal bit_count : STD_LOGIC_VECTOR(2 downto 0);
	signal data_count : STD_LOGIC_VECTOR(2 downto 0);
	
	signal ack : STD_LOGIC;
	
	signal spi_clk_internal : STD_LOGIC;
	signal spi_clk_en : STD_LOGIC;
	
	signal clk_count_reset : STD_LOGIC;
	signal clk_reset : STD_LOGIC;
	
	signal stb_rising_edge : STD_LOGIC;
	signal stb_clear : STD_LOGIC;
	
	signal cyc_inv : STD_LOGIC;
	signal cyc_falling_edge : STD_LOGIC;
	signal cyc_inv_clear : STD_LOGIC;
	
	signal saved_miso : STD_LOGIC;
	
	type STATES is (IDLE, WAIT_CS_SETUP, SHIFT, LASTRISING, LASTFALLING, WAIT_CS_HOLD, WAIT_CS_DISABLE, DONE);
	signal state : STATES := IDLE;

begin

	data_o <= shift_in;
	-- This likely causes issues with signals changing asynchronously
	--ack_o <= ack when cyc_i = '1' and stb_i = '1' else '0';
	ack_o <= ack;
	
	spi_clk <= spi_clk_internal and spi_clk_en;
	spi_mosi <= shift_out(31);
	
	clk_reset <= sys_reset OR clk_count_reset;
	
	-- spi_clk is 100mhz /8 = 12mhz
	process(sys_clk,clk_reset)
	begin
	
		if clk_reset = '1' then
			clk_count <= "00";
			spi_clk_internal <= '0';
		elsif rising_edge(sys_clk) then
		
			clk_count <= clk_count + 1;
			
			if clk_count = "00" then
				spi_clk_internal <= not spi_clk_internal;
			end if;
		
		end if;
	end process;
	
	
	process(sys_clk,sys_reset)
	begin
	
		if sys_reset = '1' then
		
			state <= IDLE;
			
			shift_in <= (others => '0');
			saved_miso <= '0';
			
			ack <= '0';
			
			spi_clk_en <= '0';
			spi_cs <= '1';
			
			clk_count_reset <= '0';
			
			data_count <= "000";
			
			stb_clear <= '0';
			cyc_inv_clear <= '0';
			
			dbg_state <= X"0000";
			
		elsif rising_edge(sys_clk) then
		
			dbg_state(15 downto 12) <= cyc_i & stb_i & ack & "0";
			
			stb_clear <= '0';
			cyc_inv_clear <= '0';
		
			case state is
			when IDLE =>
				
				dbg_state(11 downto 0) <= X"001";
				
				cyc_inv_clear <= '1';
				
				if cyc_i = '1' and stb_rising_edge = '1' then
				
					-- Clear rising edge register
					stb_clear <= '1';
					
					-- Capture data from inputs
					shift_out <= data_i;
					data_count <= data_cnt_i;
					
					-- Set cs active
					spi_cs <= '0';
					
					-- Reset counter for spi_clk
					clk_count_reset <= '1';
					
					state <= WAIT_CS_SETUP;
					bit_count <= "001"; -- 1 clock will elapse to get to next state
					
				end if;
				
				
			-- Wait 50ns for CS setup time, at 100mhz this is 5 clocks
			when WAIT_CS_SETUP =>
			
				dbg_state(11 downto 0) <= X"002";
				
				bit_count <= bit_count + 1;
				
				-- Will take 1 cycle to get to next state, so we start early
				if bit_count = "100" then
					
					-- Cancel reset on spi_clk
					clk_count_reset <= '0';
					
					-- Enable spi_clk output
					spi_clk_en <= '1';
					
					-- First bit is loaded into shift_reg already
					bit_count <= "001";
					
					state <= SHIFT;
					
				end if;
				
				
			-- Shift bits in/out
			when SHIFT =>
			
				dbg_state(11 downto 0) <= X"003";
				
				-- Falling edge of spi_clk
				if clk_count = "00" and spi_clk_internal = '1' then
				
					bit_count <= bit_count + 1;
					if bit_count = "111" then
						
						-- Done one byte
						data_count <= data_count - 1;
						
						-- and about to become zero
						if data_count = "001" then
							
							state <= LASTRISING;
							
						end if;
						
					end if;
					
					shift_out(31 downto 0) <= shift_out(30 downto 0) & "0";
					
				-- Rising edge of spi_clk
				elsif clk_count = "00" and spi_clk_internal = '0' then
					
					shift_in(31 downto 0) <= shift_in(30 downto 0) & spi_miso;
					
				end if;
				
				
			-- Wait for last rising edge, where either:
			-- !cyc_falling_edge && stb_rising_edge => start shifting again
			-- else quit
			when LASTRISING =>
				
				dbg_state(11 downto 0) <= X"004";
				
				if clk_count = "00" and spi_clk_internal = '0' then
					
					-- Signal ack now since we have all data sent and received
					ack <= '1';

					-- Shift the last bit in now
					shift_in(31 downto 0) <= shift_in(30 downto 0) & spi_miso;
					
					state <= LASTFALLING;
					
				end if;
				
			-- Wait for last rising edge.  We should have set up the next
			-- input bit, but we can still do so up until 10ns before rising
			-- edge of spi_clk
			when LASTFALLING =>
				
				dbg_state(11 downto 0) <= X"005";
				
				if clk_count = "00" and spi_clk_internal = '1' then
					
					-- Lower cyc to end SPI access
					if cyc_falling_edge = '1' then
						
						cyc_inv_clear <= '1';
						
						-- Disable clock
						spi_clk_en <= '0';
						
						-- Hold spi_clk in reset
						clk_count_reset <= '1';
						
						-- Will be 10ns when we get to next state
						bit_count <= "001";
						
						state <= WAIT_CS_HOLD;
						
					elsif cyc_falling_edge = '0' and stb_rising_edge = '1' then
						
						-- Clear stb rising edge register
						stb_clear <= '1';
						
						-- Capture output data from master and mosi will change
						shift_out <= data_i;
						data_count <= data_cnt_i;
						
						-- First bit is loaded into shift_reg already
						bit_count <= "001";
							
						-- Continue shifting
						state <= SHIFT;
						
					else
						
						-- We can't let the clock rise yet, so we stop it for now
						spi_clk_en <= '0';
						
						-- Hold spi_clk in reset
						clk_count_reset <= '1';
						
						-- We have waited 40ns already
						bit_count <= "011";
						
						state <= DONE;
						
					end if;
					
				end if;

				
				
			-- The WB master hasn't indicated what to do next
			-- so we stretch out the spi_clk until we know
			when DONE =>
			
				dbg_state(11 downto 0) <= X"006";
				
				bit_count <= bit_count + 1;
				
				-- Stop counting after 5
				if bit_count = "100" then
					bit_count <= "100";
				end if;
				
				-- Hold spi_clk in reset
				clk_count_reset <= '1';
				
				-- Capture data if there is another cycle ready to go
				-- (a bit late now, but this should work according to specs)
				if cyc_i = '1' and stb_rising_edge = '1' then
					-- TODO: We probably need to wait 10ns before allowing clock to resume
					shift_out <= data_i;
					data_count <= data_cnt_i;
				end if;
				
				-- Lower cyc to end SPI access
				if cyc_falling_edge = '1' then
					
					cyc_inv_clear <= '1';
					
					-- If we know that we hit CS hold time, then we're done
					if bit_count = "100" then
						
						-- Set cs inactive
						spi_cs <= '1';
						
						state <= IDLE;
						
					else
						-- Otherwise we wait a bit longer...
						state <= WAIT_CS_HOLD;
					end if;
					
				-- If stb goes back to 1, more data needs to be transferred
				elsif stb_rising_edge = '1' then
				
					-- 011 is when spi_clock would have a rising edge anyway
					-- or 100 means we missed the rising edge so we should
					-- just start now
					if bit_count = "011" or bit_count = "100" then
						
						-- Clear rising edge register
						stb_clear <= '1';
						
						-- Put saved bit in shift register
						shift_in(31 downto 0) <= shift_in(30 downto 0) & spi_miso;
						
						-- Cancel reset so that we get a rising edge next
						clk_count_reset <= '0';

						-- Enable spi_clk output
						spi_clk_en <= '1';
						
						-- We shifted in one bit a few lines above
						bit_count <= "001";
						
						state <= SHIFT;
						
					end if;

				end if;
			
			-- Wait min 50ns for CS hold time, at 100mhz this is 5 clocks
			when WAIT_CS_HOLD =>
			
				dbg_state(11 downto 0) <= X"007";
				
				bit_count <= bit_count + 1;
				
				if bit_count = "101" then
					
					-- Set cs inactive
					spi_cs <= '1';
					
					-- More to do...
					if cyc_i = '1' and stb_rising_edge = '1' then
						
						state <= WAIT_CS_DISABLE;
						bit_count <= "000";
					else
						state <= IDLE;
					end if;
					
				end if;
				
			-- Wait min 20ns while CS is disabled between cycles, at 100mhz this is 2 clocks
			when WAIT_CS_DISABLE =>
			
				dbg_state(11 downto 0) <= X"008";
				
				bit_count <= bit_count + 1;
				
				if bit_count = "001" then
					
					-- Clear rising edge register
					stb_clear <= '1';
					
					-- Capture data from inputs
					shift_out <= data_i;
					data_count <= data_cnt_i;
					
					-- Set cs active
					spi_cs <= '0';
					
					-- Reset counter for spi_clk
					clk_count_reset <= '1';
					
					state <= WAIT_CS_SETUP;
					bit_count <= "001"; -- 1 clock will elapse to get to next state
					
				end if;
				
			end case;
			
			-- Any any time master lowers these to end
			if cyc_i = '0' or stb_i = '0' then
				-- And we need to stop ack right away
				ack <= '0';
			end if;
				
		end if;
	
	end process;



	intreg_stb : entity work.interrupt_reg
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		int_i => stb_i,
		int_o => stb_rising_edge,
		rst_i => stb_clear
	);
	
	cyc_inv <= not cyc_i;

	intreg_cyc_inv : entity work.interrupt_reg
	port map(
		sys_clk => sys_clk,
		sys_reset => sys_reset,
		int_i => cyc_inv,
		int_o => cyc_falling_edge,
		rst_i => cyc_inv_clear
	);


end Behavioral;

