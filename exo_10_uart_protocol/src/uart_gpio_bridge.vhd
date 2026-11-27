library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_gpio_bridge is
    generic (
        CLK_FREQ     : positive := 50_000_000;
        TX_BAUD_RATE : positive := 115_200;
        RX_BAUD_RATE : positive := 115_200
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;

        -- PS to PL command register
        command_in : in std_logic_vector(31 downto 0);

        -- PL to PS status register
        status_out : out std_logic_vector(31 downto 0)
    );
end entity uart_gpio_bridge;

architecture uart_gpio_bridge_arch
    of uart_gpio_bridge is

    --------------------------------------------------
    -- Command register bit mapping
    --------------------------------------------------

    constant CMD_REQUEST_BIT : natural := 8;

    --------------------------------------------------
    -- Status register bit mapping
    --------------------------------------------------

    constant STATUS_ACK_BIT    : natural := 8;
    constant STATUS_ACTIVE_BIT : natural := 9;
    constant STATUS_TX_BUSY_BIT : natural := 10;
    constant STATUS_RX_BUSY_BIT : natural := 11;
    constant STATUS_TX_DONE_BIT : natural := 12;
    constant STATUS_RX_DONE_BIT : natural := 13;
    constant STATUS_ERROR_BIT   : natural := 14;

    --------------------------------------------------
    -- UART TX signals
    --------------------------------------------------

    signal tx_data : std_logic_vector(7 downto 0)
        := (others => '0');

    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_done  : std_logic;

    --------------------------------------------------
    -- UART RX signals
    --------------------------------------------------

    signal rx_data : std_logic_vector(7 downto 0);

    signal rx_busy       : std_logic;
    signal rx_done       : std_logic;
    signal framing_error : std_logic;

    --------------------------------------------------
    -- Internal UART loopback
    --------------------------------------------------

    signal serial_line : std_logic;

    --------------------------------------------------
    -- Command and handshake signals
    --------------------------------------------------

    signal tx_request : std_logic;
    signal tx_ack     : std_logic := '0';

    signal transaction_active : std_logic := '0';

    signal request_pending : std_logic;
    signal accept_request  : std_logic;

    signal transaction_complete : std_logic;

    --------------------------------------------------
    -- Persistent status registers
    --------------------------------------------------

    signal tx_done_reg : std_logic := '0';
    signal rx_done_reg : std_logic := '0';
    signal error_reg   : std_logic := '0';

    signal rx_data_reg : std_logic_vector(7 downto 0)
        := (others => '0');

begin

    --------------------------------------------------
    -- UART transmitter
    --------------------------------------------------

    transmitter : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => TX_BAUD_RATE
        )
        port map (
            clk      => clk,
            reset    => reset,

            data_in  => tx_data,
            tx_start => tx_start,

            tx_out   => serial_line,
            tx_busy  => tx_busy,
            done     => tx_done
        );


    --------------------------------------------------
    -- UART receiver
    --------------------------------------------------

    receiver : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => RX_BAUD_RATE
        )
        port map (
            clk           => clk,
            reset         => reset,

            rx_in         => serial_line,

            data_out      => rx_data,
            rx_busy       => rx_busy,
            done          => rx_done,
            framing_error => framing_error
        );


    --------------------------------------------------
    -- Command decoding
    --------------------------------------------------

    tx_request <= command_in(CMD_REQUEST_BIT);


    --------------------------------------------------
    -- Request detection
    --------------------------------------------------

    -- A new request exists when REQUEST and ACK
    -- have different values.

    request_pending <= tx_request xor tx_ack;


    --------------------------------------------------
    -- Request acceptance
    --------------------------------------------------

    -- Accept a request only when the complete UART
    -- subsystem is available.

    accept_request <= '1' when
        request_pending = '1'
        and transaction_active = '0'
        and tx_busy = '0'
        and rx_busy = '0'
        else '0';


    --------------------------------------------------
    -- Transaction completion detection
    --------------------------------------------------

    -- A transaction is complete when TX has finished
    -- and RX has either received a byte or detected
    -- a framing error.

    transaction_complete <=
        (tx_done_reg or tx_done)
        and
        (rx_done_reg or rx_done
         or error_reg or framing_error);


    --------------------------------------------------
    -- Command and handshake management
    --------------------------------------------------

    command_process : process(clk, reset)
    begin

        if reset = '0' then

            tx_data <= (others => '0');

            tx_start <= '0';
            tx_ack   <= '0';

            transaction_active <= '0';

        elsif rising_edge(clk) then

            -- Generate a single-cycle START pulse.
            tx_start <= '0';

            if accept_request = '1' then

                -- Latch the byte provided by the PS.
                tx_data <= command_in(7 downto 0);

                -- Acknowledge the accepted request.
                tx_ack <= tx_request;

                -- Trigger the UART transmitter.
                tx_start <= '1';

                transaction_active <= '1';

            elsif transaction_active = '1'
                and transaction_complete = '1'
            then

                transaction_active <= '0';

            end if;

        end if;

    end process command_process;


    --------------------------------------------------
    -- Persistent status register management
    --------------------------------------------------

    status_register_process : process(clk, reset)
    begin

        if reset = '0' then

            tx_done_reg <= '0';
            rx_done_reg <= '0';
            error_reg   <= '0';

            rx_data_reg <= (others => '0');

        elsif rising_edge(clk) then

            if accept_request = '1' then

                -- Clear completion flags when a new
                -- transaction is accepted.

                tx_done_reg <= '0';
                rx_done_reg <= '0';
                error_reg   <= '0';

            elsif transaction_active = '1' then

                --------------------------------------
                -- Transmitter completion
                --------------------------------------

                if tx_done = '1' then

                    tx_done_reg <= '1';

                end if;


                --------------------------------------
                -- Receiver completion
                --------------------------------------

                if rx_done = '1' then

                    rx_done_reg <= '1';

                    -- Preserve the last valid byte.
                    rx_data_reg <= rx_data;

                end if;


                --------------------------------------
                -- Receiver framing error
                --------------------------------------

                if framing_error = '1' then

                    error_reg <= '1';

                end if;

            end if;

        end if;

    end process status_register_process;


    --------------------------------------------------
    -- Status register mapping
    --------------------------------------------------

    status_out(7 downto 0) <= rx_data_reg;

    status_out(STATUS_ACK_BIT) <= tx_ack;

    status_out(STATUS_ACTIVE_BIT) <=
        transaction_active;

    status_out(STATUS_TX_BUSY_BIT) <= tx_busy;

    status_out(STATUS_RX_BUSY_BIT) <= rx_busy;

    status_out(STATUS_TX_DONE_BIT) <= tx_done_reg;

    status_out(STATUS_RX_DONE_BIT) <= rx_done_reg;

    status_out(STATUS_ERROR_BIT) <= error_reg;

    -- Reserved bits
    status_out(31 downto 15) <= (others => '0');

end architecture uart_gpio_bridge_arch;