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
				  SteadyMinTime : Positive := 10
	           );
    Port ( 
			  sys_clk : in  STD_LOGIC;
           sys_reset : in  STD_LOGIC;
	 
			  sig_in : in  STD_LOGIC;
           sig_out : out  STD_LOGIC
           );
end debounce;

architecture Behavioral of debounce is

	signal last_sig : STD_LOGIC;
	signal steady_count : STD_LOGIC_VECTOR(3 downto 0);

begin

	process(sys_clk, sys_reset, sig_in)
	begin
	
		if sys_reset = '1' then
			
			last_sig <= sig_in;
			sig_out <= sig_in;
			steady_count <= (others => '0');
			
		elsif rising_edge(sys_clk) then
			
			steady_count <= steady_count + 1;
			
			if sig_in /= last_sig then
			
				steady_count <= (others => '0');
				last_sig <= sig_in;
				
			else
				
				if steady_count = SteadyMinTime then
					sig_out <= sig_in;
				end if;
				
			end if;
			
		end if;
	
	end process;


end Behavioral;

