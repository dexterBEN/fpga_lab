library ieee;
use ieee.std_logic_1164.all;

-- Registre parallele de 4 bits.
-- Reset asynchrone actif a '1', prioritaire sur l'horloge et enable.
-- Lors de l'integration sur carte, synchroniser sa desactivation avec clk.
entity parallel_register is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        enable : in  std_logic;
        d      : in  std_logic_vector(3 downto 0);
        q      : out std_logic_vector(3 downto 0)
    );
end entity parallel_register;

architecture rtl of parallel_register is
begin
    process (clk, reset)
    begin
        if reset = '1' then
            q <= (others => '0');
        elsif rising_edge(clk) then
            if enable = '1' then
                q <= d;
            end if;
            -- Sans affectation, les bascules conservent leur valeur.
        end if;
    end process;
end architecture rtl;
