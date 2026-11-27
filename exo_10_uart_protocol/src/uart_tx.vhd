library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
    generic (
        CLK_FREQ  : positive := 50_000_000;
        BAUD_RATE : positive := 115_200
    );
    port (
        clk      : in std_logic;
        reset    : in std_logic;
        data_in  : in std_logic_vector(7 downto 0);
        tx_start : in std_logic;

        tx_out   : out std_logic;
        tx_busy  : out std_logic;
        done     : out std_logic
    );
end entity uart_tx;

architecture uart_tx_arch of uart_tx is

    constant CLKS_PER_BIT : positive :=
        CLK_FREQ / BAUD_RATE;

    -- FSM states
    type tx_state is (IDLE, START, DATA, STOP);

    signal state      : tx_state := IDLE;
    signal next_state : tx_state := IDLE;

    -- Timing counter
    signal baud_counter : integer
        range 0 to CLKS_PER_BIT - 1 := 0;

    -- Data bit selection
    signal bit_index : integer
        range 0 to 7 := 0;

    -- Input data storage
    signal data_reg : std_logic_vector(7 downto 0)
        := (others => '0');

    -- Internal control signals
    signal baud_tick   : std_logic;
    signal last_bit    : std_logic;
    signal start_tx    : std_logic;
    signal complete_tx : std_logic;

begin

    --------------------------------------------------
    -- Control signals
    --------------------------------------------------

    baud_tick <= '1'
        when baud_counter = CLKS_PER_BIT - 1
        else '0';

    last_bit <= '1'
        when bit_index = 7
        else '0';

    start_tx <= '1'
        when state = IDLE and tx_start = '1'
        else '0';

    complete_tx <= '1'
        when state = STOP and baud_tick = '1'
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
                if start_tx = '1' then
                    next_state <= START;
                end if;

            when START =>
                if baud_tick = '1' then
                    next_state <= DATA;
                end if;

            when DATA =>
                if baud_tick = '1' and last_bit = '1' then
                    next_state <= STOP;
                end if;

            when STOP =>
                if complete_tx = '1' then
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

            if state = IDLE or baud_tick = '1' then

                baud_counter <= 0;

            else

                baud_counter <= baud_counter + 1;

            end if;

        end if;
    end process baud_counter_process;


    --------------------------------------------------
    -- Input data register
    --------------------------------------------------

    data_register : process(clk, reset)
    begin
        if reset = '0' then

            data_reg <= (others => '0');

        elsif rising_edge(clk) then

            if start_tx = '1' then
                data_reg <= data_in;
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

            elsif state = DATA and baud_tick = '1' then

                if last_bit = '0' then
                    bit_index <= bit_index + 1;
                end if;

            end if;

        end if;
    end process bit_counter_process;


    --------------------------------------------------
    -- Serial output logic
    --------------------------------------------------

    with state select
        tx_out <= '1'                 when IDLE,
                  '0'                 when START,
                  data_reg(bit_index) when DATA,
                  '1'                 when STOP;


    --------------------------------------------------
    -- Busy status
    --------------------------------------------------

    tx_busy <= '0' when state = IDLE else '1';


    --------------------------------------------------
    -- Transmission completion pulse
    --------------------------------------------------

    done_process : process(clk, reset)
    begin
        if reset = '0' then

            done <= '0';

        elsif rising_edge(clk) then

            done <= complete_tx;

        end if;
    end process done_process;

end uart_tx_arch;