library ieee;
use ieee.std_logic_1164.all;

-- Bus AXI GPIO, dans le MEME domaine d'horloge que clk :
-- 3:0=data, 4=serial_in, 5=mode, 6=load_request, 7=shift_request,
-- 8=reset_request. Voir docs/integration_pynq.md pour le protocole.
entity command_adapter is
    port (
        clk         : in  std_logic;
        aresetn     : in  std_logic;
        command     : in  std_logic_vector(8 downto 0);
        d           : out std_logic_vector(3 downto 0);
        serial_in   : out std_logic;
        mode        : out std_logic;
        load_pulse  : out std_logic;
        shift_pulse : out std_logic;
        reset       : out std_logic
    );
end entity command_adapter;

architecture rtl of command_adapter is
    -- INIT assure un demarrage en reset sur FPGA ; l'infrastructure doit
    -- aussi affirmer aresetn='0' au demarrage. Deux etages de liberation.
    signal reset_pipe     : std_logic_vector(1 downto 0) := "11";
    signal reset_internal : std_logic;
    signal load_previous  : std_logic := '1';
    signal shift_previous : std_logic := '1';
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of reset_pipe : signal is "TRUE";
begin
    -- Seule l'infrastructure utilise les entrees asynchrones des bascules.
    -- La requete Python est deja synchrone : elle passe par le chemin D,
    -- evitant une LUT multi-entrees devant les pins PRE/CLR (LUTAR-1).
    reset_conditioner : process (clk, aresetn)
    begin
        if aresetn = '0' then
            reset_pipe <= "11";
        elsif rising_edge(clk) then
            if command(8) = '1' then
                reset_pipe <= "11";
            else
                reset_pipe <= reset_pipe(0) & '0';
            end if;
        end if;
    end process;

    reset_internal <= reset_pipe(1);
    reset <= reset_internal;

    request_history : process (clk, reset_internal)
    begin
        if reset_internal = '1' then
            -- Une demande deja haute au reset ne cree pas d'operation.
            -- Un zero doit etre echantillonne pour rearmer chaque commande.
            load_previous <= '1';
            shift_previous <= '1';
        elsif rising_edge(clk) then
            load_previous <= command(6);
            shift_previous <= command(7);
        end if;
    end process;

    -- Impulsions combinatoires issues de sources synchrones enregistrees.
    -- Apres une ecriture GPIO au front N, le registre enfant opere au
    -- front N+1. Les donnees restent stables jusqu'a ce front inclus.
    -- Le reset logiciel inhibe les commandes des son apparition, avant
    -- son assertion enregistree au front suivant.
    load_pulse <= command(6) and not load_previous and not reset_internal and not command(8);
    shift_pulse <= command(7) and not shift_previous and not reset_internal and not command(8);
    d <= command(3 downto 0);
    serial_in <= command(4);
    mode <= command(5);
end architecture rtl;
