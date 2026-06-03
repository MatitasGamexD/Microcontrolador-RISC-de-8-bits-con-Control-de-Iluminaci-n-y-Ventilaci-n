-- ==========================================================
-- Archivo: cpu_top_tb.vhd
-- Descripción:
--   Testbench del proyecto.
--
-- Función:
--   Permite simular el módulo principal cpu_top en ModelSim.
--
-- Pruebas realizadas:
--   1. Reset inicial.
--   2. Modo manual con iluminación encendida.
--   3. Modo manual con ventilación encendida.
--   4. Modo manual con ambas salidas encendidas.
--   5. Modo manual con ambas salidas apagadas.
--   6. Entrada a modo automático.
--   7. Reset mientras está en modo automático.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cpu_top_tb is
end cpu_top_tb;

architecture Behavioral of cpu_top_tb is

    -- ==========================================================
    -- Declaración del componente bajo prueba, UUT
    -- ==========================================================

    component cpu_top
        Port (
            clk       : in  STD_LOGIC;
            reset     : in  STD_LOGIC;

            sw_modo   : in  STD_LOGIC;
            sw_ilum   : in  STD_LOGIC;
            sw_vent   : in  STD_LOGIC;

            out_ilum  : out STD_LOGIC;
            out_vent  : out STD_LOGIC;

            gpio_ilum : out STD_LOGIC;
            gpio_vent : out STD_LOGIC
        );
    end component;

    -- ==========================================================
    -- Señales internas del testbench
    -- ==========================================================

    signal clk_tb       : STD_LOGIC := '0';
    signal reset_tb     : STD_LOGIC := '0';

    signal sw_modo_tb   : STD_LOGIC := '0';
    signal sw_ilum_tb   : STD_LOGIC := '0';
    signal sw_vent_tb   : STD_LOGIC := '0';

    signal out_ilum_tb  : STD_LOGIC;
    signal out_vent_tb  : STD_LOGIC;

    signal gpio_ilum_tb : STD_LOGIC;
    signal gpio_vent_tb : STD_LOGIC;

    -- Reloj de la DE0:
    -- 50 MHz equivale a un periodo de 20 ns.
    constant CLK_PERIOD : time := 20 ns;

begin

    -- ==========================================================
    -- Instancia del microcontrolador completo
    -- ==========================================================
    -- UUT significa Unit Under Test, unidad bajo prueba.
    -- Aquí se conecta el testbench con el módulo cpu_top.
    -- ==========================================================

    UUT: cpu_top
        port map (
            clk       => clk_tb,
            reset     => reset_tb,

            sw_modo   => sw_modo_tb,
            sw_ilum   => sw_ilum_tb,
            sw_vent   => sw_vent_tb,

            out_ilum  => out_ilum_tb,
            out_vent  => out_vent_tb,

            gpio_ilum => gpio_ilum_tb,
            gpio_vent => gpio_vent_tb
        );

    -- ==========================================================
    -- Generador de reloj
    -- ==========================================================
    -- Genera una señal cuadrada de 50 MHz:
    --   10 ns en bajo
    --   10 ns en alto
    --   total = 20 ns
    -- ==========================================================

    clk_process : process
    begin
        clk_tb <= '0';
        wait for CLK_PERIOD / 2;

        clk_tb <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- ==========================================================
    -- Proceso de estímulos
    -- ==========================================================
    -- Aquí se cambian las entradas del sistema para probar
    -- diferentes condiciones de funcionamiento.
    -- ==========================================================

    stim_proc : process
    begin

        -- ======================================================
        -- PRUEBA 1: RESET INICIAL
        -- ======================================================
        -- Se activa reset para comprobar que todas las salidas
        -- arranquen apagadas.
        -- ======================================================

        report "PRUEBA 1: Reset inicial";

        reset_tb   <= '1';
        sw_modo_tb <= '0';
        sw_ilum_tb <= '0';
        sw_vent_tb <= '0';

        wait for 200 ns;

        assert out_ilum_tb = '0'
            report "ERROR: out_ilum deberia estar apagado durante reset"
            severity error;

        assert out_vent_tb = '0'
            report "ERROR: out_vent deberia estar apagado durante reset"
            severity error;

        assert gpio_ilum_tb = '0'
            report "ERROR: gpio_ilum deberia estar apagado durante reset"
            severity error;

        assert gpio_vent_tb = '0'
            report "ERROR: gpio_vent deberia estar apagado durante reset"
            severity error;

        -- Se desactiva reset para que el microcontrolador comience
        -- a ejecutar el programa desde la ROM.
        reset_tb <= '0';
        wait for 2 us;

        -- ======================================================
        -- PRUEBA 2: MODO MANUAL - ILUMINACIÓN ENCENDIDA
        -- ======================================================
        -- SW0 = 0 -> modo manual
        -- SW1 = 1 -> iluminación encendida
        -- SW2 = 0 -> ventilación apagada
        -- ======================================================

        report "PRUEBA 2: Modo manual, iluminacion ON, ventilacion OFF";

        sw_modo_tb <= '0';
        sw_ilum_tb <= '1';
        sw_vent_tb <= '0';

        wait for 5 us;

        assert out_ilum_tb = '1'
            report "ERROR: En modo manual, out_ilum deberia estar encendido"
            severity error;

        assert gpio_ilum_tb = '1'
            report "ERROR: En modo manual, gpio_ilum deberia estar encendido"
            severity error;

        assert out_vent_tb = '0'
            report "ERROR: En modo manual, out_vent deberia estar apagado"
            severity error;

        assert gpio_vent_tb = '0'
            report "ERROR: En modo manual, gpio_vent deberia estar apagado"
            severity error;

        -- ======================================================
        -- PRUEBA 3: MODO MANUAL - VENTILACIÓN ENCENDIDA
        -- ======================================================
        -- SW0 = 0 -> modo manual
        -- SW1 = 0 -> iluminación apagada
        -- SW2 = 1 -> ventilación encendida
        -- ======================================================

        report "PRUEBA 3: Modo manual, iluminacion OFF, ventilacion ON";

        sw_modo_tb <= '0';
        sw_ilum_tb <= '0';
        sw_vent_tb <= '1';

        wait for 5 us;

        assert out_ilum_tb = '0'
            report "ERROR: En modo manual, out_ilum deberia estar apagado"
            severity error;

        assert gpio_ilum_tb = '0'
            report "ERROR: En modo manual, gpio_ilum deberia estar apagado"
            severity error;

        assert out_vent_tb = '1'
            report "ERROR: En modo manual, out_vent deberia estar encendido"
            severity error;

        assert gpio_vent_tb = '1'
            report "ERROR: En modo manual, gpio_vent deberia estar encendido"
            severity error;

        -- ======================================================
        -- PRUEBA 4: MODO MANUAL - TODO ENCENDIDO
        -- ======================================================
        -- SW0 = 0 -> modo manual
        -- SW1 = 1 -> iluminación encendida
        -- SW2 = 1 -> ventilación encendida
        -- ======================================================

        report "PRUEBA 4: Modo manual, iluminacion ON, ventilacion ON";

        sw_modo_tb <= '0';
        sw_ilum_tb <= '1';
        sw_vent_tb <= '1';

        wait for 5 us;

        assert out_ilum_tb = '1'
            report "ERROR: En modo manual, out_ilum deberia estar encendido"
            severity error;

        assert gpio_ilum_tb = '1'
            report "ERROR: En modo manual, gpio_ilum deberia estar encendido"
            severity error;

        assert out_vent_tb = '1'
            report "ERROR: En modo manual, out_vent deberia estar encendido"
            severity error;

        assert gpio_vent_tb = '1'
            report "ERROR: En modo manual, gpio_vent deberia estar encendido"
            severity error;

        -- ======================================================
        -- PRUEBA 5: MODO MANUAL - TODO APAGADO
        -- ======================================================
        -- SW0 = 0 -> modo manual
        -- SW1 = 0 -> iluminación apagada
        -- SW2 = 0 -> ventilación apagada
        -- ======================================================

        report "PRUEBA 5: Modo manual, todo apagado";

        sw_modo_tb <= '0';
        sw_ilum_tb <= '0';
        sw_vent_tb <= '0';

        wait for 5 us;

        assert out_ilum_tb = '0'
            report "ERROR: En modo manual, out_ilum deberia estar apagado"
            severity error;

        assert gpio_ilum_tb = '0'
            report "ERROR: En modo manual, gpio_ilum deberia estar apagado"
            severity error;

        assert out_vent_tb = '0'
            report "ERROR: En modo manual, out_vent deberia estar apagado"
            severity error;

        assert gpio_vent_tb = '0'
            report "ERROR: En modo manual, gpio_vent deberia estar apagado"
            severity error;

        -- ======================================================
        -- PRUEBA 6: ENTRADA A MODO AUTOMÁTICO
        -- ======================================================
        -- SW0 = 1 -> modo automático
        --
        -- Al comienzo del ciclo automático:
        --   iluminación = encendida
        --   ventilación = encendida
        --
        -- Los cambios después de 5 s y 10 s se verifican
        -- físicamente en la FPGA.
        -- ======================================================

        report "PRUEBA 6: Entrada a modo automatico";

        sw_modo_tb <= '1';
        sw_ilum_tb <= '0';
        sw_vent_tb <= '0';

        wait for 5 us;

        assert out_ilum_tb = '1'
            report "ERROR: En modo automatico inicial, out_ilum deberia estar encendido"
            severity error;

        assert gpio_ilum_tb = '1'
            report "ERROR: En modo automatico inicial, gpio_ilum deberia estar encendido"
            severity error;

        assert out_vent_tb = '1'
            report "ERROR: En modo automatico inicial, out_vent deberia estar encendido"
            severity error;

        assert gpio_vent_tb = '1'
            report "ERROR: En modo automatico inicial, gpio_vent deberia estar encendido"
            severity error;

        -- ======================================================
        -- PRUEBA 7: RESET EN MODO AUTOMÁTICO
        -- ======================================================
        -- Se activa reset mientras el sistema está en automático
        -- para verificar que las salidas se apaguen y el sistema
        -- vuelva a iniciar correctamente.
        -- ======================================================

        report "PRUEBA 7: Reset durante modo automatico";

        reset_tb <= '1';
        wait for 200 ns;

        assert out_ilum_tb = '0'
            report "ERROR: Durante reset en automatico, out_ilum deberia estar apagado"
            severity error;

        assert gpio_ilum_tb = '0'
            report "ERROR: Durante reset en automatico, gpio_ilum deberia estar apagado"
            severity error;

        assert out_vent_tb = '0'
            report "ERROR: Durante reset en automatico, out_vent deberia estar apagado"
            severity error;

        assert gpio_vent_tb = '0'
            report "ERROR: Durante reset en automatico, gpio_vent deberia estar apagado"
            severity error;

        -- Se desactiva el reset.
        -- Como sw_modo_tb sigue en 1, el sistema vuelve a modo automático.
        reset_tb <= '0';
        wait for 5 us;

        assert out_ilum_tb = '1'
            report "ERROR: Despues del reset en automatico, out_ilum deberia volver a encender"
            severity error;

        assert gpio_ilum_tb = '1'
            report "ERROR: Despues del reset en automatico, gpio_ilum deberia volver a encender"
            severity error;

        assert out_vent_tb = '1'
            report "ERROR: Despues del reset en automatico, out_vent deberia volver a encender"
            severity error;

        assert gpio_vent_tb = '1'
            report "ERROR: Despues del reset en automatico, gpio_vent deberia volver a encender"
            severity error;

        -- ======================================================
        -- Nota final sobre los tiempos reales
        -- ======================================================
        -- En hardware real:
        --   Iluminación: 5 s ON / 5 s OFF
        --   Ventilador:  5 s ON / 10 s OFF
        --
        -- En simulación no se espera observar esos segundos
        -- completos porque implican demasiados ciclos.
        -- ======================================================

        report "SIMULACION FINALIZADA CORRECTAMENTE";

        wait;

    end process;

end Behavioral;
