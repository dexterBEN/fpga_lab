library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity parallel_register_tb is
end entity parallel_register_tb;

architecture simulation of parallel_register_tb is
    -- Verification fonctionnelle RTL uniquement : les contraintes physiques
    -- setup/hold et recovery/removal seront analysees dans Vivado.
    constant CLK_PERIOD : time := 10 ns;
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal enable       : std_logic := '0';
    signal d            : std_logic_vector(3 downto 0) := "0000";
    signal q            : std_logic_vector(3 downto 0);
    signal finished     : boolean := false;
begin
    dut : entity work.parallel_register(rtl)
        port map (
            clk => clk,
            reset => reset,
            enable => enable,
            d => d,
            q => q
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
            report "Timeout : le testbench parallel_register ne s'est pas termine"
            severity failure;
        wait;
    end process;

    stimulus : process
    begin
        -- Test 1 : reset initial sans attendre de front montant.
        wait for 2 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec du reset initial" severity failure;
        -- Test 2 : chargement parallele.
        wait until falling_edge(clk);
        reset <= '0';
        enable <= '1';
        d <= "1010";

        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "1010" report "Echec du chargement de 1010" severity failure;

        -- Test 3 : stabilite entre les fronts et au front descendant.
        d <= "0101";
        wait for 1 ns;
        assert q = "1010" report "Sortie modifiee hors front montant" severity failure;
        wait until falling_edge(clk);
        wait for 1 ns;
        assert q = "1010" report "Sortie modifiee au front descendant" severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0101" report "Echec du chargement de 0101" severity failure;

        -- Test 4 : conservation sur trois cycles avec des entrees variables.
        for i in 13 to 15 loop
            wait until falling_edge(clk);
            enable <= '0';
            d <= std_logic_vector(to_unsigned(i, d'length));
            wait for 1 ns;
            assert q = "0101" report "Valeur modifiee entre les fronts avec enable=0" severity failure;
            wait until rising_edge(clk);
            wait for 1 ns;
            assert q = "0101" report "Valeur non conservee avec enable=0" severity failure;
        end loop;

        -- Test 5 : reset avec enable inactif.
        wait for 1 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec du reset avec enable=0" severity failure;

        -- Test 6 : priorite du reset au front montant avec enable actif.
        wait until falling_edge(clk);
        enable <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0000" report "Reset non prioritaire" severity failure;

        -- Test 7 : reprise du chargement apres reset.
        wait until falling_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "1111" report "Echec du chargement apres reset" severity failure;

        -- Test 8 : impulsion de reset entierement entre deux fronts montants.
        -- Impulsion courte pour la simulation fonctionnelle uniquement.
        wait until falling_edge(clk);
        enable <= '0';
        wait for 1 ns;
        reset <= '1';
        wait for 1 ns;
        assert q = "0000" report "Echec du reset entre deux fronts" severity failure;
        reset <= '0';
        wait for 1 ns;
        assert q = "0000" report "Sortie modifiee a la desactivation du reset" severity failure;
        wait until rising_edge(clk);
        wait for 1 ns;
        assert q = "0000" report "Valeur non conservee apres reset" severity failure;

        -- Test 9 : chargement des 16 combinaisons possibles.
        for i in 0 to 15 loop
            wait until falling_edge(clk);
            enable <= '1';
            d <= std_logic_vector(to_unsigned(i, d'length));
            wait until rising_edge(clk);
            wait for 1 ns;
            assert q = std_logic_vector(to_unsigned(i, q'length))
                report "Echec du chargement de la valeur " & integer'image(i)
                severity failure;
        end loop;

        report "Tous les tests ont reussi." severity note;
        finished <= true;
        wait;
    end process;
end architecture simulation;
