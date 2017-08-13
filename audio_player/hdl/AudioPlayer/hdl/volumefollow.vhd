----------------------------------------------------------------------------------
--
-- Circuit to gradually change volume up or down to the target volume sent by
-- the PC.  This reduces any popping sounds when the sound goes to/from a muted
-- state, as well as any sudden jumps in the volume control.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;

entity volumefollow is
    Port ( volume_i : in  STD_LOGIC_VECTOR (8 downto 0);
           targetvolume_i : in  STD_LOGIC_VECTOR (8 downto 0);
			  mute_i : in STD_LOGIC;
           nextvolume_o : out  STD_LOGIC_VECTOR (8 downto 0));
end volumefollow;

architecture Behavioral of volumefollow is

begin
	
	process(volume_i, targetvolume_i, mute_i)
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

