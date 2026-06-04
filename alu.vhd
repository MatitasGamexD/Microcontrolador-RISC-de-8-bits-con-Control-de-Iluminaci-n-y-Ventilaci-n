vhdl
-- ==========================================================
-- Archivo: alu.vhd
--
-- En este archivo se implementa la ALU del microcontrolador.
-- Trabaja con datos de 8 bits y permite hacer suma, resta, AND y OR.
--
-- En el proyecto se usa principalmente la operación AND para revisar
-- el bit del switch de modo y saber si está en manual o automático.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    Port (
        A       : in  STD_LOGIC_VECTOR(7 downto 0); -- Primer dato que entra a la ALU
        B       : in  STD_LOGIC_VECTOR(7 downto 0); -- Segundo dato que entra a la ALU
        ALU_Sel : in  STD_LOGIC_VECTOR(1 downto 0); -- Indica qué operación se va a realizar
        Result  : out STD_LOGIC_VECTOR(7 downto 0); -- Resultado final de la operación
        Zero    : out STD_LOGIC                      -- Se activa cuando el resultado es cero
    );
end alu;

architecture Behavioral of alu is

    -- Señal interna donde se guarda temporalmente el resultado de la operación.
    signal temp_result : STD_LOGIC_VECTOR(7 downto 0);

begin

    -- Proceso combinacional: cambia cuando cambian A, B o ALU_Sel.
    process(A, B, ALU_Sel)
    begin
        case ALU_Sel is

            when "00" =>
                -- Suma de A y B. Se convierten a unsigned para poder operar.
                temp_result <= std_logic_vector(unsigned(A) + unsigned(B));

            when "01" =>
                -- Resta de A menos B. También se usa unsigned para hacer la operación.
                temp_result <= std_logic_vector(unsigned(A) - unsigned(B));

            when "10" =>
                -- Operación AND bit a bit, usada para revisar el bit de modo.
                temp_result <= A and B;

            when "11" =>
                -- Operación OR bit a bit.
                temp_result <= A or B;

            when others =>
                -- Caso de seguridad: si llega un valor raro, se limpia el resultado.
                temp_result <= (others => '0');

        end case;
    end process;

    -- Se pasa el resultado interno hacia la salida principal de la ALU.
    Result <= temp_result;

    -- La bandera Zero se activa cuando el resultado es 00000000.
    -- Esta señal se usa en instrucciones como JMP_ZERO.
    Zero <= '1' when temp_result = "00000000" else '0';

end Behavioral;
