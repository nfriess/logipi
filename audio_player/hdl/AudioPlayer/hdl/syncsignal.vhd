----------------------------------------------------------------------------------
--
-- Signal synchronizer circuit
--
-- Based on design at http://www.fpga4fun.com/CrossClockDomain1.html
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity syncsignal is
    Generic ( DEFAULT_VAL : STD_LOGIC := '0' );
    Port ( target_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
           sig_i : in  STD_LOGIC;
           sig_o : out  STD_LOGIC);
end syncsignal;

architecture Behavioral of syncsignal is

	attribute ASYNC_REG     : string;
	attribute KEEP          : string;

	signal sig_shift : STD_LOGIC_VECTOR(1 downto 0);
	
	attribute KEEP of sig_shift: signal is "TRUE";
	attribute ASYNC_REG of sig_shift: signal is "TRUE";

begin

	sig_o <= sig_shift(1);

	process (target_clk, sys_reset)
	begin
		
		if sys_reset = '1' then	
			sig_shift <= (others => DEFAULT_VAL);
		elsif rising_edge(target_clk) then
			sig_shift(1) <= sig_shift(0);
			sig_shift(0) <= sig_i;
		end if;
		
	end process;

end Behavioral;

