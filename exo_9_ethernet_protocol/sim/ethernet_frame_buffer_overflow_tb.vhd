
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_frame_buffer_overflow_tb is
end entity;

architecture Behavioral of ethernet_frame_buffer_overflow_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';

    signal data_in     : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid  : std_logic := '0';
    signal data_last   : std_logic := '0';

    signal read_addr   : unsigned(10 downto 0) := (others => '0');
    signal read_data   : std_logic_vector(7 downto 0);

    signal frame_ack   : std_logic := '0';
    signal frame_ready : std_logic;
    signal frame_size  : unsigned(11 downto 0);
    signal overflow    : std_logic;

begin

    -- Horloge de 50 MHz
    clk <= not clk after CLK_PERIOD / 2;

    -- Module teste (DUT)
    uut : entity work.ethernet_frame_buffer
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

    stimulus : process

        -- Envoyer un octet au buffer
        procedure send_byte(
            constant value   : in std_logic_vector(7 downto 0);
            constant is_last : in std_logic
        ) is
        begin
            wait until falling_edge(clk);

            data_in    <= value;
            data_valid <= '1';
            data_last  <= is_last;

            wait until rising_edge(clk);
            wait for 1 ns;

            data_valid <= '0';
            data_last  <= '0';
        end procedure;

        -- Verifier un octet en memoire
        procedure check_byte(
            constant address  : in natural;
            constant expected : in std_logic_vector(7 downto 0)
        ) is
        begin
            read_addr <= to_unsigned(address, read_addr'length);

            -- Lecture synchrone : attendre un front montant
            wait until rising_edge(clk);
            wait for 1 ns;

            assert read_data = expected
                report "Erreur de lecture a l'adresse "
                       & integer'image(address)
                severity error;
        end procedure;

        -- Acquitter la trame
        procedure acknowledge_frame is
        begin
            wait until falling_edge(clk);
            frame_ack <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            frame_ack <= '0';

            assert frame_ready = '0'
                report "frame_ready devrait etre a 0 apres ACK"
                severity error;

            -- Laisser le DUT revenir en IDLE
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

    begin

        ----------------------------------------------------
        -- RESET
        ----------------------------------------------------
        wait for 40 ns;
        wait until falling_edge(clk);
        rst <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        ----------------------------------------------------
        -- TEST 1 : Trame de 3 octets
        ----------------------------------------------------
        report "TEST 1 : trame de 3 octets";

        send_byte(x"AA", '0');
        send_byte(x"BB", '0');
        send_byte(x"CC", '1');

        wait for 1 ns;

        assert frame_ready = '1'
            report "TEST 1 : frame_ready incorrect"
            severity error;

        assert frame_size = to_unsigned(3, frame_size'length)
            report "TEST 1 : frame_size incorrect"
            severity error;

        assert overflow = '0'
            report "TEST 1 : overflow devrait etre a 0"
            severity error;

        check_byte(0, x"AA");
        check_byte(1, x"BB");
        check_byte(2, x"CC");

        acknowledge_frame;

        ----------------------------------------------------
        -- TEST 2 : Trame de 4 octets
        ----------------------------------------------------
        report "TEST 2 : trame de 4 octets";

        send_byte(x"11", '0');
        send_byte(x"22", '0');
        send_byte(x"33", '0');
        send_byte(x"44", '1');

        wait for 1 ns;

        assert frame_ready = '1'
            report "TEST 2 : frame_ready incorrect"
            severity error;

        assert frame_size = to_unsigned(4, frame_size'length)
            report "TEST 2 : frame_size incorrect"
            severity error;

        assert overflow = '0'
            report "TEST 2 : overflow devrait etre a 0"
            severity error;

        check_byte(0, x"11");
        check_byte(1, x"22");
        check_byte(2, x"33");
        check_byte(3, x"44");

        acknowledge_frame;

        ----------------------------------------------------
        -- TEST 3 : Trame de 6 octets (overflow)
        ----------------------------------------------------
        report "TEST 3 : trame de 6 octets";

        send_byte(x"AA", '0');
        send_byte(x"BB", '0');
        send_byte(x"CC", '0');
        send_byte(x"DD", '0');

        -- Cinquieme octet : memoire pleine
        send_byte(x"EE", '0');

        assert overflow = '1'
            report "TEST 3 : overflow non detecte"
            severity error;

        assert frame_ready = '0'
            report "TEST 3 : le module doit etre en DROP"
            severity error;

        -- Sixieme octet : termine la trame
        send_byte(x"FF", '1');

        wait for 1 ns;

        assert frame_ready = '1'
            report "TEST 3 : frame_ready incorrect"
            severity error;

        assert overflow = '1'
            report "TEST 3 : overflow devrait rester a 1"
            severity error;

        assert frame_size = to_unsigned(4, frame_size'length)
            report "TEST 3 : frame_size devrait etre 4"
            severity error;

        -- Les octets supplementaires ne doivent pas
        -- ecraser la memoire existante
        check_byte(0, x"AA");
        check_byte(1, x"BB");
        check_byte(2, x"CC");
        check_byte(3, x"DD");

        acknowledge_frame;

        ----------------------------------------------------
        -- TEST 4 : Nouvelle trame apres overflow
        ----------------------------------------------------
        report "TEST 4 : reutilisation apres overflow";

        send_byte(x"12", '0');
        send_byte(x"34", '1');

        wait for 1 ns;

        assert frame_ready = '1'
            report "TEST 4 : frame_ready incorrect"
            severity error;

        assert frame_size = to_unsigned(2, frame_size'length)
            report "TEST 4 : frame_size incorrect"
            severity error;

        assert overflow = '0'
            report "TEST 4 : overflow should be reset"
            severity error;

        check_byte(0, x"12");
        check_byte(1, x"34");

        acknowledge_frame;

        report "All tests for overflow pass !"
            severity note;

        wait;
    end process;

end Behavioral;
