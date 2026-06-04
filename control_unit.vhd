-- ==========================================================
-- Archivo: control_unit.vhd
-- Descripción:
--   Unidad de control del microcontrolador.
--
-- Función:
--   Implementa una máquina de estados finitos, FSM, que controla
--   el ciclo de instrucción del microcontrolador.
--
-- Ciclo general:
--   FETCH -> DECODE -> EXECUTE
--
-- En este diseño el FETCH se divide en dos etapas:
--   S_FETCH_OPCODE  : lee el opcode de la ROM.
--   S_FETCH_OPERAND : lee el operando de la ROM.
--
-- Esto se hace porque cada instrucción ocupa dos bytes:
--   1 byte = opcode
--   1 byte = operando
--
-- Estados:
--   S_FETCH_OPCODE
--   S_FETCH_OPERAND
--   S_DECODE
--   S_EXECUTE
--
-- La unidad de control no procesa datos directamente.
-- Su trabajo es generar señales de control para el datapath.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_unit is
    Port (
        clk              : in  STD_LOGIC; -- Reloj principal
        reset            : in  STD_LOGIC; -- Reset general

        -- Entradas de estado provenientes del datapath
        Opcode           : in  STD_LOGIC_VECTOR(7 downto 0); -- Instrucción actual
        Zero_Flag        : in  STD_LOGIC;                    -- Bandera de cero de la ALU

        -- Señales de control hacia el datapath
        PC_Load          : out STD_LOGIC; -- Cargar PC con operando
        PC_Inc           : out STD_LOGIC; -- Incrementar PC
        IR_Load          : out STD_LOGIC; -- Cargar opcode
        Op_Load          : out STD_LOGIC; -- Cargar operando
        Reg_WE           : out STD_LOGIC; -- Escribir en banco de registros

        Reg_Dest         : out STD_LOGIC_VECTOR(1 downto 0); -- Registro destino
        Reg_SrcA         : out STD_LOGIC_VECTOR(1 downto 0); -- Registro fuente A
        Reg_SrcB         : out STD_LOGIC_VECTOR(1 downto 0); -- Registro fuente B

        ALU_Sel          : out STD_LOGIC_VECTOR(1 downto 0); -- Operación de ALU

        -- Selector del dato que se escribirá en el banco de registros:
        -- "00" = resultado ALU
        -- "01" = dato desde RAM/IO
        -- "10" = operando inmediato
        Mux_RegWrite_Sel : out STD_LOGIC_VECTOR(1 downto 0);

        -- Señal de escritura hacia RAM/IO
        RAM_WE           : out STD_LOGIC
    );
end control_unit;

architecture Behavioral of control_unit is

    
    -- Definición de estados de la FSM

    type fsm_state is (
        S_FETCH_OPCODE,   -- Buscar opcode
        S_FETCH_OPERAND,  -- Buscar operando
        S_DECODE,         -- Decodificar instrucción
        S_EXECUTE         -- Ejecutar instrucción
    );

    -- Estado actual y siguiente estado.
    signal state, next_state : fsm_state;

begin

    -- ==========================================================
    -- Registro de estado
    -- ==========================================================
    -- En cada flanco de subida del reloj la FSM pasa al siguiente
    -- estado. Con reset vuelve al estado inicial.
    -- ==========================================================

    process(clk, reset)
    begin
        if reset = '1' then

            -- Estado inicial después del reset.
            state <= S_FETCH_OPCODE;

        elsif rising_edge(clk) then

            -- Avanza al siguiente estado calculado.
            state <= next_state;

        end if;
    end process;

    -- ==========================================================
    -- Lógica combinacional de control
    -- ==========================================================
    -- Según el estado actual y el opcode, se generan las señales
    -- necesarias para controlar el datapath.
    -- ==========================================================

    process(state, Opcode, Zero_Flag)
    begin

        -- ======================================================
        -- Valores por defecto
        -- ======================================================
        -- Se colocan todas las señales en cero para evitar
        -- activaciones no deseadas y generación de latches.
        -- ======================================================

        PC_Load <= '0';
        PC_Inc  <= '0';
        IR_Load <= '0';
        Op_Load <= '0';
        Reg_WE  <= '0';
        RAM_WE  <= '0';

        Reg_Dest <= "00";
        Reg_SrcA <= "00";
        Reg_SrcB <= "00";
        ALU_Sel  <= "00";
        Mux_RegWrite_Sel <= "00";

        next_state <= state;

        
        -- Máquina de estados
        case state is
            -- --------------------------------------------------
            -- Estado 1: FETCH_OPCODE
            -- --------------------------------------------------
            -- Lee desde ROM el opcode de la instrucción.
            -- El dato leído se guarda en el IR.
            -- Luego incrementa el PC para leer el operando.
            -- --------------------------------------------------

            when S_FETCH_OPCODE =>

                IR_Load <= '1';
                PC_Inc  <= '1';
                next_state <= S_FETCH_OPERAND;

            -- --------------------------------------------------
            -- Estado 2: FETCH_OPERAND
            -- --------------------------------------------------
            -- Lee desde ROM el operando de la instrucción.
            -- El operando puede ser una dirección o un dato.
            -- Luego incrementa el PC.
            -- --------------------------------------------------

            when S_FETCH_OPERAND =>

                Op_Load <= '1';
                PC_Inc  <= '1';
                next_state <= S_DECODE;

            -- --------------------------------------------------
            -- Estado 3: DECODE
            -- --------------------------------------------------
            -- Estado intermedio donde se interpreta la instrucción.
            -- En este diseño la decodificación se realiza al pasar
            -- a EXECUTE.
            -- --------------------------------------------------

            when S_DECODE =>

                next_state <= S_EXECUTE;

            -- --------------------------------------------------
            -- Estado 4: EXECUTE
            -- --------------------------------------------------
            -- Ejecuta la instrucción indicada por Opcode.
            -- Aquí se activan señales para cargar registros,
            -- operar la ALU, escribir RAM o saltar.
            -- --------------------------------------------------

            when S_EXECUTE =>

                case Opcode is

                    -- ==================================================
                    -- LOAD_R0
                    -- ==================================================
                    -- Carga en R0 el dato leído desde RAM/IO.
                    -- Ejemplo:
                    --   R0 <- RAM[operando]
                    -- ==================================================

                    when "00000001" =>

                        Mux_RegWrite_Sel <= "01"; -- Dato desde RAM/IO
                        Reg_Dest <= "00";         -- R0
                        Reg_WE   <= '1';          -- Habilita escritura

                    -- ==================================================
                    -- LOAD_R1
                    -- ==================================================
                    -- Carga en R1 el dato leído desde RAM/IO.
                    -- ==================================================

                    when "00000010" =>

                        Mux_RegWrite_Sel <= "01"; -- Dato desde RAM/IO
                        Reg_Dest <= "01";         -- R1
                        Reg_WE   <= '1';

                    -- ==================================================
                    -- STORE_R0
                    -- ==================================================
                    -- Guarda el contenido de R0 en RAM/IO.
                    -- Ejemplo:
                    --   RAM[operando] <- R0
                    -- ==================================================

                    when "00000011" =>

                        Reg_SrcA <= "00"; -- Selecciona R0 como dato de salida
                        RAM_WE   <= '1';  -- Habilita escritura en RAM/IO

                    -- ==================================================
                    -- AND_REG
                    -- ==================================================
                    -- Realiza:
                    --   R0 = R0 AND R1
                    --
                    -- En el proyecto se usa para verificar sw_modo.
                    -- R1 contiene la máscara 00000100.
                    -- ==================================================

                    when "00000100" =>

                        Reg_SrcA <= "00"; -- R0
                        Reg_SrcB <= "01"; -- R1
                        ALU_Sel  <= "10"; -- AND
                        Mux_RegWrite_Sel <= "00"; -- Resultado de ALU
                        Reg_Dest <= "00"; -- Guardar resultado en R0
                        Reg_WE   <= '1';

                    -- ==================================================
                    -- JMP_ZERO
                    -- ==================================================
                    -- Salta a la dirección indicada por el operando si
                    -- Zero_Flag = 1.
                    --
                    -- Se usa para ir al modo manual cuando sw_modo = 0.
                    -- ==================================================

                    when "00000101" =>

                        if Zero_Flag = '1' then
                            PC_Load <= '1';
                        end if;

                    -- ==================================================
                    -- JMP
                    -- ==================================================
                    -- Salto incondicional.
                    -- Carga el PC con el valor del operando.
                    -- ==================================================

                    when "00000110" =>

                        PC_Load <= '1';

                    -- ==================================================
                    -- MOVI_R1
                    -- ==================================================
                    -- Carga un dato inmediato en R1.
                    -- Ejemplo:
                    --   R1 <- operando
                    -- ==================================================

                    when "00000111" =>

                        Mux_RegWrite_Sel <= "10"; -- Operando inmediato
                        Reg_Dest <= "01";         -- R1
                        Reg_WE   <= '1';

                    -- ==================================================
                    -- MOVI_R0
                    -- ==================================================
                    -- Carga un dato inmediato en R0.
                    -- Se usa en modo automático para cargar un valor base.
                    -- ==================================================

                    when "00001000" =>

                        Mux_RegWrite_Sel <= "10"; -- Operando inmediato
                        Reg_Dest <= "00";         -- R0
                        Reg_WE   <= '1';

                    when others =>

                        -- Si el opcode no corresponde a ninguna instrucción,
                        -- no se ejecuta ninguna acción.
                        null;

                end case;

                -- Después de ejecutar cualquier instrucción,
                -- el procesador vuelve a buscar el siguiente opcode.
                next_state <= S_FETCH_OPCODE;

        end case;
    end process;

end Behavioral;
