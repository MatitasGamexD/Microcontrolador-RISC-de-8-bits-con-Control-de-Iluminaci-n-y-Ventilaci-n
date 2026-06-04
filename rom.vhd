-- ==========================================================
-- Archivo: rom.vhd
-- Descripción:
--   Memoria ROM de instrucciones del microcontrolador.
--
-- Función:
--   Contiene el programa que ejecuta el microcontrolador.
--   Cada instrucción ocupa dos posiciones:
--      1 byte para el opcode
--      1 byte para el operando
--
-- Programa implementado:
--   1. Lee los switches desde el puerto 0xFE.
--   2. Usa una máscara para revisar el bit de modo.
--   3. Si sw_modo = 0, ejecuta modo manual.
--   4. Si sw_modo = 1, ejecuta modo automático.
--   5. Escribe las salidas en el puerto 0xFF.
--   6. Repite el ciclo indefinidamente.
--
-- Direcciones especiales:
--   0xFE = puerto de entrada
--   0xFF = puerto de salida
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rom is
    Port (
        address     : in  STD_LOGIC_VECTOR(7 downto 0); -- Dirección de la instrucción
        instruction : out STD_LOGIC_VECTOR(7 downto 0)  -- Instrucción o dato leído
    );
end rom;

architecture Behavioral of rom is

    -- ROM de 64 posiciones de 8 bits.
    type rom_type is array (0 to 63) of STD_LOGIC_VECTOR(7 downto 0);

    -- ==========================================================
    -- Definición de instrucciones del microcontrolador
    -- ==========================================================

    constant LOAD_R0  : STD_LOGIC_VECTOR(7 downto 0) := "00000001"; -- Cargar en R0 desde RAM/IO
    constant LOAD_R1  : STD_LOGIC_VECTOR(7 downto 0) := "00000010"; -- Cargar en R1 desde RAM/IO
    constant STORE_R0 : STD_LOGIC_VECTOR(7 downto 0) := "00000011"; -- Guardar R0 en RAM/IO
    constant AND_REG  : STD_LOGIC_VECTOR(7 downto 0) := "00000100"; -- R0 = R0 AND R1
    constant JMP_ZERO : STD_LOGIC_VECTOR(7 downto 0) := "00000101"; -- Saltar si Zero_Flag = 1
    constant JMP      : STD_LOGIC_VECTOR(7 downto 0) := "00000110"; -- Salto incondicional
    constant MOVI_R1  : STD_LOGIC_VECTOR(7 downto 0) := "00000111"; -- Mover inmediato a R1
    constant MOVI_R0  : STD_LOGIC_VECTOR(7 downto 0) := "00001000"; -- Mover inmediato a R0

    -- ==========================================================
    -- Programa almacenado en ROM
    -- ==========================================================

    signal rom_memory : rom_type := (

        -- ======================================================
        -- CICLO PRINCIPAL
        -- ======================================================

        -- Dirección 0:
        -- Leer switches desde 0xFE y guardar el valor en R0.
        -- Formato leído:
        -- 00000 | sw_modo | sw_ilum | sw_vent
        0  => LOAD_R0,
        1  => "11111110",  -- 0xFE

        -- Dirección 2:
        -- Cargar en R1 la máscara 00000100.
        -- Esta máscara sirve para revisar el bit 2,
        -- que corresponde a sw_modo.
        2  => MOVI_R1,
        3  => "00000100",

        -- Dirección 4:
        -- R0 = R0 AND R1.
        -- Si sw_modo = 0, el resultado será 00000000.
        -- Si sw_modo = 1, el resultado será 00000100.
        4  => AND_REG,
        5  => "00000000",

        -- Dirección 6:
        -- Si Zero_Flag = 1, significa que sw_modo = 0,
        -- por lo tanto se salta al modo manual en dirección 12.
        6  => JMP_ZERO,
        7  => "00001100",

        -- ======================================================
        -- MODO AUTOMÁTICO
        -- ======================================================
        -- Si el salto anterior no se ejecuta, entonces sw_modo = 1.
        -- Se carga en R0 el valor base 00000010.
        -- bit 1 = iluminación
        -- bit 0 = ventilación
        --
        -- Los tiempos automáticos reales se controlan en ram_io.vhd.
        8  => MOVI_R0,
        9  => "00000010",

        -- Saltar a la rutina de escritura de salidas.
        10 => JMP,
        11 => "00010000",

        -- ======================================================
        -- MODO MANUAL
        -- ======================================================
        -- En modo manual se vuelven a leer los switches,
        -- porque R0 fue modificado por la operación AND.
        12 => LOAD_R0,
        13 => "11111110",

        -- Saltar a escritura de salidas.
        14 => JMP,
        15 => "00010000",

        -- ======================================================
        -- ACTUALIZAR SALIDAS
        -- ======================================================
        -- Guardar R0 en 0xFF.
        -- 0xFF corresponde al puerto de salida.
        -- bit 1 = iluminación
        -- bit 0 = ventilación
        16 => STORE_R0,
        17 => "11111111",

        -- Repetir el programa desde el inicio.
        18 => JMP,
        19 => "00000000",

        -- Las demás posiciones de la ROM quedan en cero.
        others => (others => '0')
    );

begin

    -- Lectura de ROM.
    -- El Program Counter entrega la dirección y la ROM devuelve el opcode o el operando correspondiente.
    instruction <= rom_memory(to_integer(unsigned(address)));

end Behavioral;
