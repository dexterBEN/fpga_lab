library ieee;
use ieee.std_logic_1164.all;

-- Integration des deux registres : mode selectionne uniquement la sortie.
-- Les commandes load et shift restent independantes de mode.
entity register_system is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        load      : in  std_logic;
        shift     : in  std_logic;
        mode      : in  std_logic;
        d         : in  std_logic_vector(3 downto 0);
        serial_in : in  std_logic;
        q         : out std_logic_vector(3 downto 0)
    );
end entity register_system;

architecture rtl of register_system is
    signal parallel_q : std_logic_vector(3 downto 0);
    signal shift_q    : std_logic_vector(3 downto 0);
begin
    parallel_inst : entity work.parallel_register(rtl)
        port map (
            clk => clk, reset => reset, enable => load,
            d => d, q => parallel_q
        );

    shift_inst : entity work.shift_register(rtl)
        port map (
            clk => clk, reset => reset, shift => shift,
            serial_in => serial_in, q => shift_q
        );

    q <= parallel_q when mode = '0' else shift_q;
end architecture rtl;
