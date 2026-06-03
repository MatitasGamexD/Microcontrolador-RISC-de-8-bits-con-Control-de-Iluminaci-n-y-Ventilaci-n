-- ==========================================================
-- Archivo: register_bank.vhd
-- Descripción:
--   Banco de registros del microcontrolador.
--   Contiene 4 registros internos de 8 bits cada uno.
--
-- Registros disponibles:
--   R0, R1, R2 y R3
--   Se seleccionan mediante direcciones de 2 bits:
--     "00" = R0
--     "01" = R1
--     "10" = R2
--     "11" = R3
--
-- Función:
--   Permite leer dos registros al mismo tiempo y escribir
--   un registro en cada flanco de subida del reloj.
--
-- Uso dentro del proyecto:
--   R0 se usa principalmente para guardar datos leídos de los
--   switches o para escribir salidas.
--   R1 se usa como registro auxiliar, por ejemplo para guardar
--   la máscara que permite revisar el bit de modo.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_bank is
    Port (
        clk         : in  STD_LOGIC;                     -- Reloj del sistema
        reset       : in  STD_LOGIC;                     -- Reset general
        we          : in  STD_LOGIC;                     -- Habilitador de escritura
        read_addr1  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del primer registro a leer
        read_addr2  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del segundo registro a leer
        write_addr  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del registro a escribir
        write_data  : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dato que se va a escribir
        read_data1  : out STD_LOGIC_VECTOR(7 downto 0);  -- Primer dato leído
        read_data2  : out STD_LOGIC_VECTOR(7 downto 0)   -- Segundo dato leído
    );
end register_bank;

architecture Behavioral of register_bank is

    -- Definición del banco de registros.
    -- Son 4 posiciones, cada una de 8 bits.
    type reg_array is array (0 to 3) of STD_LOGIC_VECTOR(7 downto 0);

    -- Inicialmente todos los registros arrancan en cero.
    signal registers : reg_array := (others => (others => '0'));

begin

    -- ==========================================================
    -- Proceso síncrono de escritura y reset
    -- ==========================================================
    -- El reset limpia todos los registros.
    -- La escritura se hace solo en flanco de subida del reloj
    -- y únicamente si we = '1'.
    -- ==========================================================

    process(clk, reset)
    begin
        if reset = '1' then

            -- Reset activo:
            -- limpia todos los registros internos.
            registers <= (others => (others => '0'));

        elsif rising_edge(clk) then

            -- Escritura síncrona.
            -- Si we está activo, se escribe write_data en el registro
            -- indicado por write_addr.
            if we = '1' then
                registers(to_integer(unsigned(write_addr))) <= write_data;
            end if;

        end if;
    end process;

    -- ==========================================================
    -- Lectura asíncrona
    -- ==========================================================
    -- Las salidas read_data1 y read_data2 cambian automáticamente
    -- cuando cambian read_addr1 o read_addr2.
    -- ==========================================================

    read_data1 <= registers(to_integer(unsigned(read_addr1)));
    read_data2 <= registers(to_integer(unsigned(read_addr2)));

end Behavioral;
