library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_tx_robustness_tb is
end entity uart_tx_robustness_tb;

architecture uart_tx_robustness_tb_arch
    of uart_tx_robustness_tb is

    --------------------------------------------------
    -- Testbench configuration
    --------------------------------------------------

    constant CLK_FREQ   : positive := 50_000_000;
    constant BAUD_RATE  : positive := 115_200;
    constant CLK_PERIOD : time := 20 ns;

    constant CLKS_PER_BIT : positive :=
        CLK_FREQ / BAUD_RATE;

    constant FRAME_CYCLES : positive :=
        10 * CLKS_PER_BIT;

    --------------------------------------------------
    -- DUT signals
    --------------------------------------------------

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '0';

    signal data_in : std_logic_vector(7 downto 0)
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
        -- Wait for the next clock cycle
        --------------------------------------------------

        procedure next_cycle is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;


        --------------------------------------------------
        -- Wait for multiple clock cycles
        --------------------------------------------------

        procedure wait_cycles (
            constant count : in natural
        ) is
        begin
            for cycle in 1 to count loop
                next_cycle;
            end loop;
        end procedure;


        --------------------------------------------------
        -- Verify idle outputs
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
        -- Start a new transmission
        --------------------------------------------------

        procedure start_transmission (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            check_idle;

            wait until falling_edge(clk);

            data_in  <= value;
            tx_start <= '1';

            next_cycle;

            tx_start <= '0';

            assert tx_busy = '1'
                report "Transmission did not start"
                severity failure;

            assert tx_out = '0'
                report "Invalid START bit"
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
                           ": unexpected DONE pulse"
                    severity failure;

                next_cycle;

            end loop;

        end procedure;


        --------------------------------------------------
        -- Verify transmission completion
        --------------------------------------------------

        procedure check_completion is
        begin

            assert tx_out = '1'
                report "TX must return to IDLE"
                severity failure;

            assert tx_busy = '0'
                report "BUSY must be cleared"
                severity failure;

            assert done = '1'
                report "DONE must be asserted"
                severity failure;

            next_cycle;

            check_idle;

        end procedure;


        --------------------------------------------------
        -- Verify a complete UART frame
        --------------------------------------------------

        procedure check_frame (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            check_bit('0', "START");

            for bit_number in 0 to 7 loop

                check_bit(
                    value(bit_number),
                    "DATA " & integer'image(bit_number)
                );

            end loop;

            check_bit('1', "STOP");

            check_completion;

        end procedure;


    begin

        --------------------------------------------------
        -- Initial reset
        --------------------------------------------------

        reset <= '0';

        wait for 5 * CLK_PERIOD;

        check_idle;

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;


        --------------------------------------------------
        -- TC09: Modify input data during transmission
        --------------------------------------------------

        report "TC09: Input data modification during TX";

        start_transmission(x"55");

        -- Verify START and the first data bit.
        check_bit('0', "START");
        check_bit('1', "DATA 0");

        -- Change the external input during transmission.
        data_in <= x"AA";

        -- The remaining bits must still match 0x55.
        for bit_number in 1 to 7 loop

            check_bit(
                std_logic(to_unsigned(16#55#, 8)(bit_number)),
                "DATA " & integer'image(bit_number)
            );

        end loop;

        check_bit('1', "STOP");

        check_completion;

        report "PASS: Input modification did not corrupt TX"
            severity note;


        --------------------------------------------------
        -- TC10: Transmission request while busy
        --------------------------------------------------

        report "TC10: Transmission request while BUSY";

        start_transmission(x"55");

        check_bit('0', "START");

        -- Inject another request during DATA 0.
        data_in  <= x"AA";
        tx_start <= '1';

        -- Keep checking the original transmission.
        assert tx_out = '1'
            report "Unexpected DATA 0"
            severity failure;

        next_cycle;

        tx_start <= '0';

        -- Verify the remaining cycles of DATA 0.
        for cycle in 1 to CLKS_PER_BIT - 1 loop

            assert tx_out = '1'
                report "DATA 0 corrupted by second request"
                severity failure;

            assert tx_busy = '1'
                report "Transmission interrupted"
                severity failure;

            assert done = '0'
                report "Premature DONE pulse"
                severity failure;

            next_cycle;

        end loop;

        -- Verify the remaining original data bits.
        for bit_number in 1 to 7 loop

            check_bit(
                std_logic(to_unsigned(16#55#, 8)(bit_number)),
                "DATA " & integer'image(bit_number)
            );

        end loop;

        check_bit('1', "STOP");

        check_completion;

        -- Ensure that the rejected request was not queued.
        for cycle in 1 to FRAME_CYCLES loop

            next_cycle;

            check_idle;

        end loop;

        report "PASS: Request while BUSY was ignored"
            severity note;


        --------------------------------------------------
        -- TC11: Reset during transmission
        --------------------------------------------------

        report "TC11: Reset during transmission";

        start_transmission(x"00");

        check_bit('0', "START");

        -- Wait until the transmission is in progress.
        wait_cycles(CLKS_PER_BIT / 2);

        assert tx_busy = '1'
            report "Expected active transmission"
            severity failure;

        assert tx_out = '0'
            report "Expected a low data bit"
            severity failure;

        -- Assert reset between clock edges.
        reset <= '0';

        wait for 1 ns;

        -- Verify asynchronous reset behavior.
        check_idle;

        -- Keep the device in reset for several cycles.
        for cycle in 1 to 5 loop

            next_cycle;

            check_idle;

        end loop;

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;

        -- Ensure that the interrupted frame does not resume.
        for cycle in 1 to FRAME_CYCLES loop

            next_cycle;

            check_idle;

        end loop;

        report "PASS: Reset interrupted the transmission"
            severity note;


        --------------------------------------------------
        -- TC12: Transmission after reset
        --------------------------------------------------

        report "TC12: Transmission after reset";

        start_transmission(x"A6");

        check_frame(x"A6");

        report "PASS: UART recovered successfully after reset"
            severity note;


        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART TX robustness tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_tx_robustness_tb_arch;