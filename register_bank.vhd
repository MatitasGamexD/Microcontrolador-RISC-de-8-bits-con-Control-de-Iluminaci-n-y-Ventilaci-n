-- ==========================================================
-- Archivo: register_bank.vhd
--
-- Este archivo implementa el banco de registros del microcontrolador.
-- Tiene 4 registros internos de 8 bits: R0, R1, R2 y R3.
--
-- Cada registro se selecciona con una dirección de 2 bits:
-- "00" = R0, "01" = R1, "10" = R2 y "11" = R3.
--
-- El banco permite leer dos registros al mismo tiempo y escribir
-- en uno solo cuando hay flanco de subida del reloj y we está activo.
--
-- En el proyecto, R0 se usa bastante para guardar lo que se lee de
-- los switches o lo que se va a mandar a las salidas. R1 se usa como
-- apoyo, por ejemplo para guardar la máscara del bit de modo.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity register_bank is
    Port (
        clk         : in  STD_LOGIC;                     -- Reloj del sistema
        reset       : in  STD_LOGIC;                     -- Reinicia todos los registros
        we          : in  STD_LOGIC;                     -- Habilita la escritura
        read_addr1  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del primer registro a leer
        read_addr2  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del segundo registro a leer
        write_addr  : in  STD_LOGIC_VECTOR(1 downto 0);  -- Dirección del registro donde se va a escribir
        write_data  : in  STD_LOGIC_VECTOR(7 downto 0);  -- Dato que se escribe
        read_data1  : out STD_LOGIC_VECTOR(7 downto 0);  -- Primer dato leído
        read_data2  : out STD_LOGIC_VECTOR(7 downto 0)   -- Segundo dato leído
    );
end register_bank;

architecture Behavioral of register_bank is

    -- Arreglo que representa los 4 registros internos, cada uno de 8 bits.
    type reg_array is array (0 to 3) of STD_LOGIC_VECTOR(7 downto 0);

    -- Los registros arrancan inicializados en cero.
    signal registers : reg_array := (others => (others => '0'));

begin

    -- Proceso síncrono para manejar el reset y la escritura en los registros.
    process(clk, reset)
    begin
        if reset = '1' then

            -- Con reset activo se limpian todos los registros.
            registers <= (others => (others => '0'));

        elsif rising_edge(clk) then

            -- Si we está activo, se guarda write_data en el registro seleccionado.
            if we = '1' then
                registers(to_integer(unsigned(write_addr))) <= write_data;
            end if;

        end if;
    end process;

    -- Lectura asíncrona:
    -- las salidas cambian apenas cambien las direcciones de lectura.
    read_data1 <= registers(to_integer(unsigned(read_addr1)));
    read_data2 <= registers(to_integer(unsigned(read_addr2)));

end Behavioral;
