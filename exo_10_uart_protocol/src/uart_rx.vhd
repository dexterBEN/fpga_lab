library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
    generic (
        CLK_FREQ  : positive := 50_000_000;
        BAUD_RATE : positive := 115_200
    );
    port (
        clk           : in std_logic;
        reset         : in std_logic;
        rx_in         : in std_logic;

        data_out      : out std_logic_vector(7 downto 0);
        rx_busy       : out std_logic;
        done          : out std_logic;
        framing_error : out std_logic
    );
end entity uart_rx;

architecture uart_rx_arch of uart_rx is

    --------------------------------------------------
    -- Timing configuration
    --------------------------------------------------

    constant CLKS_PER_BIT : positive :=
        CLK_FREQ / BAUD_RATE;

    constant HALF_CLKS_PER_BIT : natural :=
        CLKS_PER_BIT / 2;

    --------------------------------------------------
    -- FSM states
    --------------------------------------------------

    type rx_state is (IDLE, START, DATA, STOP, WAIT_IDLE);

    signal state      : rx_state := IDLE;
    signal next_state : rx_state := IDLE;

    --------------------------------------------------
    -- Input synchronization
    --------------------------------------------------

    signal rx_meta : std_logic := '1';
    signal rx_sync : std_logic := '1';

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of rx_meta : signal is "TRUE";
    attribute ASYNC_REG of rx_sync : signal is "TRUE";

    --------------------------------------------------
    -- Timing counter
    --------------------------------------------------

    signal baud_counter : integer
        range 0 to CLKS_PER_BIT - 1 := 0;

    --------------------------------------------------
    -- Data bit selection
    --------------------------------------------------

    signal bit_index : integer
        range 0 to 7 := 0;

    --------------------------------------------------
    -- Received data storage
    --------------------------------------------------

    signal data_reg : std_logic_vector(7 downto 0)
        := (others => '0');

    --------------------------------------------------
    -- Internal control signals
    --------------------------------------------------

    signal baud_tick       : std_logic;
    signal half_baud_tick  : std_logic;
    signal last_bit        : std_logic;

    signal start_rx        : std_logic;
    signal sample_data     : std_logic;
    signal complete_rx     : std_logic;
    signal valid_stop      : std_logic;

begin

    --------------------------------------------------
    -- Configuration validation
    --------------------------------------------------

    assert CLKS_PER_BIT >= 2
        report "At least two clock cycles per bit are required"
        severity failure;


    --------------------------------------------------
    -- Input synchronizer
    --------------------------------------------------

    input_synchronizer : process(clk, reset)
    begin
        if reset = '0' then

            rx_meta <= '1';
            rx_sync <= '1';

        elsif rising_edge(clk) then

            rx_meta <= rx_in;
            rx_sync <= rx_meta;

        end if;
    end process input_synchronizer;


    --------------------------------------------------
    -- Control signals
    --------------------------------------------------

    baud_tick <= '1'
        when baud_counter = CLKS_PER_BIT - 1
        else '0';

    half_baud_tick <= '1'
        when baud_counter = HALF_CLKS_PER_BIT - 1
        else '0';

    last_bit <= '1'
        when bit_index = 7
        else '0';

    start_rx <= '1'
        when state = IDLE and rx_sync = '0'
        else '0';

    sample_data <= '1'
        when state = DATA and baud_tick = '1'
        else '0';

    complete_rx <= '1'
        when state = STOP and baud_tick = '1'
        else '0';

    valid_stop <= '1'
        when complete_rx = '1' and rx_sync = '1'
        else '0';


    --------------------------------------------------
    -- State register
    --------------------------------------------------

    state_register : process(clk, reset)
    begin
        if reset = '0' then

            state <= IDLE;

        elsif rising_edge(clk) then

            state <= next_state;

        end if;
    end process state_register;


    --------------------------------------------------
    -- State transition logic
    --------------------------------------------------

    transition_logic : process(all)
    begin

        -- Keep the current state by default.
        next_state <= state;

        case state is

            when IDLE =>

                if start_rx = '1' then
                    next_state <= START;
                end if;

            when START =>

                -- Validate the start bit at its midpoint.
                if half_baud_tick = '1' then

                    if rx_sync = '0' then
                        next_state <= DATA;
                    else
                        next_state <= IDLE;
                    end if;

                end if;

            when DATA =>

                -- Transition after sampling all eight bits.
                if sample_data = '1' and last_bit = '1' then
                    next_state <= STOP;
                end if;

            when STOP =>

                -- Validate the stop bit.
                if complete_rx = '1' then

                    if valid_stop = '1' then
                        next_state <= IDLE;
                    else
                        next_state <= WAIT_IDLE;
                    end if;

                end if;

            when WAIT_IDLE =>

                -- Wait for the serial line to return high.
                if rx_sync = '1' then
                    next_state <= IDLE;
                end if;

        end case;

    end process transition_logic;


    --------------------------------------------------
    -- Baud rate counter
    --------------------------------------------------

    baud_counter_process : process(clk, reset)
    begin
        if reset = '0' then

            baud_counter <= 0;

        elsif rising_edge(clk) then

            if state = IDLE or state = WAIT_IDLE then

                baud_counter <= 0;

            elsif state = START and half_baud_tick = '1' then

                baud_counter <= 0;

            elsif baud_tick = '1' then

                baud_counter <= 0;

            else

                baud_counter <= baud_counter + 1;

            end if;

        end if;
    end process baud_counter_process;


    --------------------------------------------------
    -- Received data register
    --------------------------------------------------

    data_register : process(clk, reset)
    begin
        if reset = '0' then

            data_reg <= (others => '0');

        elsif rising_edge(clk) then

            if start_rx = '1' then

                data_reg <= (others => '0');

            elsif sample_data = '1' then

                -- Store each received bit in its position.
                -- UART transmits the least significant bit first.
                data_reg(bit_index) <= rx_sync;

            end if;

        end if;
    end process data_register;


    --------------------------------------------------
    -- Data bit counter
    --------------------------------------------------

    bit_counter_process : process(clk, reset)
    begin
        if reset = '0' then

            bit_index <= 0;

        elsif rising_edge(clk) then

            if state = IDLE then

                bit_index <= 0;

            elsif sample_data = '1' and last_bit = '0' then

                bit_index <= bit_index + 1;

            end if;

        end if;
    end process bit_counter_process;


    --------------------------------------------------
    -- Output data register
    --------------------------------------------------

    output_register : process(clk, reset)
    begin
        if reset = '0' then

            data_out <= (others => '0');

        elsif rising_edge(clk) then

            -- Publish the received byte only after
            -- successful stop bit validation.
            if valid_stop = '1' then

                data_out <= data_reg;

            end if;

        end if;
    end process output_register;


    --------------------------------------------------
    -- Busy status
    --------------------------------------------------

    rx_busy <= '0' when state = IDLE else '1';


    --------------------------------------------------
    -- Reception completion pulse
    --------------------------------------------------

    done_process : process(clk, reset)
    begin
        if reset = '0' then

            done <= '0';

        elsif rising_edge(clk) then

            done <= valid_stop;

        end if;
    end process done_process;


    --------------------------------------------------
    -- Framing error pulse
    --------------------------------------------------

    error_process : process(clk, reset)
    begin
        if reset = '0' then

            framing_error <= '0';

        elsif rising_edge(clk) then

            framing_error <= complete_rx and not rx_sync;

        end if;
    end process error_process;

end architecture uart_rx_arch;