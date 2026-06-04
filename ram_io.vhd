
-- ==========================================================
-- Archivo: ram_io.vhd
--
-- Este módulo maneja la RAM interna y también los puertos de entrada/salida.
-- Desde aquí se leen los switches y se controlan las salidas de iluminación y ventilación.
--
-- Se usan dos direcciones especiales:
-- 0xFE para leer los switches: 00000 | sw_modo | sw_ilum | sw_vent
-- 0xFF para guardar las salidas: bit 1 = iluminación, bit 0 = ventilación.
--
-- En modo manual, las salidas dependen de lo que escriba el microcontrolador.
-- En modo automático, se usan contadores para manejar los tiempos de los LEDs y del ventilador.
--
-- Como el reloj es de 50 MHz:
-- 5 s = 250 000 000 ciclos, 10 s = 500 000 000 ciclos y 15 s = 750 000 000 ciclos.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ram_io is
    Port (
        clk         : in  STD_LOGIC;                     -- Reloj principal
        reset       : in  STD_LOGIC;                     -- Reinicia salidas, RAM y contadores
        we          : in  STD_LOGIC;                     -- Permite escribir en RAM o en el puerto de salida
        address     : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dirección de memoria o puerto
        write_data  : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dato que se va a escribir
        read_data   : out STD_LOGIC_VECTOR(7 downto 0);  -- Dato que se lee

        -- Entradas desde los switches físicos.
        sw_modo     : in  STD_LOGIC; -- 0 = manual, 1 = automático
        sw_ilum     : in  STD_LOGIC; -- Control manual de la iluminación
        sw_vent     : in  STD_LOGIC; -- Control manual de la ventilación

        -- Salidas hacia iluminación y ventilación.
        out_ilum    : out STD_LOGIC;
        out_vent    : out STD_LOGIC
    );
end ram_io;

architecture Behavioral of ram_io is

    -- RAM interna de 64 posiciones, cada una de 8 bits.
    type ram_type is array (0 to 63) of STD_LOGIC_VECTOR(7 downto 0);
    signal ram_memory : ram_type := (others => (others => '0'));

    -- Registro donde se guarda lo que el microcontrolador escribe en 0xFF.
    -- El bit 1 controla iluminación y el bit 0 controla ventilación.
    signal reg_salidas : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- Aquí se agrupan los switches para que el microcontrolador los lea como un dato de 8 bits.
    signal entradas_agrupadas : STD_LOGIC_VECTOR(7 downto 0);

    -- Constantes usadas para los tiempos del modo automático.
    constant CICLOS_5_SEGUNDOS  : integer := 250000000;
    constant CICLOS_10_SEGUNDOS : integer := 500000000;
    constant CICLOS_15_SEGUNDOS : integer := 750000000;

    -- Contador para la iluminación automática, con ciclo total de 10 segundos.
    signal contador_led_auto : integer range 0 to CICLOS_10_SEGUNDOS - 1 := 0;

    -- Señal que controla la iluminación cuando está en modo automático.
    signal auto_ilum : STD_LOGIC := '0';

    -- Contador para el ventilador automático, con ciclo total de 15 segundos.
    signal contador_vent_auto : integer range 0 to CICLOS_15_SEGUNDOS - 1 := 0;

    -- Señal que controla el ventilador cuando está en modo automático.
    signal auto_vent : STD_LOGIC := '0';

begin

    -- Los switches se organizan en un solo bus para leerlos desde la dirección 0xFE.
    -- bit 2 = modo, bit 1 = iluminación y bit 0 = ventilación.
    entradas_agrupadas <= "00000" & sw_modo & sw_ilum & sw_vent;

    -- Proceso principal: maneja reset, escritura en RAM/IO y los contadores automáticos.
    process(clk, reset)
    begin
        if reset = '1' then

            -- Con reset se limpian las salidas, la RAM y los contadores.
            reg_salidas        <= (others => '0');
            ram_memory         <= (others => (others => '0'));
            contador_led_auto  <= 0;
            contador_vent_auto <= 0;

        elsif rising_edge(clk) then

            -- Escritura normal desde el microcontrolador.
            -- Si we = '1', se escribe en el puerto 0xFF o en la RAM interna.
            if we = '1' then

                if address = "11111111" then

                    -- En 0xFF se guardan las salidas de iluminación y ventilación.
                    reg_salidas <= write_data;

                elsif unsigned(address) < 64 then

                    -- Escritura en la RAM normal, solo para direcciones de 0 a 63.
                    ram_memory(to_integer(unsigned(address))) <= write_data;

                end if;
            end if;

            -- Los contadores solo avanzan cuando el sistema está en modo automático.
            if sw_modo = '1' then

                -- Contador para la iluminación: 5 segundos ON y 5 segundos OFF.
                if contador_led_auto = CICLOS_10_SEGUNDOS - 1 then
                    contador_led_auto <= 0;
                else
                    contador_led_auto <= contador_led_auto + 1;
                end if;

                -- Contador para el ventilador: 5 segundos ON y 10 segundos OFF.
                if contador_vent_auto = CICLOS_15_SEGUNDOS - 1 then
                    contador_vent_auto <= 0;
                else
                    contador_vent_auto <= contador_vent_auto + 1;
                end if;

            else

                -- Al volver a modo manual, los ciclos automáticos arrancan de nuevo desde cero.
                contador_led_auto  <= 0;
                contador_vent_auto <= 0;

            end if;

        end if;
    end process;

    -- Proceso de lectura para RAM y puertos.
    -- Permite leer switches en 0xFE, salidas en 0xFF y RAM entre 0 y 63.
    process(address, ram_memory, entradas_agrupadas, reg_salidas)
    begin
        if address = "11111110" then

            -- Lectura de switches desde el puerto 0xFE.
            read_data <= entradas_agrupadas;

        elsif address = "11111111" then

            -- Lectura del registro de salidas desde el puerto 0xFF.
            read_data <= reg_salidas;

        elsif unsigned(address) < 64 then

            -- Lectura normal de la RAM interna.
            read_data <= ram_memory(to_integer(unsigned(address)));

        else

            -- Para direcciones que no se usan, se devuelve cero.
            read_data <= (others => '0');

        end if;
    end process;

    -- Iluminación automática:
    -- Se enciende durante los primeros 5 segundos y se apaga los otros 5 segundos.
    auto_ilum <= '1' when contador_led_auto < CICLOS_5_SEGUNDOS else '0';

    -- Ventilador automático:
    -- Se enciende durante 5 segundos y luego queda apagado durante 10 segundos.
    auto_vent <= '1' when contador_vent_auto < CICLOS_5_SEGUNDOS else '0';

    -- Salidas físicas:
    -- Con reset todo se apaga; en automático se usan los contadores y en manual se usa reg_salidas.
    out_ilum <= '0' when reset = '1' else
                auto_ilum when sw_modo = '1' else
                reg_salidas(1);

    out_vent <= '0' when reset = '1' else
                auto_vent when sw_modo = '1' else
                reg_salidas(0);

end Behavioral;
```
