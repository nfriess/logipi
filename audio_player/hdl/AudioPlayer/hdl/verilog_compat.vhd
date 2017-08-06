--
--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 
--
--   To use any of the example code shown below, uncomment the lines and modify as necessary
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package verilog_compat is

component sdram is
port (
	clk_i : in std_logic;
	rst_i : in std_logic;
	stb_i : in std_logic;
	we_i : in std_logic;
	sel_i : in std_logic_vector(3 downto 0);
	cyc_i : in std_logic;
	addr_i : in std_logic_vector(31 downto 0);
	data_i : in std_logic_vector(31 downto 0);
	data_o : out std_logic_vector(31 downto 0);
	stall_o : out std_logic;
	ack_o : out std_logic;

	sdram_clk_o : out std_logic;
	sdram_cke_o : out std_logic;
	sdram_cs_o : out std_logic;
	sdram_ras_o : out std_logic;
	sdram_cas_o : out std_logic;
	sdram_we_o : out std_logic;
	sdram_dqm_o : out std_logic_vector(1 downto 0);
	sdram_addr_o : out std_logic_vector(12 downto 0);
	sdram_ba_o : out std_logic_vector(1 downto 0);
	sdram_data_io : inout std_logic_vector(15 downto 0)
	
);
end component;

end verilog_compat;

package body verilog_compat is


end verilog_compat;
