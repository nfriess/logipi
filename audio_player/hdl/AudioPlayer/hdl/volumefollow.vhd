----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:15:43 07/20/2017 
-- Design Name: 
-- Module Name:    volumefollow - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity volumefollow is
    Port ( volume_i : in  STD_LOGIC_VECTOR (8 downto 0);
           targetvolume_i : in  STD_LOGIC_VECTOR (8 downto 0);
			  mute_i : in STD_LOGIC;
           nextvolume_o : out  STD_LOGIC_VECTOR (8 downto 0));
end volumefollow;

architecture Behavioral of volumefollow is

begin
	
	process(volume_i, targetvolume_i)
	begin
			
		if mute_i = '1' or targetvolume_i = "0" & X"00" then
			nextvolume_o <= "0" & volume_i(8 downto 1);
		elsif volume_i < targetvolume_i then
			nextvolume_o <= std_logic_vector(to_unsigned(to_integer(unsigned(volume_i)) + 1, nextvolume_o'length));
		elsif volume_i > targetvolume_i then
			nextvolume_o <= std_logic_vector(to_unsigned(to_integer(unsigned(volume_i)) - 1, nextvolume_o'length));
		else
			nextvolume_o <= volume_i;
		end if;
			
	end process;


end Behavioral;

