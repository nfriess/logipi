----------------------------------------------------------------------------------
--
-- Example VHDL to connect i2cslave to an SRAM buffer.  There is also some code
-- below commented out for connecting to wishbone_register.  You should also be
-- able to connect i2cslave to any wishbone compatible SDRAM controller.
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
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity top is
    Port ( OSC_FPGA : in  STD_LOGIC;
			  LED0 : out STD_LOGIC;
			  LED1 : out STD_LOGIC;
			  PB0 : in STD_LOGIC;
			  SYS_SDA : inout STD_LOGIC;
			  SYS_SCL : inout STD_LOGIC
			  );
end top;

architecture Behavioral of top is

	signal wb_cyc : std_logic;
	signal wb_stb : std_logic;
	signal wb_ack : std_logic;
	signal wb_write : std_logic;
	
	signal wb_addr : std_logic_vector(15 downto 0);
	
	signal wb_data_i2c_o : std_logic_vector(15 downto 0);
	signal wb_data_i2c_i : std_logic_vector(15 downto 0);
	
	--signal reg0 : std_logic_vector(15 downto 0) := X"DEDE";
	--signal reg1 : std_logic_vector(15 downto 0) := X"ADAD";
	
	
	signal rd_sig : std_logic_vector(15 downto 0);
	signal rd_en : std_logic;
	signal wr_en : std_logic;
	signal delay : std_logic;
	
	signal rst : std_logic;
	
begin

	rst <= NOT PB0;
	
	LED0 <= '1';
	LED1 <= '0';
	
	i2cslave : entity work.i2cslave
	generic map(
		DATA_WIDTH => 16,
		ADDR_WIDTH => 16,
		I2C_ADDRESS => 16#60#
	)
	port map(
		sys_clk => OSC_FPGA,
		sys_reset => rst,
		i2c_sda => SYS_SDA,
		i2c_scl => SYS_SCL,
		
		wb_address => wb_addr,
		wb_data_i => wb_data_i2c_i,
		wb_data_o => wb_data_i2c_o,
		wb_cycle => wb_cyc,
		wb_strobe => wb_stb,
		wb_ack => wb_ack,
		wb_write => wb_write
		
	);
	
	process(OSC_FPGA)
	begin
		if rising_edge(OSC_FPGA) then
			rd_en <= '0';
			wr_en <= '0';
			if wb_cyc = '1' and wb_stb = '1' and delay = '0' then
				if wb_write = '0' then
					rd_en <= '1';
				else
					wr_en <= '1';
				end if;
			end if;
			
			delay <= '0';
			if rd_en = '1' or wr_en = '1' then
				wb_data_i2c_i <= rd_sig;
				delay <= '1';
			end if;
			
			wb_ack <= '0';
			if delay = '1' then
				wb_ack <= '1';
			end if;
			
		end if;
	end process;
	
	dpsram : entity work.dpram
		generic map(
			DATA_WIDTH => 16,
			RAM_WIDTH => 15
		)
		port map(
			clk => OSC_FPGA,
			rst => rst,
			din => wb_data_i2c_o,
			wr_en => wr_en,
			rd_en => rd_en,
			wr_addr => wb_addr(14 downto 0),
			rd_addr => wb_addr(14 downto 0),
			dout => rd_sig
		);
		
-- Example of connecting to some registers:
--
--	regs : entity work.wishbone_register
--	generic map(
--		wb_size => 16,
--		nb_regs => 2
--	)
--	port map(
--		gls_reset => '0',
--		gls_clk => OSC_FPGA,
--		
--		wbs_address => wb_addr,
--		wbs_writedata => wb_data_i2c_o,
--		wbs_readdata => wb_data_i2c_i,
--		wbs_strobe => wb_stb,
--		wbs_cycle => wb_cyc,
--		wbs_write => wb_write,
--		wbs_ack => wb_ack,
--		
--		reg_out(0) => reg0,
--		reg_out(1) => reg1,
--		reg_in(0) => reg0,
--		reg_in(1) => reg1
--	);
	


end Behavioral;

