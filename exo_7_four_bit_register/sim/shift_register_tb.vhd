library ieee;
use ieee.std_logic_1164.all;

entity shift_register_tb is
end entity shift_register_tb;

architecture simulation of shift_register_tb is
    -- Verification RTL, sans validation des contraintes temporelles physiques.
    constant CLK_PERIOD : time := 10 ns;
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal shift        : std_logic := '0';
    signal serial_in    : std_logic := '0';
    signal q            : std_logic_vector(3 downto 0);
    signal finished     : boolean := false;
begin
    dut : entity work.shift_register(rtl)
        port map (
            clk => clk, reset => reset, shift => shift,
            serial_in => serial_in, q => q
        );

    clock_generator : process
    begin
        while not finished loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Timeout avant le --stop-time=1us du Makefile.
    watchdog : process
    begin
        wait for 500 ns;
        assert finished
            report "Timeout : le testbench shift_register ne s'est pas termine"
            severity failure;
        wait;
    end process;

    stimulus : process
        -- Les entrees changent au front descendant pour preparer le suivant.
        procedure shift_bit (
            constant bit_in   : in std_logic;
            constant expected : in std_logic_vector(3 downto 0)
        ) is
            variable previous_q : std_logic_vector(3 downto 0);
        begin
            previous_q := q;
            wait until falling_edge(clk);
            shift <= '1';
            serial_in <= bit_in;
            wait for 1 ns;
            assert q = previous_q
                report "Sortie modifiee hors front montant" severity failure;
            wait until rising_edge(clk);
            wait for 1 ns;
            assert q = expected
                report "Echec du decalage : attendu " & to_string(expected)
                & ", obtenu " & to_string(q) severity failure;
        end procedure;
    begin
        -- Test 1 : reset initial asynchrone.
        wait for 2 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec du reset initial" severity failure;
        reset <= '0';

        -- Test 2 : un bit traverse les quatre positions, puis sort.
        shift_bit('1', "0001");
        shift_bit('0', "0010");
        shift_bit('0', "0100");
        shift_bit('0', "1000");
        shift_bit('0', "0000");

        -- Test 3 : insertion successive de 1, 0, 1, 1 => 1011.
        shift_bit('1', "0001");
        shift_bit('0', "0010");
        shift_bit('1', "0101");
        shift_bit('1', "1011");

        -- Test 4 : conservation pendant trois cycles, entree serie variable.
        for i in 0 to 2 loop
            wait until falling_edge(clk);
            shift <= '0';
            if i = 1 then
                serial_in <= '1';
            else
                serial_in <= '0';
            end if;
            wait for 1 ns;
            assert q = "1011" report "Echec conservation hors front" severity failure;
            wait until rising_edge(clk);
            wait for 1 ns;
            assert q = "1011" report "Echec conservation avec shift=0" severity failure;
        end loop;

        -- Test 5 : impulsion de reset entre deux fronts, avec shift inactif.
        -- Duree courte pour la simulation fonctionnelle uniquement.
        wait until falling_edge(clk);
        wait for 1 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec reset asynchrone" severity failure;
        reset <= '0';
        wait for 1 ns;
        assert q = "0000" report "Sortie modifiee a la fin du reset" severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0000" report "Echec conservation apres reset" severity failure;

        -- Test 6 : reset prioritaire sur shift, avant et au front montant.
        shift_bit('1', "0001");
        wait until falling_edge(clk);
        serial_in <= '1';
        wait for 1 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec reset avec shift=1" severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0000" report "Reset non prioritaire" severity failure;
        wait until falling_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0001" report "Echec reprise apres reset" severity failure;

        report "Tous les tests du registre a decalage ont reussi." severity note;
        finished <= true;
        wait;
    end process;
end architecture simulation;
