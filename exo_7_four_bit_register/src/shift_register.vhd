library ieee;
use ieee.std_logic_1164.all;

-- Registre SIPO : entree serie, sortie parallele de 4 bits.
-- serial_in -> q(0) -> q(1) -> q(2) -> q(3) -> bit perdu.
-- Reset asynchrone actif a '1'. Synchroniser sa desactivation sur carte.
entity shift_register is
    port (
        clk       : in  std_logic;
        reset     : in  std_logic;
        shift     : in  std_logic;
        serial_in : in  std_logic;
        q         : out std_logic_vector(3 downto 0)
    );
end entity shift_register;

architecture rtl of shift_register is
    signal stored : std_logic_vector(3 downto 0);
begin
    q <= stored;

    process (clk, reset)
    begin
        if reset = '1' then
            stored <= (others => '0');
        elsif rising_edge(clk) then
            if shift = '1' then
                stored <= stored(2 downto 0) & serial_in;
            end if;
        end if;
    end process;
end architecture rtl;
