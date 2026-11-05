library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity register_axi_wrapper_tb is
end entity;

architecture simulation of register_axi_wrapper_tb is
    signal clk : std_logic := '0';
    signal aresetn : std_logic := '0';
    signal command : std_logic_vector(8 downto 0) := "011111111";
    signal q : std_logic_vector(3 downto 0);
begin
    clk <= not clk after 5 ns;
    dut : entity work.register_axi_wrapper(rtl)
        port map (clk, aresetn, command, q);

    watchdog : process
    begin
        wait for 900 ns;
        assert false report "Timeout register_axi_wrapper_tb" severity failure;
    end process;

    stimulus : process
        function word(constant data : natural;
                      constant serial, select_mode, load_req, shift_req, reset_req : std_logic)
            return std_logic_vector is
        begin
            return reset_req & shift_req & load_req & select_mode & serial
                   & std_logic_vector(to_unsigned(data, 4));
        end function;
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;
        procedure write_command(constant value : std_logic_vector(8 downto 0)) is
        begin
            wait until falling_edge(clk);
            command <= value;
            wait for 1 ns;
        end procedure;
        procedure check_both(constant parallel_value, shift_value : natural) is
        begin
            command(5) <= '0';
            wait for 500 ps;
            assert q = std_logic_vector(to_unsigned(parallel_value, 4))
                report "Valeur parallele incorrecte : " & to_string(q) severity failure;
            command(5) <= '1';
            wait for 500 ps;
            assert q = std_logic_vector(to_unsigned(shift_value, 4))
                report "Valeur SIPO incorrecte : " & to_string(q) severity failure;
        end procedure;
        procedure operate(constant data : natural;
                          constant serial, load_req, shift_req : std_logic;
                          constant expected_parallel, expected_shift : natural) is
        begin
            write_command(word(data, serial, '0', '0', '0', '0'));
            tick; -- donnees en place et demandes rearmees.
            write_command(word(data, serial, '0', load_req, shift_req, '0'));
            tick; -- front exact d'execution, sans cycle supplementaire.
            check_both(expected_parallel, expected_shift);
        end procedure;
    begin
        wait for 2 ns;
        check_both(0, 0);
        wait until falling_edge(clk);
        aresetn <= '1';
        for i in 1 to 4 loop tick; end loop;
        check_both(0, 0); -- demandes hautes initiales ignorees.

        -- Producteur synchrone : le GPIO change APRES un front N.
        -- Aucun chargement au front N ; consommation au front N+1.
        write_command(word(6, '0', '0', '0', '0', '0'));
        tick;
        wait until rising_edge(clk);
        command <= word(6, '0', '0', '1', '0', '0');
        wait for 1 ns;
        assert q = "0000" report "Chargement trop tot au front GPIO" severity failure;
        tick;
        check_both(6, 0);

        operate(10, '0', '1', '0', 10, 0);
        -- Modifier les donnees APRES l'operation ne doit pas recharger.
        write_command(word(3, '1', '1', '1', '0', '0'));
        for i in 1 to 8 loop tick; check_both(10, 0); end loop;

        operate(0, '1', '0', '1', 10, 1);
        -- Une demande shift maintenue ne fait pas avancer le bit a nouveau.
        for i in 1 to 8 loop tick; check_both(10, 1); end loop;
        operate(15, '0', '0', '1', 10, 2);
        operate(5, '1', '1', '1', 5, 5);
        operate(12, '1', '1', '1', 12, 11);

        -- Conservation, entrees variables et changement combinatoire de mode.
        for i in 0 to 2 loop
            write_command(word(i, '0', '0', '0', '0', '0'));
            tick;
            check_both(12, 11);
        end loop;

        -- Reset logiciel pendant deux demandes actives : aucun stockage.
        write_command(word(15, '1', '0', '1', '1', '1'));
        check_both(12, 11); -- la demande Python attend le prochain front.
        tick;
        check_both(0, 0);
        write_command(word(6, '0', '1', '1', '1', '1'));
        tick;
        check_both(0, 0);
        write_command(word(6, '0', '0', '1', '1', '0'));
        for i in 1 to 4 loop tick; check_both(0, 0); end loop;
        operate(9, '1', '1', '1', 9, 1);

        -- Reset infrastructure et reprise, sans operation parasite.
        wait until falling_edge(clk);
        wait for 1 ns;
        aresetn <= '0';
        wait for 1 ns;
        check_both(0, 0);
        tick;
        wait until falling_edge(clk);
        aresetn <= '1';
        for i in 1 to 4 loop tick; check_both(0, 0); end loop;
        operate(3, '0', '1', '1', 3, 0);
        report "Tous les tests de register_axi_wrapper ont reussi." severity note;
        finish;
    end process;
end architecture;
