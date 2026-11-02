library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;


entity demultiplexer is
    port (
        d  : in  STD_LOGIC;
        s  : in  STD_LOGIC_VECTOR(1 downto 0);
        y0 : out STD_LOGIC;
        y1 : out STD_LOGIC;
        y2 : out STD_LOGIC;
        y3 : out STD_LOGIC
    );
end demultiplexer;

architecture demultiplexer_arch of demultiplexer is
begin

    process(d, s)
    begin

        y0 <= '0';
        y1 <= '0';
        y2 <= '0';
        y3 <= '0';

        case s is

            when "00" =>
                y0 <= d;

            when "01" =>
                y1 <= d;

            when "10" =>
                y2 <= d;

            when "11" =>
                y3 <= d;

            when others =>
                null;

        end case;

    end process;

end demultiplexer_arch;