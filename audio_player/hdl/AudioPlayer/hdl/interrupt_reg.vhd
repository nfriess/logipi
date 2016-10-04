----------------------------------------------------------------------------------
-- 
-- Edge-triggered interrupt register
--
-- Will hold its 'set' state until a synchronous reset signal is applied.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity interrupt_reg is
    Port ( sys_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
           int_i : in  STD_LOGIC;
           int_o : out  STD_LOGIC;
           rst_i : in  STD_LOGIC);
end interrupt_reg;

architecture Behavioral of interrupt_reg is

	signal have_rst : STD_LOGIC;
	signal int_reg : STD_LOGIC;

begin

	int_o <= '1' when ((int_i = '1' or int_reg = '1') and rst_i = '0' and have_rst = '0') else '0';

	process(sys_clk,sys_reset)
	begin
		if sys_reset = '1' then
			int_reg <= '0';
			have_rst <= '0';
		elsif rising_edge(sys_clk) then
			
			if rst_i = '1' then
				int_reg <= '0';
				have_rst <= '1';
			elsif rst_i = '0' and have_rst = '1' and int_i = '0' then
				int_reg <= '0';
				have_rst <= '0';
			elsif rst_i = '0' and have_rst = '0' and int_i = '1' then
				int_reg <= '1';
			end if;
			
		end if;
	end process;

end Behavioral;

