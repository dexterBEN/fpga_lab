library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_tx_tb is
end entity uart_tx_tb;

architecture uart_tx_tb_arch of uart_tx_tb is

    --------------------------------------------------
    -- Testbench configuration
    --------------------------------------------------

    constant CLK_FREQ   : positive := 50_000_000;
    constant BAUD_RATE  : positive := 115_200;
    constant CLK_PERIOD : time := 20 ns;

    constant CLKS_PER_BIT : positive :=
        CLK_FREQ / BAUD_RATE;

    --------------------------------------------------
    -- DUT signals
    --------------------------------------------------

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '0';
    signal data_in  : std_logic_vector(7 downto 0)
        := (others => '0');

    signal tx_start : std_logic := '0';

    signal tx_out   : std_logic;
    signal tx_busy  : std_logic;
    signal done     : std_logic;

begin

    --------------------------------------------------
    -- Device Under Test
    --------------------------------------------------

    dut : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => data_in,
            tx_start => tx_start,
            tx_out   => tx_out,
            tx_busy  => tx_busy,
            done     => done
        );

    --------------------------------------------------
    -- Clock generator
    --------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;

    --------------------------------------------------
    -- Stimulus and verification
    --------------------------------------------------

    stimulus : process

        --------------------------------------------------
        -- Wait for a clock edge and signal stabilization
        --------------------------------------------------

        procedure next_cycle is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        --------------------------------------------------
        -- Verify the idle state
        --------------------------------------------------

        procedure check_idle is
        begin
            assert tx_out = '1'
                report "TX line must be high in IDLE"
                severity failure;

            assert tx_busy = '0'
                report "BUSY must be low in IDLE"
                severity failure;

            assert done = '0'
                report "DONE must be low in IDLE"
                severity failure;
        end procedure;

        --------------------------------------------------
        -- Verify one complete UART bit
        --------------------------------------------------

        procedure check_bit (
            constant expected : in std_logic;
            constant bit_name : in string
        ) is
        begin

            for cycle in 0 to CLKS_PER_BIT - 1 loop

                assert tx_out = expected
                    report bit_name &
                           ": unexpected TX value at cycle " &
                           integer'image(cycle)
                    severity failure;

                assert tx_busy = '1'
                    report bit_name &
                           ": BUSY must remain high"
                    severity failure;

                assert done = '0'
                    report bit_name &
                           ": premature DONE assertion"
                    severity failure;

                next_cycle;

            end loop;

        end procedure;

        --------------------------------------------------
        -- Transmit and verify a complete UART frame
        --------------------------------------------------

        procedure check_frame (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            -- Prepare the input before the rising edge.
            wait until falling_edge(clk);

            data_in  <= value;
            tx_start <= '1';

            -- The DUT accepts the transmission request.
            next_cycle;

            tx_start <= '0';

            -- Verify the start bit.
            check_bit('0', "START");

            -- Verify all eight data bits, LSB first.
            for bit_number in 0 to 7 loop

                check_bit(
                    value(bit_number),
                    "DATA " & integer'image(bit_number)
                );

            end loop;

            -- Verify the stop bit.
            check_bit('1', "STOP");

            -- Verify transmission completion.
            assert tx_out = '1'
                report "TX must return to IDLE"
                severity failure;

            assert tx_busy = '0'
                report "BUSY must be cleared"
                severity failure;

            assert done = '1'
                report "DONE must be asserted"
                severity failure;

            -- DONE must last exactly one clock cycle.
            next_cycle;

            check_idle;

            report "PASS: UART frame 0x" &
                   to_hstring(value)
                severity note;

        end procedure;

    begin

        --------------------------------------------------
        -- TC01: Reset
        --------------------------------------------------

        report "TC01: Reset verification";

        reset <= '0';

        wait for 5 * CLK_PERIOD;

        check_idle;

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;

        report "PASS: Reset";

        --------------------------------------------------
        -- TC02: Idle state
        --------------------------------------------------

        report "TC02: Idle state verification";

        for cycle in 1 to 10 loop

            next_cycle;

            check_idle;

        end loop;

        report "PASS: Idle state";

        --------------------------------------------------
        -- TC03-TC08: Complete frame transmission
        --------------------------------------------------

        report "TC03-TC08: UART frame verification";

        check_frame(x"41");

        --------------------------------------------------
        -- Additional data patterns
        --------------------------------------------------

        check_frame(x"00");
        check_frame(x"FF");
        check_frame(x"55");
        check_frame(x"AA");

        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART TX tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_tx_tb_arch;