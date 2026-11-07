
library ieee;
use ieee.std_logic_1164.all;

entity register_command_adapter is
    port (
        clk          : in  std_logic;
        commands     : in  std_logic_vector(8 downto 0);

        reset_out    : out std_logic;
        load_out     : out std_logic;
        shift_out    : out std_logic;
        mode_out     : out std_logic;
        serial_out   : out std_logic;
        data_out     : out std_logic_vector(3 downto 0)
    );
end entity register_command_adapter;

architecture rtl of register_command_adapter is
    signal load_meta, load_sync, load_prev : std_logic := '0';
    signal shift_meta, shift_sync, shift_prev : std_logic := '0';
    signal reset_meta, reset_sync : std_logic := '0';
begin

    -- Data signals are driven by the AXI GPIO registers.
    data_out   <= commands(3 downto 0);
    serial_out <= commands(4);
    mode_out   <= commands(5);

    process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronize command request bits.
            load_meta  <= commands(6);
            load_sync  <= load_meta;

            shift_meta <= commands(7);
            shift_sync <= shift_meta;

            reset_meta <= commands(8);
            reset_sync <= reset_meta;

            -- Save previous synchronized values.
            load_prev  <= load_sync;
            shift_prev <= shift_sync;
        end if;
    end process;

    -- Generate a one-cycle pulse on each rising request.
    load_out  <= load_sync and not load_prev;
    shift_out <= shift_sync and not shift_prev;

    -- Active-high reset, released synchronously.
    reset_out <= reset_sync;

end architecture rtl;
