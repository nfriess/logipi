----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:36:16 07/24/2016 
-- Design Name: 
-- Module Name:    syncflag - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity syncflag is
    Port ( source_clk : in  STD_LOGIC;
           target_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
           flag_i : in  STD_LOGIC;
           flag_o : out  STD_LOGIC);
end syncflag;

architecture Behavioral of syncflag is

	signal flagtoggle_reg : STD_LOGIC;
	signal sig_shift : STD_LOGIC_VECTOR(1 downto 0);

begin

	sig_o <= sig_shift(1);
	
	-- http://www.fpga4fun.com/CrossClockDomain2.html
	process (source_clk)
	begin
		if rising_edge(source_clk) then
			flagtoggle_reg <= flagtoggle_reg xor flag_i;
		end if;
	end process;
	
	process (target_clk, sys_reset)
	begin
		
		if sys_reset = '1' then	
			sig_shift <= (others => DEFAULT_VAL);
		elsif rising_edge(target_clk) then
			sig_shift(1) <= sig_shift(0);
			sig_shift(0) <= flagtoggle_reg;
		end if;
		
	end process;

end Behavioral;

