-- ==========================================================
-- Archivo: rom.vhd
--
-- En este archivo está la ROM de instrucciones del microcontrolador.
-- Aquí se guarda el programa que se ejecuta de forma repetitiva.
--
-- Cada instrucción ocupa dos posiciones: una para el opcode y otra para el operando.
--
-- El programa lee los switches desde 0xFE, revisa el bit de modo,
-- decide si trabaja en manual o automático, escribe las salidas en 0xFF
-- y luego vuelve a empezar.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rom is
    Port (
        address     : in  STD_LOGIC_VECTOR(7 downto 0); -- Dirección que llega desde el PC
        instruction : out STD_LOGIC_VECTOR(7 downto 0)  -- Dato que entrega la ROM
    );
end rom;

architecture Behavioral of rom is

    -- ROM de 64 posiciones, cada una de 8 bits.
    type rom_type is array (0 to 63) of STD_LOGIC_VECTOR(7 downto 0);

    -- Instrucciones que entiende el microcontrolador.
    constant LOAD_R0  : STD_LOGIC_VECTOR(7 downto 0) := "00000001"; -- Carga en R0 desde RAM/IO
    constant LOAD_R1  : STD_LOGIC_VECTOR(7 downto 0) := "00000010"; -- Carga en R1 desde RAM/IO
    constant STORE_R0 : STD_LOGIC_VECTOR(7 downto 0) := "00000011"; -- Guarda R0 en RAM/IO
    constant AND_REG  : STD_LOGIC_VECTOR(7 downto 0) := "00000100"; -- Hace R0 = R0 AND R1
    constant JMP_ZERO : STD_LOGIC_VECTOR(7 downto 0) := "00000101"; -- Salta si Zero_Flag está en 1
    constant JMP      : STD_LOGIC_VECTOR(7 downto 0) := "00000110"; -- Salto directo
    constant MOVI_R1  : STD_LOGIC_VECTOR(7 downto 0) := "00000111"; -- Carga un valor inmediato en R1
    constant MOVI_R0  : STD_LOGIC_VECTOR(7 downto 0) := "00001000"; -- Carga un valor inmediato en R0

    -- Programa guardado en la ROM.
    signal rom_memory : rom_type := (

        -- ======================================================
        -- CICLO PRINCIPAL
        -- ======================================================

        -- Se leen los switches desde 0xFE y el valor se guarda en R0.
        -- El formato leído es: 00000 | sw_modo | sw_ilum | sw_vent.
        0  => LOAD_R0,
        1  => "11111110",  -- 0xFE

        -- Se carga en R1 la máscara 00000100 para revisar el bit de modo.
        -- Ese bit corresponde a sw_modo.
        2  => MOVI_R1,
        3  => "00000100",

        -- Se hace R0 = R0 AND R1.
        -- Si sw_modo = 0, el resultado da cero; si sw_modo = 1, da 00000100.
        4  => AND_REG,
        5  => "00000000",

        -- Si Zero_Flag = 1, quiere decir que está en modo manual.
        -- Por eso se salta a la dirección 12.
        6  => JMP_ZERO,
        7  => "00001100",

        -- ======================================================
        -- MODO AUTOMÁTICO
        -- ======================================================

        -- Si no hubo salto, entonces sw_modo = 1 y se entra al modo automático.
        -- Se carga un valor base en R0; los tiempos reales se manejan en ram_io.vhd.
        8  => MOVI_R0,
        9  => "00000010",

        -- Salta a la parte donde se actualizan las salidas.
        10 => JMP,
        11 => "00010000",

        -- ======================================================
        -- MODO MANUAL
        -- ======================================================

        -- En modo manual se vuelven a leer los switches,
        -- porque R0 fue modificado antes por la operación AND.
        12 => LOAD_R0,
        13 => "11111110",

        -- Salta a la rutina de escritura de salidas.
        14 => JMP,
        15 => "00010000",

        -- ======================================================
        -- ACTUALIZAR SALIDAS
        -- ======================================================

        -- Se guarda R0 en 0xFF, que es el puerto de salida.
        -- El bit 1 controla iluminación y el bit 0 controla ventilación.
        16 => STORE_R0,
        17 => "11111111",

        -- Al final se vuelve al inicio para repetir el programa.
        18 => JMP,
        19 => "00000000",

        -- Las demás posiciones no se usan y quedan en cero.
        others => (others => '0')
    );

begin

    -- La ROM entrega el opcode o el operando según la dirección enviada por el PC.
    instruction <= rom_memory(to_integer(unsigned(address)));

end Behavioral;
