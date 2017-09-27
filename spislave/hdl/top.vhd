----------------------------------------------------------------------------------
--
-- Example VHDL to connect spislave to an SRAM buffer.  There is also some code
-- below commented out for connecting to wishbone_register.  You should also be
-- able to connect spislave to any wishbone compatible SDRAM controller.
--
----------------------------------------------------------------------------------
--
-- Copyright (C) 2017  Nathan Friess
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
			  
			  SYS_SPI_SCK, RP_SPI_CE0N, SYS_SPI_MOSI : in std_logic ;
			  SYS_SPI_MISO : out std_logic
			  );
end top;

architecture Behavioral of top is
	
	signal sys_clk, clock_locked : std_logic;
	signal clk_100Mhz, clk_100Mhz_pll, osc_buff, clkfb  : std_logic;
	
	signal wb_cyc : std_logic;
	signal wb_stb : std_logic;
	signal wb_ack : std_logic;
	signal wb_write : std_logic;
	
	signal wb_addr : std_logic_vector(15 downto 0);
	
	signal wb_data_spi_o : std_logic_vector(15 downto 0);
	signal wb_data_spi_i : std_logic_vector(15 downto 0);

	signal rd_en : std_logic;
	signal wr_en : std_logic;
	
	signal rst : std_logic;
	
begin
	
	sys_clk <= clk_100Mhz;

	rst <= NOT PB0;
	
	LED0 <= '1';
	LED1 <= '0';
	
	spislave : entity work.spislave
	generic map(
		DATA_WIDTH => 16,
		ADDR_WIDTH => 16,
		AUTO_INC_ADDRESS => '1'
	)
	port map(
		sys_clk => sys_clk,
		
		spi_clk => SYS_SPI_SCK,
		spi_ce => RP_SPI_CE0N,
		spi_mosi => SYS_SPI_MOSI,
		spi_miso => SYS_SPI_MISO,
		
		wb_address => wb_addr,
		wb_data_i => wb_data_spi_i,
		wb_data_o => wb_data_spi_o,
		wb_cycle => wb_cyc,
		wb_strobe => wb_stb,
		wb_ack => wb_ack,
		wb_write => wb_write
		
	);
	
	rd_en <= '1' when wb_cyc = '1' and wb_stb = '1' and wb_write = '0' else '0';
	wr_en <= '1' when wb_cyc = '1' and wb_stb = '1' and wb_write = '1' else '0';
	
	wb_ack <= '1' when wb_cyc = '1' and wb_stb = '1' else '0';
	
	dpsram : entity work.dpram
		generic map(
			DATA_WIDTH => 16,
			RAM_WIDTH => 15
		)
		port map(
			clk => sys_clk,
			rst => rst,
			din => wb_data_spi_o,
			wr_en => wr_en,
			rd_en => rd_en,
			wr_addr => wb_addr(14 downto 0),
			rd_addr => wb_addr(14 downto 0),
			dout => wb_data_spi_i
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
--		gls_clk => sys_clk,
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

