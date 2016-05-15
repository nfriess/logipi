----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    08:20:22 04/17/2016 
-- Design Name: 
-- Module Name:    spibridge - Behavioral 
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

entity spibridge is
    Port ( SYS_SPI_SCK : in  STD_LOGIC;
           RP_SPI_CE0N : in  STD_LOGIC;
           SYS_SPI_MOSI : in  STD_LOGIC;
           SYS_SPI_MISO : out  STD_LOGIC;
           CFG_CLK_FLSH_CLK : out  STD_LOGIC;
           ARD_D8_FLSH_CS : out  STD_LOGIC;
           ARD_D9_FLSH_DI : out  STD_LOGIC;
           CFG_DIN_FLSH_DO : in  STD_LOGIC);
end spibridge;

architecture Behavioral of spibridge is

begin

	CFG_CLK_FLSH_CLK <= SYS_SPI_SCK;
	ARD_D8_FLSH_CS <= RP_SPI_CE0N;
	ARD_D9_FLSH_DI <= SYS_SPI_MOSI;
	SYS_SPI_MISO <= CFG_DIN_FLSH_DO;

end Behavioral;

