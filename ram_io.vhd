-- ==========================================================
-- Archivo: ram_io.vhd
-- Descripción:
--   Módulo de memoria RAM e interfaz de entrada/salida.
--
-- Funciones principales:
--   1. Implementa una RAM interna de 64 posiciones de 8 bits.
--   2. Permite leer los switches mediante una dirección especial.
--   3. Permite escribir salidas mediante una dirección especial.
--   4. Implementa el modo automático temporizado.
--
-- Direcciones especiales:
--   0xFE = Puerto de entrada
--          Lee los switches:
--          00000 | sw_modo | sw_ilum | sw_vent
--
--   0xFF = Puerto de salida
--          Guarda el registro de actuadores:
--          bit 1 = iluminación
--          bit 0 = ventilación
--
-- Modo manual:
--   Las salidas dependen del valor escrito por el microcontrolador
--   en el registro de salidas.
--
-- Modo automático:
--   La iluminación parpadea:
--      5 segundos encendida / 5 segundos apagada.
--
--   El ventilador trabaja:
--      5 segundos encendido / 10 segundos apagado.
--
-- Reloj usado:
--   La tarjeta DE0 trabaja con CLOCK_50 = 50 MHz.
--   Por eso:
--      5 s  = 250 000 000 ciclos
--      10 s = 500 000 000 ciclos
--      15 s = 750 000 000 ciclos
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_io is
    Port (
        clk         : in  STD_LOGIC;                     -- Reloj principal
        reset       : in  STD_LOGIC;                     -- Reset general
        we          : in  STD_LOGIC;                     -- Habilitador de escritura
        address     : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dirección de memoria o puerto
        write_data  : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dato a escribir
        read_data   : out STD_LOGIC_VECTOR(7 downto 0);  -- Dato leído

        -- Entradas externas desde switches físicos
        sw_modo     : in  STD_LOGIC; -- 0 = manual, 1 = automático
        sw_ilum     : in  STD_LOGIC; -- Control manual de iluminación
        sw_vent     : in  STD_LOGIC; -- Control manual de ventilación

        -- Salidas externas hacia iluminación y ventilación
        out_ilum    : out STD_LOGIC;
        out_vent    : out STD_LOGIC
    );
end ram_io;

architecture Behavioral of ram_io is

    -- RAM interna de 64 posiciones, cada una de 8 bits.
    type ram_type is array (0 to 63) of STD_LOGIC_VECTOR(7 downto 0);
    signal ram_memory : ram_type := (others => (others => '0'));

    -- Registro de salidas.
    -- Aquí se almacena lo que el microcontrolador escribe en 0xFF.
    -- bit 1 = iluminación
    -- bit 0 = ventilación
    signal reg_salidas : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- Señal que agrupa los switches en un solo bus de 8 bits.
    signal entradas_agrupadas : STD_LOGIC_VECTOR(7 downto 0);

    -- ==========================================================
    -- Constantes de tiempo para el modo automático
    -- ==========================================================

    constant CICLOS_5_SEGUNDOS  : integer := 250000000;
    constant CICLOS_10_SEGUNDOS : integer := 500000000;
    constant CICLOS_15_SEGUNDOS : integer := 750000000;

    -- Contador para la iluminación automática.
    -- Cuenta de 0 a 10 segundos.
    signal contador_led_auto : integer range 0 to CICLOS_10_SEGUNDOS - 1 := 0;

    -- Señal automática de iluminación.
    signal auto_ilum : STD_LOGIC := '0';

    -- Contador para el ventilador automático.
    -- Cuenta de 0 a 15 segundos.
    signal contador_vent_auto : integer range 0 to CICLOS_15_SEGUNDOS - 1 := 0;

    -- Señal automática del ventilador.
    signal auto_vent : STD_LOGIC := '0';

begin

    -- ==========================================================
    -- Agrupación de entradas
    -- ==========================================================
    -- El microcontrolador lee esta información desde la dirección 0xFE.
    --
    -- Formato:
    --   bit 2 = sw_modo
    --   bit 1 = sw_ilum
    --   bit 0 = sw_vent
    --
    -- Los bits superiores se dejan en cero.
    -- ==========================================================

    entradas_agrupadas <= "00000" & sw_modo & sw_ilum & sw_vent;

    -- ==========================================================
    -- Proceso principal de escritura, reset y temporización
    -- ==========================================================

    process(clk, reset)
    begin
        if reset = '1' then

            -- Al activar reset:
            -- se limpian las salidas, la RAM y los contadores.
            reg_salidas        <= (others => '0');
            ram_memory         <= (others => (others => '0'));
            contador_led_auto  <= 0;
            contador_vent_auto <= 0;

        elsif rising_edge(clk) then

            -- ==================================================
            -- Escritura normal desde el microcontrolador
            -- ==================================================
            -- Si we = '1', se escribe en RAM o en el puerto 0xFF.
            -- ==================================================

            if we = '1' then

                if address = "11111111" then

                    -- Dirección 0xFF:
                    -- registro de actuadores.
                    -- Aquí el microcontrolador escribe las salidas.
                    reg_salidas <= write_data;

                elsif unsigned(address) < 64 then

                    -- RAM normal:
                    -- solo se usa si la dirección está entre 0 y 63.
                    ram_memory(to_integer(unsigned(address))) <= write_data;

                end if;
            end if;

            -- ==================================================
            -- Temporizadores del modo automático
            -- ==================================================
            -- Los contadores solo avanzan si sw_modo = '1'.
            -- Si el sistema vuelve a modo manual, los contadores
            -- se reinician desde cero.
            -- ==================================================

            if sw_modo = '1' then

                -- Temporizador para iluminación:
                -- ciclo total de 10 segundos.
                if contador_led_auto = CICLOS_10_SEGUNDOS - 1 then
                    contador_led_auto <= 0;
                else
                    contador_led_auto <= contador_led_auto + 1;
                end if;

                -- Temporizador para ventilación:
                -- ciclo total de 15 segundos.
                if contador_vent_auto = CICLOS_15_SEGUNDOS - 1 then
                    contador_vent_auto <= 0;
                else
                    contador_vent_auto <= contador_vent_auto + 1;
                end if;

            else

                -- Al regresar al modo manual, se reinician los ciclos.
                contador_led_auto  <= 0;
                contador_vent_auto <= 0;

            end if;

        end if;
    end process;

    -- ==========================================================
    -- Lectura de RAM y puertos
    -- ==========================================================
    -- Este proceso permite que el datapath lea desde:
    --   0xFE -> switches
    --   0xFF -> registro de salidas
    --   0 a 63 -> RAM interna
    -- ==========================================================

    process(address, ram_memory, entradas_agrupadas, reg_salidas)
    begin
        if address = "11111110" then

            -- Dirección 0xFE:
            -- lectura de switches.
            read_data <= entradas_agrupadas;

        elsif address = "11111111" then

            -- Dirección 0xFF:
            -- lectura del registro de salidas.
            read_data <= reg_salidas;

        elsif unsigned(address) < 64 then

            -- Lectura de RAM normal.
            read_data <= ram_memory(to_integer(unsigned(address)));

        else

            -- Direcciones no usadas.
            read_data <= (others => '0');

        end if;
    end process;

    -- ==========================================================
    -- Lógica automática
    -- ==========================================================

    -- Iluminación automática:
    -- Durante los primeros 5 segundos del ciclo de 10 segundos
    -- la iluminación está encendida.
    -- Luego permanece apagada otros 5 segundos.
    auto_ilum <= '1' when contador_led_auto < CICLOS_5_SEGUNDOS else '0';

    -- Ventilador automático:
    -- Durante los primeros 5 segundos del ciclo de 15 segundos
    -- el ventilador está encendido.
    -- Luego permanece apagado 10 segundos.
    auto_vent <= '1' when contador_vent_auto < CICLOS_5_SEGUNDOS else '0';

    -- ==========================================================
    -- Salidas físicas
    -- ==========================================================
    -- Si reset = 1, todo se apaga.
    --
    -- Si sw_modo = 1, se usan las señales automáticas.
    --
    -- Si sw_modo = 0, se usan las salidas escritas por
    -- el microcontrolador en reg_salidas.
    -- ==========================================================

    out_ilum <= '0' when reset = '1' else
                auto_ilum when sw_modo = '1' else
                reg_salidas(1);

    out_vent <= '0' when reset = '1' else
                auto_vent when sw_modo = '1' else
                reg_salidas(0);

end Behavioral;
