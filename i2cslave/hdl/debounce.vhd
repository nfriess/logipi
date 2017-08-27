----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:17:32 05/15/2016 
-- Design Name: 
-- Module Name:    debounce - Behavioral 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity debounce is
	 Generic (
				  SteadyMinTime : Positive := 10;
				  SigDefault : STD_LOGIC := '0'
	           );
    Port ( 
			  sys_clk : in  STD_LOGIC;
	 
			  sig_in : in  STD_LOGIC;
           sig_out : out  STD_LOGIC
           );
end debounce;

architecture Behavioral of debounce is

	signal last_sig : STD_LOGIC := SigDefault;
	signal sig_out_reg : STD_LOGIC := SigDefault;
	signal steady_count : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

begin

	sig_out <= sig_out_reg;

	process(sys_clk)
	begin
	
		if rising_edge(sys_clk) then
			
			steady_count <= steady_count + 1;
			
			if sig_in /= last_sig then
			
				steady_count <= (others => '0');
				last_sig <= sig_in;
				
			else
				
				if steady_count = SteadyMinTime then
					sig_out_reg <= sig_in;
				end if;
				
			end if;
			
		end if;
	
	end process;


end Behavioral;

