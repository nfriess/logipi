----------------------------------------------------------------------------------
--
-- I2C slave device
--
-- Parameters:
--   ADDR_WIDTH  -- Wishbone address width in bits (8, 16, 24, 32...64)
--   DATA_WIDTH  -- Wishbone data width in bits (8, 16, 24, 32...64)
--   I2C_ADDRESS -- I2C device address, defaults to 0x60 which does not
--                  conflict with logipi board
--
-- Signals: Clock, Reset, standard wishbone, SDA, SCL
--
-- I2C Protocol:  (For data bytes in I2C)
--
-- Writes: First (ADDR_WIDTH/8) bytes must be WB address.  Sending a partial
--         WB address results in the address register being undefined.
--         After sending the WB address, optionally send (DATA_WIDTH/8) bytes
--         of WB data.  Sending partial WB data results in the write being
--         cancelled.
--
-- Reads: First perform a write of (ADDR_WIDTH/8) bytes to set the WB address.
--        Next perform a read of (DATA_WIDTH/8) bytes to read the WB data.
--        Performing a partial read will read the first N bits of the WB data.
--
-- WB addresses and data are in big endian order, MSB first.
--
-- This device will stretch the I2C clock while waiting for WB acknowledgement.
--
----------------------------------------------------------------------------------
--
-- Copyright (C) 2016  Nathan Friess
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity i2cslave is
	 Generic (
				  ADDR_WIDTH : Positive range 8 to 64 := 8;
				  DATA_WIDTH : Positive range 8 to 64 := 8;
				  I2C_ADDRESS : Positive range 1 to 16#7F# := 16#60#
	           );
    Port ( sys_clk : in  STD_LOGIC;
           i2c_sda : inout  STD_LOGIC;
           i2c_scl : inout  STD_LOGIC;
			  
			  wb_cycle : out STD_LOGIC;
			  wb_strobe : out STD_LOGIC;
			  wb_write : out STD_LOGIC;
			  wb_address : out STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
			  wb_data_i : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			  wb_data_o : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			  wb_ack : in STD_LOGIC

			);
end i2cslave;

architecture Behavioral of i2cslave is

	-- For OE: 3-state enable input, high=input, low=output 
	constant IO_INPUT : std_logic := '1';
	constant IO_OUTPUT : std_logic := '0';
	
	constant I2C_DIR_READ : std_logic := '1';

	signal i2c_sda_i : std_logic := '1';
	signal i2c_scl_i : std_logic := '1';
	signal i2c_sda_raw_o, i2c_sda_stable_o : std_logic;
	signal i2c_scl_raw_o, i2c_scl_stable_o : std_logic;
	signal i2c_sda_oe : std_logic := IO_INPUT;
	signal i2c_scl_oe : std_logic := IO_INPUT;
	
	signal i2c_sda_last : std_logic := '0';
	
	signal i2c_addr : std_logic_vector(7 downto 0);
	
	signal tmp_bit : std_logic;
	
	signal addr_bit_count : integer range 0 to ADDR_WIDTH;
	signal data_bit_count : integer range 0 to DATA_WIDTH;
	
	signal addr_reg : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
	signal data_reg : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
	
	signal count : std_logic_vector(3 downto 0);


	type STATES is (IDLE, START_CONDITION, ADDR_SCL_LOW, ADDR_SCL_HIGH,
							ADDR_ACK_SCL_LOW, ADDR_ACK_SCL_HIGH,
							-- 6
							WRITE_SCL_LOW, WRITE_SCL_HIGH,
							WRITE_WB_CYCLE_START, WRITE_WB_CYCLE_WAIT,
							WRITE_ACK_SCL_LOW, WRITE_ACK_SCL_HIGH,
							-- 12
							READ_WB_CYCLE_START, READ_WB_CYCLE_WAIT,
							READ_BEGIN_BYTE, READ_SCL_LOW, READ_SCL_HIGH,
							READ_ACK_SCL_LOW, READ_ACK_SCL_HIGH,
							-- 19
							DONE_SCL_LOW, DONE_SCL_HIGH,
							-- 21
							WAIT_STOP_CONDITION);
	signal state : STATES := IDLE;

begin

	wb_address <= addr_reg;
	wb_data_o <= data_reg;
	

	process(sys_clk)
	begin
	
		if rising_edge(sys_clk) then
		
			wb_cycle <= '0';
			wb_strobe <= '0';
			wb_write <= '0';
			
			if i2c_sda_oe = IO_INPUT then
				i2c_sda_last <= i2c_sda_stable_o;
			end if;
			
			case state is
			when IDLE =>
				
				i2c_sda_oe <= IO_INPUT;
				i2c_scl_oe <= IO_INPUT;
				
				if i2c_scl_stable_o = '1' and i2c_sda_last = '1' and i2c_sda_stable_o = '0' then
					state <= START_CONDITION;
				end if;
				
				
			when START_CONDITION =>
				-- SDA went low while SCL was high
				
				-- Wait for SCL low
				if i2c_scl_stable_o = '0' then
					state <= ADDR_SCL_LOW;
					count <= (others => '0');
				end if;
				
			when ADDR_SCL_LOW =>
				-- Receive address, SCL is low
				
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					-- Sample bit
					i2c_addr(7 downto 0) <= i2c_addr(6 downto 0) & i2c_sda_raw_o;
					count <= count + 1;
					state <= ADDR_SCL_HIGH;
				end if;
				
			when ADDR_SCL_HIGH =>
				-- Receive address, SCL is high
				
				-- SDA low -> high means STOP
				if i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					state <= IDLE;
					
				-- Wait for SCL low
				elsif i2c_scl_stable_o = '0' then
					
					if count = 8 then
					
						-- If address points to us, then we send ack on SDA
						if i2c_addr(7 downto 1) = I2C_ADDRESS then
							
							-- For us, so send ACK
							state <= ADDR_ACK_SCL_LOW;
							
						else
							
							-- Not for us, so we wait for stop condition
							state <= WAIT_STOP_CONDITION;
							
						end if;
						
					else
						state <= ADDR_SCL_LOW;
					end if;
					
				end if;
				
				
			when ADDR_ACK_SCL_LOW =>
				-- We are sending ack, SCL is low
				
				i2c_sda_oe <= IO_OUTPUT;
				i2c_sda_i <= '0';
				
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					state <= ADDR_ACK_SCL_HIGH;
				end if;
				
			when ADDR_ACK_SCL_HIGH =>
				-- We are sending ack, SCL is high
				
				-- SDA low -> high means STOP
				if i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					
					-- Done with ACK
					i2c_sda_oe <= IO_INPUT;
					
					state <= IDLE;
					
				-- Wait for SCL low
				elsif i2c_scl_stable_o = '0' then
					
					-- Done with ACK
					i2c_sda_oe <= IO_INPUT;
					
					count <= (others => '0');
					
					-- Move to state for given direction
					if i2c_addr(0) = I2C_DIR_READ then
						state <= READ_WB_CYCLE_START;
					else
						
						addr_bit_count <= 0;
						data_bit_count <= 0;
					
						state <= WRITE_SCL_LOW;
						
					end if;
					
				end if;
				
				
			when WRITE_SCL_LOW =>
				-- Master is writing byte, SCL low
			
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					
					-- Sample bit
					count <= count + 1;
					
					if addr_bit_count = ADDR_WIDTH then
						-- Data phase
						
						data_reg(DATA_WIDTH-1 downto 0) <= data_reg(DATA_WIDTH-2 downto 0) & i2c_sda_raw_o;
						data_bit_count <= data_bit_count + 1;
						
					else
						-- Addr phase
						
						addr_reg(ADDR_WIDTH-1 downto 0) <= addr_reg(ADDR_WIDTH-2 downto 0) & i2c_sda_raw_o;
						addr_bit_count <= addr_bit_count + 1;
						
					end if;
					
					state <= WRITE_SCL_HIGH;
					
				end if;
				
			when WRITE_SCL_HIGH =>
				-- Master is writing byte, SCL high
			
				-- SDA low -> high means STOP
				if i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					state <= IDLE;
					
				-- Wait for SCL low
				elsif i2c_scl_stable_o = '0' then
					if count = 8 then
						
						-- Either capture address or do wishbone cycle
						state <= WRITE_WB_CYCLE_START;
						
					else
						state <= WRITE_SCL_LOW;
					end if;
				end if;
				
				
			when WRITE_WB_CYCLE_START =>
				-- Accumulate addr/data until we have enough and then start wishbone cycle
				
				if data_bit_count = DATA_WIDTH then
					
					-- Start write cycle
					wb_cycle <= '1';
					wb_strobe <= '1';
					wb_write <= '1';
					
					state <= WRITE_WB_CYCLE_WAIT;
					
				else
					
					-- ACK from slave
					state <= WRITE_ACK_SCL_LOW;
					
				end if;
				
				
			when WRITE_WB_CYCLE_WAIT =>
				-- Wait for ack on wishbone bus
				
				wb_cycle <= '1';
				wb_strobe <= '1';
				wb_write <= '1';
				
				-- Early ACK signal
				i2c_sda_oe <= IO_OUTPUT;
				i2c_sda_i <= '0';
				
				-- Strech clock until wb_ack
				i2c_scl_oe <= IO_OUTPUT;
				i2c_scl_i <= '0';
				
				if wb_ack = '1' then
					
					wb_cycle <= '0';
					wb_strobe <= '0';
					
					state <= WRITE_ACK_SCL_LOW;
					
				end if;
				
				
			when WRITE_ACK_SCL_LOW =>
				-- Ack to master write, SCL low
				
				-- ACK signal
				i2c_sda_oe <= IO_OUTPUT;
				i2c_sda_i <= '0';
				
				-- Stop stretching clock
				i2c_scl_oe <= IO_INPUT;
				
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					state <= WRITE_ACK_SCL_HIGH;
				end if;
				
				
			when WRITE_ACK_SCL_HIGH =>
				-- Ack to master write, SCL high
				
				-- Wait for SCL low
				if i2c_scl_stable_o = '0' then
					state <= DONE_SCL_LOW;
				end if;
				
				
			when READ_WB_CYCLE_START =>
				-- Start wishbone cycle
				
				-- Strech clock until ack
				i2c_scl_oe <= IO_OUTPUT;
				i2c_scl_i <= '0';
				
				wb_cycle <= '1';
				wb_strobe <= '1';
				wb_write <= '0';
				
				state <= READ_WB_CYCLE_WAIT;
				
				
			when READ_WB_CYCLE_WAIT =>
				-- Wait for ack on wishbone bus
				
				wb_cycle <= '1';
				wb_strobe <= '1';
				wb_write <= '0';
				
				if wb_ack = '1' then
					
					wb_cycle <= '0';
					wb_strobe <= '0';
					
					data_reg <= wb_data_i;
					data_bit_count <= 0;
					
					state <= READ_BEGIN_BYTE;
					
				end if;
				
				
			when READ_BEGIN_BYTE =>
				-- Master is reading a byte, start of cycle
				
				-- Start data output
				i2c_sda_oe <= IO_OUTPUT;
				
				count <= (others => '0');
				
				state <= READ_SCL_LOW;
				
				
			when READ_SCL_LOW =>
				-- Master is reading byte, SCL low
			
				-- Stop stretching clock
				i2c_scl_oe <= IO_INPUT;
				
				-- Output next bit
				i2c_sda_i <= data_reg(DATA_WIDTH-1);
				
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					
					count <= count + 1;
					data_bit_count <= data_bit_count + 1;
					
					state <= READ_SCL_HIGH;
					
				end if;
				
			when READ_SCL_HIGH =>
				-- Master is reading byte, SCL high
				
				-- Keep outputting bit
				i2c_sda_i <= data_reg(DATA_WIDTH-1);
				
				-- Wait for SCL low
				if i2c_scl_stable_o = '0' then
				
					-- Shift data
					data_reg(DATA_WIDTH-1 downto 0) <= data_reg(DATA_WIDTH-2 downto 0) & "0";
					
					if count = 8 then
						
						-- ACK from master
						state <= READ_ACK_SCL_LOW;
						
					else
						
						state <= READ_SCL_LOW;
						
					end if;
				end if;
				
				
			when READ_ACK_SCL_LOW =>
				-- Master sends ack, SCL low
				
				-- Stop transmitting data while master sends ACK
				i2c_sda_oe <= IO_INPUT;
				
				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					-- Save ack state from master for later
					tmp_bit <= i2c_sda_raw_o;
					state <= READ_ACK_SCL_HIGH;
				end if;
				
			when READ_ACK_SCL_HIGH =>
				-- Ack to master read, SCL high
				
				-- SDA low -> high means STOP
				if i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					
					state <= IDLE;
					
				-- Wait for SCL low
				elsif i2c_scl_stable_o = '0' then
					
					
					-- NACK means there will be a stop, ACK means more reads
					if tmp_bit = '1' then -- NACK
						state <= DONE_SCL_LOW;
					else
						
						-- TODO: Count the data bits and if needed, increment address?
						
						state <= READ_BEGIN_BYTE;
						
					end if;
				
				end if;
				
				
			when DONE_SCL_LOW =>
				-- We just finished sending or reciving an ACK, SCL low
				
				-- Need to stop ACK, if we were doing that
				i2c_sda_oe <= IO_INPUT;

				-- Wait for SCL high
				if i2c_scl_stable_o = '1' then
					
					-- Sample bit in case we are continuing a write
					tmp_bit <= i2c_sda_raw_o;
					state <= DONE_SCL_HIGH;
					
				end if;
				
				
			when DONE_SCL_HIGH =>
				-- We just finished sending or reciving an ACK, SCL high
								
				-- Now, we don't know if we are continuing a cycle or
				-- if we will get a stop or a repeated start...
				
				-- SDA low -> high means STOP
				if i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					
					state <= IDLE;
					
				-- SDA low -> high means repeated START
				elsif i2c_sda_last = '1' and i2c_sda_stable_o = '0' then
					
					state <= START_CONDITION;
					
				-- No STOP or repeated START, so we continue with the previous cycle
				elsif i2c_scl_stable_o = '0' then
				
					if i2c_addr(0) = I2C_DIR_READ then
						
						count <= (others => '0');
						
						if data_bit_count = DATA_WIDTH then
							state <= READ_WB_CYCLE_START;
						else
							state <= READ_BEGIN_BYTE;
						end if;
						
						
					else
						
						-- Do the actions we missed in the write cycle
						count <= X"1";
						
						if addr_bit_count = ADDR_WIDTH then
							-- Data phase
							
							data_reg(DATA_WIDTH-1 downto 0) <= data_reg(DATA_WIDTH-2 downto 0) & tmp_bit;
							
							if data_bit_count = DATA_WIDTH then
								data_bit_count <= 1;
							else
								data_bit_count <= data_bit_count + 1;
							end if;
							
						else
							-- Addr phase
							
							addr_reg(ADDR_WIDTH-1 downto 0) <= addr_reg(ADDR_WIDTH-2 downto 0) & tmp_bit;
							addr_bit_count <= addr_bit_count + 1;
							
						end if;
						
						state <= WRITE_SCL_LOW;
						
					end if;
					
				end if;
				
				
			when WAIT_STOP_CONDITION =>
				-- Wait for stop condition
				
				
				-- Stop condition is SCL=1, SDA goes 0=>1
				if i2c_scl_stable_o = '1' and i2c_sda_last = '0' and i2c_sda_stable_o = '1' then
					state <= IDLE;
					
				-- Repeated start condition is SCL=1, SDA goes 1=>0 (like start)
				elsif i2c_scl_stable_o = '1' and i2c_sda_last = '1' and i2c_sda_stable_o = '0' then
					state <= START_CONDITION;
				end if;
				
				
			--when others =>
				
			--	state <= IDLE;
				
			end case;
		end if;
	
	end process;
	
	
	SDA_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "I2C",
      SLEW => "SLOW")
   port map (
      O => i2c_sda_raw_o,
      IO => i2c_sda,
      I => i2c_sda_i,
      T => i2c_sda_oe
   );
	
   SCL_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "I2C",
      SLEW => "SLOW")
   port map (
      O => i2c_scl_raw_o,
      IO => i2c_scl,
      I => i2c_scl_i,
      T => i2c_scl_oe
   );
	
	
	debounce_sda : entity work.debounce
	generic map(
		SigDefault => '1'
	)
	port map(
		sys_clk => sys_clk,
		sig_in => i2c_sda_raw_o,
		sig_out => i2c_sda_stable_o
	);

	debounce_scl : entity work.debounce
	generic map(
		SigDefault => '1'
	)
	port map(
		sys_clk => sys_clk,
		sig_in => i2c_scl_raw_o,
		sig_out => i2c_scl_stable_o
	);
	

end Behavioral;

