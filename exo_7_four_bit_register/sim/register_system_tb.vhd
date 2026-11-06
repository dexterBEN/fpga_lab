library ieee;
use ieee.std_logic_1164.all;

entity register_system_tb is
end entity register_system_tb;

architecture simulation of register_system_tb is
    -- Verification fonctionnelle RTL, sans validation temporelle physique.
    constant CLK_PERIOD : time := 10 ns;
    constant CHECK_DELAY : time := CLK_PERIOD / 20;
    signal clk          : std_logic := '0';
    signal reset        : std_logic := '0';
    signal load         : std_logic := '0';
    signal shift        : std_logic := '0';
    signal mode         : std_logic := '0';
    signal d            : std_logic_vector(3 downto 0) := "0000";
    signal serial_in    : std_logic := '0';
    signal q            : std_logic_vector(3 downto 0);
    signal finished     : boolean := false;
begin
    dut : entity work.register_system(rtl)
        port map (
            clk => clk, reset => reset, load => load, shift => shift,
            mode => mode, d => d, serial_in => serial_in, q => q
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

    -- Timeout inferieur au --stop-time=1us du Makefile, pour que le
    -- simulateur signale un blocage avant son arret force.
    watchdog : process
    begin
        wait for 500 ns;
        assert finished
            report "Timeout : le testbench register_system ne s'est pas termine"
            severity failure;
        wait;
    end process;

    stimulus : process
        -- Verification des deux etats par le port public uniquement.
        -- MODE pilote uniquement un multiplexeur combinatoire : q doit
        -- changer sans attendre de front montant. Les etats sont conserves.
        -- Les trois delais sont proportionnels a CLK_PERIOD pour garder
        -- les verifications entre deux fronts, avec une marge suffisante.
        procedure check_outputs (
            constant expected_parallel : in std_logic_vector(3 downto 0);
            constant expected_shift    : in std_logic_vector(3 downto 0)
        ) is
        begin
            mode <= '0';
            wait for CHECK_DELAY;
            assert q = expected_parallel
                report "Sortie parallele incorrecte : " & to_string(q)
                severity failure;
            mode <= '1';
            wait for CHECK_DELAY;
            assert q = expected_shift
                report "Sortie SIPO incorrecte : " & to_string(q)
                severity failure;
            mode <= '0';
            wait for CHECK_DELAY;
            assert q = expected_parallel
                report "Echec du retour au mode parallele" severity failure;
        end procedure;

        procedure cycle (
            constant load_value        : in std_logic;
            constant shift_value       : in std_logic;
            constant data_value        : in std_logic_vector(3 downto 0);
            constant serial_value      : in std_logic;
            constant selected_mode     : in std_logic;
            constant expected_parallel : in std_logic_vector(3 downto 0);
            constant expected_shift    : in std_logic_vector(3 downto 0)
        ) is
        begin
            wait until falling_edge(clk);
            load <= load_value;
            shift <= shift_value;
            d <= data_value;
            serial_in <= serial_value;
            mode <= selected_mode;
            wait until rising_edge(clk);
            wait for 1 ns;
            if selected_mode = '0' then
                assert q = expected_parallel
                    report "Echec sortie selectionnee au front" severity failure;
            else
                assert q = expected_shift
                    report "Echec sortie selectionnee au front" severity failure;
            end if;
            check_outputs(expected_parallel, expected_shift);
        end procedure;
    begin
        -- Test 1 : reset commun, sans attendre de front montant.
        wait for 1 ns;
        reset <= '1';
        wait for 1 ns;
        check_outputs("0000", "0000");
        wait until falling_edge(clk);
        reset <= '0';

        -- Test 2 : commandes independantes, y compris sur le registre masque.
        cycle('1', '0', "1010", '0', '1', "1010", "0000");
        cycle('0', '1', "1111", '1', '0', "1010", "0001");
        cycle('0', '1', "0000", '0', '0', "1010", "0010");

        -- Test 3 : les deux operations ont lieu sur le meme front montant.
        cycle('1', '1', "0101", '1', '0', "0101", "0101");
        cycle('1', '1', "1100", '1', '1', "1100", "1011");

        -- Test 4 : conservation sur trois cycles avec entrees variables.
        cycle('0', '0', "0000", '0', '0', "1100", "1011");
        cycle('0', '0', "1111", '1', '1', "1100", "1011");
        cycle('0', '0', "0011", '0', '0', "1100", "1011");

        -- Test 5 : reset des deux etats non nuls entre deux fronts montants.
        -- Courte impulsion pour la simulation fonctionnelle uniquement.
        wait until falling_edge(clk);
        reset <= '1';
        wait for 1 ns;
        check_outputs("0000", "0000");
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        check_outputs("0000", "0000");

        -- Test 6 : reset prioritaire sur les deux commandes actives.
        cycle('1', '1', "1111", '1', '0', "1111", "0001");
        wait until falling_edge(clk);
        reset <= '1';
        wait for 1 ns;
        check_outputs("0000", "0000");
        wait until rising_edge(clk);
        wait for 1 ns;
        check_outputs("0000", "0000");
        wait until falling_edge(clk);
        reset <= '0';
        wait until rising_edge(clk);
        wait for 1 ns;
        check_outputs("1111", "0001");

        report "Tous les tests du systeme de registres ont reussi." severity note;
        finished <= true;
        wait;
    end process;
end architecture simulation;
