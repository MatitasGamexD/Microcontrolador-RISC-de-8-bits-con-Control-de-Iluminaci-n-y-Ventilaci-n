-- ==========================================================
-- Archivo: alu.vhd
-- Descripción:
--   Unidad Aritmético-Lógica (ALU) de 8 bits.
--   Permite realizar operaciones básicas entre dos operandos:
--   suma, resta, AND y OR.
--
-- Entradas:
--   A       : Primer operando de 8 bits.
--   B       : Segundo operando de 8 bits.
--   ALU_Sel : Selector de operación.
--
-- Salidas:
--   Result  : Resultado de la operación.
--   Zero    : Bandera que se activa cuando el resultado es cero.
--
-- Uso dentro del proyecto:
--   En este microcontrolador, la ALU se usa principalmente para hacer la operación AND entre el valor leído de los
--   switches y una máscara, con el fin de saber si el sistema está en modo manual o automático.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity alu is
    Port (
        A       : in  STD_LOGIC_VECTOR(7 downto 0); -- Operando A de 8 bits
        B       : in  STD_LOGIC_VECTOR(7 downto 0); -- Operando B de 8 bits
        ALU_Sel : in  STD_LOGIC_VECTOR(1 downto 0); -- Selector de operación
        Result  : out STD_LOGIC_VECTOR(7 downto 0); -- Resultado de 8 bits
        Zero    : out STD_LOGIC                      -- Bandera de resultado cero
    );
end alu;

architecture Behavioral of alu is

    -- Señal interna donde se almacena temporalmente
    -- el resultado de la operación seleccionada.
    signal temp_result : STD_LOGIC_VECTOR(7 downto 0);

begin

    -- Proceso combinacional.
    -- Se ejecuta cada vez que cambian A, B o ALU_Sel.
    process(A, B, ALU_Sel)
    begin
        case ALU_Sel is

            when "00" =>
                -- Operación de suma:
                -- Convierte A y B a tipo unsigned para poder sumarlos.
                temp_result <= std_logic_vector(unsigned(A) + unsigned(B));

            when "01" =>
                -- Operación de resta:
                -- Convierte A y B a tipo unsigned para poder restarlos.
                temp_result <= std_logic_vector(unsigned(A) - unsigned(B));

            when "10" =>
                -- Operación lógica AND bit a bit.
                -- En el proyecto se usa para revisar el bit de modo.
                temp_result <= A and B;

            when "11" =>
                -- Operación lógica OR bit a bit.
                temp_result <= A or B;

            when others =>
                -- Caso de seguridad.
                -- Si por alguna razón llega otro valor, el resultado se limpia.
                temp_result <= (others => '0');

        end case;
    end process;

    -- Se asigna el resultado interno a la salida de la ALU.
    Result <= temp_result;

    -- Bandera Zero:
    -- Se activa en '1' cuando el resultado es 00000000.
    -- Se usa para instrucciones de salto condicional como JMP_ZERO.
    Zero <= '1' when temp_result = "00000000" else '0';

end Behavioral;
