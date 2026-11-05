library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity command_adapter_tb is
end entity;

architecture simulation of command_adapter_tb is
    constant PERIOD : time := 10 ns;
    signal clk : std_logic := '0';
    signal aresetn : std_logic := '0';
    signal command : std_logic_vector(8 downto 0) := (others => '1');
    signal d : std_logic_vector(3 downto 0);
    signal serial_in, mode, load_pulse, shift_pulse, reset : std_logic;
    signal load_count, shift_count : natural := 0;
begin
    clk <= not clk after PERIOD / 2;
    dut : entity work.command_adapter(rtl)
        port map (clk, aresetn, command, d, serial_in, mode,
                  load_pulse, shift_pulse, reset);

    -- Compte les impulsions effectivement echantillonnees par un enfant.
    counter : process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                load_count <= 0;
                shift_count <= 0;
            else
                if load_pulse = '1' then load_count <= load_count + 1; end if;
                if shift_pulse = '1' then shift_count <= shift_count + 1; end if;
            end if;
        end if;
    end process;

    watchdog : process
    begin
        wait for 900 ns;
        assert false report "Timeout command_adapter_tb" severity failure;
    end process;

    stimulus : process
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
    begin
        wait for 2 ns;
        assert reset = '1' and load_pulse = '0' and shift_pulse = '0'
            report "Demarrage non protege" severity failure;
        assert d = "1111" and serial_in = '1' and mode = '1'
            report "Mapping de donnees incorrect" severity failure;
        write_command("011111111"); -- reset logiciel inactif, demandes hautes.
        aresetn <= '1';
        tick;
        assert reset = '1' report "Reset libere trop tot" severity failure;
        tick;
        assert reset = '0' report "Reset non libere apres deux fronts" severity failure;
        tick;
        assert load_count = 0 and shift_count = 0
            report "Requete haute au demarrage executee" severity failure;

        write_command("000000011");
        tick; -- rearmement des deux demandes.
        write_command("001000011");
        assert load_pulse = '1' and shift_pulse = '0' and d = "0011"
            report "Premiere impulsion load incorrecte" severity failure;
        tick;
        assert load_pulse = '0' and load_count = 1 severity failure;
        for i in 1 to 8 loop tick; end loop;
        assert load_count = 1 report "Load repete avec demande maintenue" severity failure;

        write_command("011010011"); -- shift monte pendant que load reste haut.
        assert shift_pulse = '1' and load_pulse = '0' and serial_in = '1'
            report "Independance des impulsions incorrecte" severity failure;
        tick;
        for i in 1 to 8 loop tick; end loop;
        assert load_count = 1 and shift_count = 1
            report "Shift repete avec demande maintenue" severity failure;

        for i in 1 to 3 loop
            write_command("000000000");
            tick;
            write_command("011101010"); -- load + shift, mode=1, d=1010.
            assert load_pulse = '1' and shift_pulse = '1'
                and mode = '1' and d = "1010" severity failure;
            tick;
        end loop;
        assert load_count = 4 and shift_count = 4
            report "Echec rearmement/commandes simultanees" severity failure;

        write_command("111111111"); -- reset prioritaire, demandes maintenues.
        assert reset = '0' and load_pulse = '0' and shift_pulse = '0'
            report "Reset fonctionnel mal cadence ou commandes non inhibees" severity failure;
        tick;
        assert reset = '1' report "Reset fonctionnel non enregistre" severity failure;
        write_command("111000000"); -- donnees variables pendant reset.
        tick;
        assert reset = '1' and load_count = 0 and shift_count = 0 severity failure;
        write_command("011000000");
        tick;
        assert reset = '1' severity failure;
        tick;
        assert reset = '0' severity failure;
        tick;
        assert load_count = 0 and shift_count = 0
            report "Operation parasite apres reset" severity failure;
        write_command("000000000");
        tick;
        write_command("011000000");
        tick;
        assert load_count = 1 and shift_count = 1
            report "Reprise impossible apres reset" severity failure;

        wait until falling_edge(clk);
        wait for 1 ns;
        aresetn <= '0';
        wait for 1 ns;
        assert reset = '1' and load_pulse = '0' and shift_pulse = '0'
            report "Reset infrastructure non asynchrone" severity failure;
        report "Tous les tests de command_adapter ont reussi." severity note;
        finish;
    end process;
end architecture;
