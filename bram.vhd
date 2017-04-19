---------------------------------------------------------------------------------
--| @file bram.vhd
--| @brief Implements a generic dual port block RAM which.
--|
--| @author         Richard James Howe.
--| @copyright      Copyright 2013 Richard James Howe.
--| @license        MIT
--| @email          howe.r.j.89@gmail.com
--|
--| @note GHDL complains about the function "inFile" not being a pure function,
--| as it reads from a file, it simulates correctly however. 
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity memory is

	-- The dual port Block RAM module can be initialized from a file,
	-- or initialized to all zeros. The model can be synthesized (with
	-- Xilinx's ISE) into BRAM.
	--	
	-- Valid file_type options include:
	--
	-- "bin"  - A binary file (ASCII '0' and '1', one number per line)
	-- "hex"  - A Hex file (ASCII '0-9' 'a-f', 'A-F', one number per line)
	-- "nil"  - RAM contents will be defaulted to all zeros, no file will
	--          be read from
	--
	-- The data length must be divisible by 4 if the "hex" option is
	-- given.
	--
	-- These default values for addr_length and data_length have been
	-- chosen so as to fill the block RAM available on a Spartan 6.
	--
	generic(addr_length: positive  := 12;
		data_length: positive  := 16;
		file_name:    string   := "memory.bin"; 
		file_type:    string   := "bin");
	port(
		--| Port A of dual port RAM
		a_clk:  in  std_logic;
		a_dwe:  in  std_logic;
		a_dre:  in  std_logic;
		a_addr: in  std_logic_vector(addr_length - 1 downto 0);
		a_din:  in  std_logic_vector(data_length - 1 downto 0);
		a_dout: out std_logic_vector(data_length - 1 downto 0) := (others => '0');
		--| Port B of dual port RAM
		b_clk:  in  std_logic;
		b_dwe:  in  std_logic;
		b_dre:  in  std_logic;
		b_addr: in  std_logic_vector(addr_length - 1 downto 0);
		b_din:  in  std_logic_vector(data_length - 1 downto 0);
		b_dout: out std_logic_vector(data_length - 1 downto 0) := (others => '0'));
end memory;

architecture behav of memory is
	constant ramSz: positive := 2 ** addr_length;

	type ramArray_t is array ((ramSz - 1 ) downto 0) of std_logic_vector(data_length - 1 downto 0);

	function hexCharToStdLogicVector(hc: character) return std_logic_vector is
		variable slv: std_logic_vector(3 downto 0);
	begin
		case hc is
		when '0' => slv := "0000";
		when '1' => slv := "0001";
		when '2' => slv := "0010";
		when '3' => slv := "0011";
		when '4' => slv := "0100";
		when '5' => slv := "0101";
		when '6' => slv := "0110";
		when '7' => slv := "0111";
		when '8' => slv := "1000";
		when '9' => slv := "1001";
		when 'A' => slv := "1010";
		when 'a' => slv := "1010";
		when 'B' => slv := "1011";
		when 'b' => slv := "1011";
		when 'C' => slv := "1100";
		when 'c' => slv := "1100";
		when 'D' => slv := "1101";
		when 'd' => slv := "1101";
		when 'E' => slv := "1110";
		when 'e' => slv := "1110";
		when 'F' => slv := "1111";
		when 'f' => slv := "1111";
		when others => slv := "XXXX";
		end case;
		assert (slv /= "XXXX") report " not a valid hex character: " & hc  severity failure;
		return slv;
	end hexCharToStdLogicVector;

	function initRam(file_name, file_type: in string) return ramArray_t is
		variable ramData:   ramArray_t;
		file     inFile:    text is in file_name;
		variable inputLine: line;
		variable tmpVar:    bit_vector(data_length - 1 downto 0);
		variable c:         character;
		variable slv:       std_logic_vector(data_length - 1 downto 0);
	begin
		for i in 0 to ramSz - 1 loop
			if file_type = "nil" then
				ramData(i):=(others => '0');
			elsif not endfile(inFile) then
				readline(inFile,inputLine);
				if file_type = "bin" then -- binary
					read(inputLine, tmpVar);
					ramData(i) := to_stdlogicvector(tmpVar);
				elsif file_type = "hex" then -- hexadecimal
					assert (data_length mod 4) = 0 report "(data_length%4)!=0" severity failure;
					for j in 1 to (data_length/4) loop
						c:= inputLine((data_length/4) - j + 1);
						slv((j*4)-1 downto (j*4)-4) := hexCharToStdLogicVector(c);
					end loop;
					ramData(i) := slv;
				else
					report "Incorrect file type given: " & file_type severity failure;
				end if;
			else
				ramData(i) := (others => '0');
			end if;
		end loop;
		return ramData;
	end function;

	shared variable ram: ramArray_t := initRam(file_name, file_type);

begin
	a_ram: process(a_clk)
	begin
		if rising_edge(a_clk) then
			if a_dwe = '1' then
				ram(to_integer(unsigned(a_addr))) := a_din;
			end if;
			if a_dre = '1' then
				a_dout <= ram(to_integer(unsigned(a_addr)));
			else
				a_dout <= (others => '0');
			end if;
		end if;
	end process;

	b_ram: process(b_clk)
	begin
		if rising_edge(b_clk) then
			if b_dwe = '1' then
				ram(to_integer(unsigned(b_addr))) := b_din;
			end if;
			if b_dre = '1' then
				b_dout <= ram(to_integer(unsigned(b_addr)));
			else
				b_dout <= (others => '0');
			end if;
		end if;
	end process;
end architecture;

