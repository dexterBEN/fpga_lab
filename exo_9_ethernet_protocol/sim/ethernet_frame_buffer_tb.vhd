library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_frame_buffer_tb is
end entity;

architecture Behavioral of ethernet_frame_buffer_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';

    signal data_in     : std_logic_vector(7 downto 0)
                        := (others => '0');
    signal data_valid  : std_logic := '0';
    signal data_last   : std_logic := '0';

    signal read_addr   : unsigned(10 downto 0)
                        := (others => '0');
    signal read_data   : std_logic_vector(7 downto 0);

    signal frame_ack   : std_logic := '0';
    signal frame_ready : std_logic;
    signal frame_size  : unsigned(11 downto 0);

begin

    -- Horloge 50 MHz
    clk <= not clk after CLK_PERIOD / 2;

    uut : entity work.ethernet_frame_buffer
        generic map (
            BUFFER_SIZE => 2048
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
            frame_size  => frame_size
        );

    stimulus : process

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

        procedure check_byte(
            constant address  : in natural;
            constant expected : in std_logic_vector(7 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            read_addr <= to_unsigned(address, read_addr'length);

            wait until rising_edge(clk);
            wait for 1 ns;

            assert read_data = expected
                report "Erreur de lecture a l'adresse "
                       & integer'image(address)
                severity error;
        end procedure;

    begin

        -- Test 1 : reset
        wait for 2 * CLK_PERIOD;
        wait until falling_edge(clk);
        rst <= '0';

        wait for 1 ns;
        assert frame_ready = '0'
            report "frame_ready doit etre a 0"
            severity error;

        -- Test 2 : reception de quatre octets
        
        -- MAC destination : 00:E0:4C:68:27:F6
        send_byte(x"00", '0');
        send_byte(x"E0", '0');
        send_byte(x"4C", '0');
        send_byte(x"68", '0');
        send_byte(x"27", '0');
        send_byte(x"F6", '0');

        -- MAC source : 76:D6:D6:82:15:66
        send_byte(x"76", '0');
        send_byte(x"D6", '0');
        send_byte(x"D6", '0');
        send_byte(x"82", '0');
        send_byte(x"15", '0');
        send_byte(x"66", '0');

        -- EtherType : 0x0800 (IPv4)
        send_byte(x"08", '0');
        send_byte(x"00", '1');  -- last byte


        -- Test 3 : fin de trame
        wait for 1 ns;

        assert frame_ready = '1'
            report "La trame devrait etre disponible"
            severity error;

        assert frame_size = to_unsigned(14, frame_size'length)
            report "should be a frame of size 14 byte"
            severity error;

        -- Test 4 : lecture de la memoire
        
        -- Check destination MAC
        check_byte(0,  x"00");
        check_byte(1,  x"E0");
        check_byte(2,  x"4C");
        check_byte(3,  x"68");
        check_byte(4,  x"27");
        check_byte(5,  x"F6");

        -- Check source MAC
        check_byte(6,  x"76");
        check_byte(7,  x"D6");
        check_byte(8,  x"D6");
        check_byte(9,  x"82");
        check_byte(10, x"15");
        check_byte(11, x"66");

        -- Check l'EtherType
        check_byte(12, x"08");
        check_byte(13, x"00");


        -- Test 5 : acquittement
        wait until falling_edge(clk);
        frame_ack <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;
        frame_ack <= '0';

        assert frame_ready = '0'
            report "frame_ready doit revenir a 0"
            severity error;

        report "Tous les tests sont passes !" severity note;

        wait;
    end process;

end Behavioral;
