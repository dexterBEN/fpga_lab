
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_frame_buffer_gpio_bridge_tb is
end entity;

architecture Behavioral of ethernet_frame_buffer_gpio_bridge_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal cmd_word    : std_logic_vector(31 downto 0)
                         := (others => '0');
    signal status_word : std_logic_vector(31 downto 0);

    signal data_in     : std_logic_vector(7 downto 0);
    signal data_valid  : std_logic;
    signal data_last   : std_logic;

    signal read_addr   : unsigned(10 downto 0);
    signal read_data   : std_logic_vector(7 downto 0);

    signal frame_ack   : std_logic;
    signal frame_ready : std_logic;
    signal frame_size  : unsigned(11 downto 0);
    signal overflow    : std_logic;

begin

    -- Horloge 50 MHz
    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------
    -- GPIO Bridge
    --------------------------------------------------

    bridge : entity work.ethernet_frame_buffer_gpio_bridge
        port map (
            clk         => clk,
            rst         => rst,

            cmd_word    => cmd_word,
            status_word => status_word,

            data_in     => data_in,
            data_valid  => data_valid,
            data_last   => data_last,

            read_addr   => read_addr,
            read_data   => read_data,

            frame_ack   => frame_ack,
            frame_ready => frame_ready,
            frame_size  => frame_size,
            overflow    => overflow
        );


    --------------------------------------------------
    -- Ethernet Frame Buffer
    --------------------------------------------------

    buffer_dut : entity work.ethernet_frame_buffer
        generic map (
            BUFFER_SIZE => 4
        )
        port map (
            clk         => clk,
            rst         => rst,

            data_in     => data_in,
            data_valid  => data_valid,
            data_last   => data_last,

            read_addr   => read_addr,
            read_data   => read_data,

            frame_ack   => frame_ack,
            frame_ready => frame_ready,
            frame_size  => frame_size,
            overflow    => overflow
        );


    --------------------------------------------------
    -- Stimulus
    --------------------------------------------------

    stimulus : process

        variable cmd : std_logic_vector(31 downto 0)
                       := (others => '0');

        -- Attendre la confirmation d'un toggle
        procedure wait_seen(
            constant status_bit : in natural;
            constant expected   : in std_logic
        ) is
            variable confirmed : boolean := false;
        begin
            for i in 1 to 20 loop
                wait until rising_edge(clk);
                wait for 1 ns;

                if status_word(status_bit) = expected then
                    confirmed := true;
                    exit;
                end if;
            end loop;

            assert confirmed
                report "Timeout de confirmation GPIO, bit "
                    & integer'image(status_bit)
                severity failure;
        end procedure;


        -- Envoyer un octet
        procedure send_byte(
            constant value   : in std_logic_vector(7 downto 0);
            constant is_last : in std_logic
        ) is
        begin
            wait until falling_edge(clk);

            cmd(7 downto 0) := value;
            cmd(8) := is_last;

            -- Changer le toggle d'envoi
            cmd(9) := not cmd(9);

            cmd_word <= cmd;

            -- Bit 22 du status = send_seen
            wait_seen(22, cmd(9));
        end procedure;


        -- Lire un octet par le bridge
        procedure check_byte(
            constant address  : in natural;
            constant expected : in std_logic_vector(7 downto 0)
        ) is
        begin
            wait until falling_edge(clk);

            cmd(21 downto 11) :=
                std_logic_vector(to_unsigned(address, 11));

            cmd(22) := not cmd(22);
            cmd_word <= cmd;

            -- Bit 24 du status = read_seen
            wait_seen(24, cmd(22));

            assert status_word(7 downto 0) = expected
                report "Lecture incorrecte a l'adresse "
                    & integer'image(address)
                severity error;
        end procedure;


        -- Acquitter une trame
        procedure acknowledge_frame is
        begin
            wait until falling_edge(clk);

            cmd(10) := not cmd(10);
            cmd_word <= cmd;

            -- Bit 23 du status = ack_seen
            wait_seen(23, cmd(10));

            assert status_word(20) = '0'
                report "frame_ready reste actif apres ACK"
                severity error;

            -- Laisser passer le retour en IDLE
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;


        -- Verifier taille, ready et overflow
        procedure check_status(
            constant expected_size     : in natural;
            constant expected_overflow : in std_logic
        ) is
        begin
            assert status_word(20) = '1'
                report "frame_ready devrait etre a 1"
                severity error;

            assert unsigned(status_word(19 downto 8)) =
                   to_unsigned(expected_size, 12)
                report "frame_size incorrect"
                severity error;

            assert status_word(21) = expected_overflow
                report "overflow incorrect"
                severity error;
        end procedure;

    begin

        --------------------------------------------------
        -- RESET
        --------------------------------------------------

        wait for 40 ns;
        wait until falling_edge(clk);

        rst <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;


        --------------------------------------------------
        -- TEST 1 : Trame normale de 3 octets
        --------------------------------------------------

        report "TEST 1 : reception normale via GPIO";

        send_byte(x"AA", '0');
        send_byte(x"BB", '0');
        send_byte(x"CC", '1');

        check_status(3, '0');

        check_byte(0, x"AA");
        check_byte(1, x"BB");
        check_byte(2, x"CC");

        acknowledge_frame;


        --------------------------------------------------
        -- TEST 2 : Trame de 4 octets
        --------------------------------------------------

        report "TEST 2 : capacite exacte du buffer";

        send_byte(x"11", '0');
        send_byte(x"22", '0');
        send_byte(x"33", '0');
        send_byte(x"44", '1');

        check_status(4, '0');

        check_byte(0, x"11");
        check_byte(1, x"22");
        check_byte(2, x"33");
        check_byte(3, x"44");

        acknowledge_frame;


        --------------------------------------------------
        -- TEST 3 : Trame de 6 octets (DROP)
        --------------------------------------------------

        report "TEST 3 : depassement memoire";

        send_byte(x"AA", '0');
        send_byte(x"BB", '0');
        send_byte(x"CC", '0');
        send_byte(x"DD", '0');

        send_byte(x"EE", '0');

        assert status_word(21) = '1'
            report "overflow non detecte"
            severity error;

        assert status_word(20) = '0'
            report "frame_ready premature"
            severity error;

        send_byte(x"FF", '1');

        check_status(4, '1');

        check_byte(0, x"AA");
        check_byte(1, x"BB");
        check_byte(2, x"CC");
        check_byte(3, x"DD");

        acknowledge_frame;


        --------------------------------------------------
        -- TEST 4 : Reutilisation apres overflow
        --------------------------------------------------

        report "TEST 4 : nouvelle trame apres overflow";

        send_byte(x"12", '0');
        send_byte(x"34", '1');

        check_status(2, '0');

        check_byte(0, x"12");
        check_byte(1, x"34");

        acknowledge_frame;


        --------------------------------------------------
        -- FIN
        --------------------------------------------------

        report "Tous les tests GPIO Bridge sont passes !"
            severity note;

        wait;

    end process;

end Behavioral;
