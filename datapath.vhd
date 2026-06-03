-- ==========================================================
-- Archivo: datapath.vhd
-- Descripción:
--   Camino de datos del microcontrolador RISC de 8 bits.
--
-- Función:
--   Este módulo contiene los elementos internos que permiten
--   mover, almacenar y procesar datos dentro del microcontrolador.
--
-- Elementos principales:
--   - Program Counter, PC
--   - Instruction Register, IR
--   - Registro de operando
--   - Banco de registros
--   - ALU
--   - Multiplexor de escritura
--   - Buses hacia ROM y RAM/IO
--
-- Relación con otros módulos:
--   La unidad de control, control_unit.vhd, envía señales de
--   control a este datapath para indicar qué operación se debe
--   realizar en cada estado de la FSM.
--
-- Arquitectura Harvard:
--   Este datapath usa buses separados:
--      ROM_Addr / ROM_Data para instrucciones
--      RAM_Addr / RAM_Data para datos y puertos
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity datapath is
    Port (
        clk              : in  STD_LOGIC; -- Reloj principal del sistema
        reset            : in  STD_LOGIC; -- Reset general

        -- ======================================================
        -- Señales de control provenientes de la FSM
        -- ======================================================
        -- Estas señales vienen desde control_unit.vhd y controlan
        -- el comportamiento interno del datapath.
        -- ======================================================

        PC_Load          : in  STD_LOGIC; -- Carga el PC con el operando, usado en saltos
        PC_Inc           : in  STD_LOGIC; -- Incrementa el PC
        IR_Load          : in  STD_LOGIC; -- Carga el opcode en el Instruction Register
        Op_Load          : in  STD_LOGIC; -- Carga el operando de la instrucción
        Reg_WE           : in  STD_LOGIC; -- Habilita escritura en el banco de registros

        Reg_Dest         : in  STD_LOGIC_VECTOR(1 downto 0); -- Registro destino
        Reg_SrcA         : in  STD_LOGIC_VECTOR(1 downto 0); -- Registro fuente A
        Reg_SrcB         : in  STD_LOGIC_VECTOR(1 downto 0); -- Registro fuente B

        ALU_Sel          : in  STD_LOGIC_VECTOR(1 downto 0); -- Operación de la ALU

        -- Selector del dato que se escribirá en el banco de registros:
        -- "00" = resultado de ALU
        -- "01" = dato leído desde RAM/IO
        -- "10" = operando inmediato
        Mux_RegWrite_Sel : in  STD_LOGIC_VECTOR(1 downto 0);

        -- ======================================================
        -- Señales de estado hacia la FSM
        -- ======================================================

        Opcode           : out STD_LOGIC_VECTOR(7 downto 0); -- Opcode actual
        Zero_Flag        : out STD_LOGIC;                    -- Bandera de cero de la ALU

        -- ======================================================
        -- Bus de memoria ROM, memoria de instrucciones
        -- ======================================================

        ROM_Addr         : out STD_LOGIC_VECTOR(7 downto 0); -- Dirección hacia ROM
        ROM_Data         : in  STD_LOGIC_VECTOR(7 downto 0); -- Dato leído desde ROM

        -- ======================================================
        -- Bus de memoria RAM e I/O, memoria de datos y puertos
        -- ======================================================

        RAM_Addr         : out STD_LOGIC_VECTOR(7 downto 0); -- Dirección hacia RAM/IO
        RAM_Data_In      : in  STD_LOGIC_VECTOR(7 downto 0); -- Dato leído desde RAM/IO
        RAM_Data_Out     : out STD_LOGIC_VECTOR(7 downto 0)  -- Dato que se escribe en RAM/IO
    );
end datapath;

architecture Behavioral of datapath is

    -- ==========================================================
    -- Declaración del componente ALU
    -- ==========================================================

    component alu
        Port (
            A       : in  STD_LOGIC_VECTOR(7 downto 0);
            B       : in  STD_LOGIC_VECTOR(7 downto 0);
            ALU_Sel : in  STD_LOGIC_VECTOR(1 downto 0);
            Result  : out STD_LOGIC_VECTOR(7 downto 0);
            Zero    : out STD_LOGIC
        );
    end component;

    -- ==========================================================
    -- Declaración del componente Banco de Registros
    -- ==========================================================

    component register_bank
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            we          : in  STD_LOGIC;
            read_addr1  : in  STD_LOGIC_VECTOR(1 downto 0);
            read_addr2  : in  STD_LOGIC_VECTOR(1 downto 0);
            write_addr  : in  STD_LOGIC_VECTOR(1 downto 0);
            write_data  : in  STD_LOGIC_VECTOR(7 downto 0);
            read_data1  : out STD_LOGIC_VECTOR(7 downto 0);
            read_data2  : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- ==========================================================
    -- Registros internos principales
    -- ==========================================================

    -- Program Counter:
    -- Guarda la dirección de la próxima posición de la ROM
    -- que se va a leer.
    signal PC_reg : unsigned(7 downto 0) := (others => '0');

    -- Instruction Register:
    -- Guarda el opcode de la instrucción actual.
    signal IR_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- Registro de operando:
    -- Guarda el segundo byte de la instrucción.
    -- Puede ser una dirección o un dato inmediato.
    signal Operand_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- ==========================================================
    -- Señales internas de conexión
    -- ==========================================================

    -- Resultado entregado por la ALU.
    signal alu_result_sig : STD_LOGIC_VECTOR(7 downto 0);

    -- Datos leídos desde el banco de registros.
    signal reg_read1_sig : STD_LOGIC_VECTOR(7 downto 0);
    signal reg_read2_sig : STD_LOGIC_VECTOR(7 downto 0);

    -- Dato que finalmente se escribirá en el banco de registros.
    signal reg_write_data : STD_LOGIC_VECTOR(7 downto 0);

begin

    -- ==========================================================
    -- Proceso del PC, IR y registro de operando
    -- ==========================================================
    -- Este proceso es síncrono con el reloj y responde al reset.
    --
    -- PC:
    --   - Se reinicia en cero con reset.
    --   - Se incrementa con PC_Inc.
    --   - Se carga con Operand_reg cuando PC_Load = 1.
    --
    -- IR:
    --   - Guarda el opcode leído desde la ROM.
    --
    -- Operand_reg:
    --   - Guarda el operando leído desde la ROM.
    -- ==========================================================

    process(clk, reset)
    begin
        if reset = '1' then

            -- Reset general del datapath.
            PC_reg      <= (others => '0');
            IR_reg      <= (others => '0');
            Operand_reg <= (others => '0');

        elsif rising_edge(clk) then

            -- Control del Program Counter.
            if PC_Load = '1' then

                -- Carga el PC con el operando.
                -- Esto se usa en instrucciones de salto.
                PC_reg <= unsigned(Operand_reg);

            elsif PC_Inc = '1' then

                -- Incrementa el PC para avanzar a la siguiente
                -- posición de la ROM.
                PC_reg <= PC_reg + 1;

            end if;

            -- Carga del opcode actual.
            if IR_Load = '1' then
                IR_reg <= ROM_Data;
            end if;

            -- Carga del operando de la instrucción.
            if Op_Load = '1' then
                Operand_reg <= ROM_Data;
            end if;

        end if;
    end process;

    -- ==========================================================
    -- Multiplexor de escritura al banco de registros
    -- ==========================================================
    -- Decide qué dato se va a escribir en el registro destino.
    --
    -- "00" -> Resultado de la ALU.
    -- "01" -> Dato leído desde RAM/IO.
    -- "10" -> Operando inmediato.
    -- ==========================================================

    process(Mux_RegWrite_Sel, alu_result_sig, RAM_Data_In, Operand_reg)
    begin
        case Mux_RegWrite_Sel is

            when "00" =>
                -- Se guarda el resultado generado por la ALU.
                reg_write_data <= alu_result_sig;

            when "01" =>
                -- Se guarda el dato leído desde RAM/IO.
                -- Por ejemplo, cuando se lee el puerto 0xFE.
                reg_write_data <= RAM_Data_In;

            when "10" =>
                -- Se guarda directamente el operando de la instrucción.
                -- Se usa en instrucciones inmediatas como MOVI_R0 o MOVI_R1.
                reg_write_data <= Operand_reg;

            when others =>
                -- Caso de seguridad.
                reg_write_data <= (others => '0');

        end case;
    end process;

    -- ==========================================================
    -- Instancia de la ALU
    -- ==========================================================
    -- La ALU recibe dos datos del banco de registros y realiza
    -- la operación indicada por ALU_Sel.
    -- ==========================================================

    Inst_ALU: alu port map(
        A       => reg_read1_sig,
        B       => reg_read2_sig,
        ALU_Sel => ALU_Sel,
        Result  => alu_result_sig,
        Zero    => Zero_Flag
    );

    -- ==========================================================
    -- Instancia del banco de registros
    -- ==========================================================
    -- Permite leer dos registros al mismo tiempo y escribir uno.
    -- ==========================================================

    Inst_RegBank: register_bank port map(
        clk         => clk,
        reset       => reset,
        we          => Reg_WE,
        read_addr1  => Reg_SrcA,
        read_addr2  => Reg_SrcB,
        write_addr  => Reg_Dest,
        write_data  => reg_write_data,
        read_data1  => reg_read1_sig,
        read_data2  => reg_read2_sig
    );

    -- ==========================================================
    -- Asignaciones hacia el exterior del datapath
    -- ==========================================================

    -- La dirección de ROM viene del Program Counter.
    ROM_Addr <= std_logic_vector(PC_reg);

    -- El opcode actual se entrega a la unidad de control.
    Opcode <= IR_reg;

    -- La dirección para RAM/IO corresponde al operando.
    -- Ejemplo:
    --   0xFE para leer switches.
    --   0xFF para escribir salidas.
    RAM_Addr <= Operand_reg;

    -- El dato que se escribe en RAM/IO sale del registro fuente A.
    RAM_Data_Out <= reg_read1_sig;

end Behavioral;
