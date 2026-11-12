
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is

    generic (
        DATA_WIDTH : positive := 4
    );

    port (
        a        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        b        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        op       : in  std_logic_vector(2 downto 0);

        result   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        carry    : out std_logic;
        borrow   : out std_logic;
        zero     : out std_logic;
        overflow : out std_logic
    );
end entity alu;

architecture alu_arch of alu is
begin

    -- Combinational ALU: no clock or stored state.
    process(all) is
        variable extended_result : unsigned(DATA_WIDTH downto 0);
        variable computed_result : std_logic_vector(DATA_WIDTH - 1 downto 0);
    begin
        -- Default assignments prevent inferred latches.
        extended_result := (others => '0');
        computed_result := (others => '0');

        carry    <= '0';
        borrow   <= '0';
        overflow <= '0';

        case op is

            when "000" =>  -- ADD
                extended_result :=
                    ('0' & unsigned(a)) + ('0' & unsigned(b));

                computed_result :=
                    std_logic_vector(extended_result(DATA_WIDTH - 1 downto 0));

                carry <= extended_result(DATA_WIDTH);

                -- Signed overflow:
                -- Same-sign operands produce an opposite-sign result.
                if (a(DATA_WIDTH - 1) = b(DATA_WIDTH - 1)) and
                   (computed_result(DATA_WIDTH - 1) /= a(DATA_WIDTH - 1)) then
                    overflow <= '1';
                end if;

            when "001" =>  -- AND
                computed_result := a and b;

            when "010" =>  -- OR
                computed_result := a or b;

            when "011" =>  -- SUB
                extended_result :=
                    ('0' & unsigned(a)) - ('0' & unsigned(b));

                computed_result :=
                    std_logic_vector(extended_result(DATA_WIDTH - 1 downto 0));

                -- Unsigned borrow:
                -- A borrow occurs when A is smaller than B.
                if unsigned(a) < unsigned(b) then
                    borrow <= '1';
                end if;

                -- Signed overflow:
                -- Different-sign operands produce a result
                -- whose sign differs from A.
                if (a(DATA_WIDTH - 1) /= b(DATA_WIDTH - 1)) and
                   (computed_result(DATA_WIDTH - 1) /= a(DATA_WIDTH - 1)) then
                    overflow <= '1';
                end if;

            when others =>
                computed_result := (others => '0');

        end case;

        result <= computed_result;

        -- Zero flag is derived from the final ALU result.
        if computed_result = (computed_result'range => '0') then
            zero <= '1';
        else
            zero <= '0';
        end if;

    end process;

end architecture alu_arch;
