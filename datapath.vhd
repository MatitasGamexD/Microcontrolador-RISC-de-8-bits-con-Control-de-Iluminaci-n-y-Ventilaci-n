```vhdl
-- ==========================================================
-- Archivo: datapath.vhd
--
-- Este archivo contiene el camino de datos del microcontrolador.
-- Aquí se conectan las partes que mueven, guardan y procesan datos,
-- como el PC, el IR, el banco de registros y la ALU.
--
-- La unidad de control es la que manda las señales para decidir
-- qué debe hacer el datapath en cada estado de la FSM.
--
-- También se manejan buses separados para instrucciones y datos,
-- siguiendo la idea de arquitectura Harvard.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity datapath is
    Port (
        clk              : in  STD_LOGIC; -- Reloj principal del sistema
        reset            : in  STD_LOGIC; -- Reinicia los registros internos

        -- Señales que vienen desde la unidad de control.
        -- Con estas señales se maneja el comportamiento interno del datapath.
        PC_Load          : in  STD_LOGIC; -- Carga el PC con el operando, usado en saltos
        PC_Inc           : in  STD_LOGIC; -- Incrementa el PC para avanzar en la ROM
        IR_Load          : in  STD_LOGIC; -- Guarda el opcode en el registro de instrucción
        Op_Load          : in  STD_LOGIC; -- Guarda el operando de la instrucción
        Reg_WE           : in  STD_LOGIC; -- Habilita la escritura en el banco de registros

        Reg_Dest         : in  STD_LOGIC_VECTOR(1 downto 0); -- Registro donde se escribe el dato
        Reg_SrcA         : in  STD_LOGIC_VECTOR(1 downto 0); -- Primer registro que se va a leer
        Reg_SrcB         : in  STD_LOGIC_VECTOR(1 downto 0); -- Segundo registro que se va a leer

        ALU_Sel          : in  STD_LOGIC_VECTOR(1 downto 0); -- Selecciona la operación de la ALU

        -- Selecciona qué dato se escribe en el banco de registros:
        -- "00" = resultado de la ALU, "01" = dato de RAM/IO, "10" = operando inmediato.
        Mux_RegWrite_Sel : in  STD_LOGIC_VECTOR(1 downto 0);

        -- Señales que el datapath le entrega a la unidad de control.
        Opcode           : out STD_LOGIC_VECTOR(7 downto 0); -- Opcode de la instrucción actual
        Zero_Flag        : out STD_LOGIC;                    -- Bandera de cero generada por la ALU

        -- Bus hacia la ROM, donde están guardadas las instrucciones.
        ROM_Addr         : out STD_LOGIC_VECTOR(7 downto 0); -- Dirección que se envía a la ROM
        ROM_Data         : in  STD_LOGIC_VECTOR(7 downto 0); -- Dato leído desde la ROM

        -- Bus hacia RAM/IO, donde están los datos y los puertos externos.
        RAM_Addr         : out STD_LOGIC_VECTOR(7 downto 0); -- Dirección que se envía a RAM/IO
        RAM_Data_In      : in  STD_LOGIC_VECTOR(7 downto 0); -- Dato leído desde RAM/IO
        RAM_Data_Out     : out STD_LOGIC_VECTOR(7 downto 0)  -- Dato que se escribe en RAM/IO
    );
end datapath;

architecture Behavioral of datapath is

    -- Componente ALU usado dentro del datapath.
    component alu
        Port (
            A       : in  STD_LOGIC_VECTOR(7 downto 0);
            B       : in  STD_LOGIC_VECTOR(7 downto 0);
            ALU_Sel : in  STD_LOGIC_VECTOR(1 downto 0);
            Result  : out STD_LOGIC_VECTOR(7 downto 0);
            Zero    : out STD_LOGIC
        );
    end component;

    -- Componente del banco de registros.
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

    -- Program Counter: guarda la dirección de la próxima instrucción en la ROM.
    signal PC_reg : unsigned(7 downto 0) := (others => '0');

    -- Instruction Register: guarda el opcode que se está ejecutando.
    signal IR_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- Registro de operando: guarda el segundo byte de la instrucción.
    -- Este valor puede ser una dirección de memoria o un dato inmediato.
    signal Operand_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

    -- Señal interna con el resultado que entrega la ALU.
    signal alu_result_sig : STD_LOGIC_VECTOR(7 downto 0);

    -- Datos que salen del banco de registros.
    signal reg_read1_sig : STD_LOGIC_VECTOR(7 downto 0);
    signal reg_read2_sig : STD_LOGIC_VECTOR(7 downto 0);

    -- Dato que finalmente se escribe en el banco de registros.
    signal reg_write_data : STD_LOGIC_VECTOR(7 downto 0);

begin

    -- Proceso principal del PC, IR y registro de operando.
    -- Se actualiza con el reloj y también responde al reset.
    process(clk, reset)
    begin
        if reset = '1' then

            -- Cuando hay reset, se limpian los registros principales del datapath.
            PC_reg      <= (others => '0');
            IR_reg      <= (others => '0');
            Operand_reg <= (others => '0');

        elsif rising_edge(clk) then

            -- Control del Program Counter.
            if PC_Load = '1' then

                -- En los saltos, el PC toma el valor guardado en el operando.
                PC_reg <= unsigned(Operand_reg);

            elsif PC_Inc = '1' then

                -- Si no hay salto, el PC avanza a la siguiente posición de la ROM.
                PC_reg <= PC_reg + 1;

            end if;

            -- Carga el opcode actual desde la ROM.
            if IR_Load = '1' then
                IR_reg <= ROM_Data;
            end if;

            -- Carga el operando de la instrucción desde la ROM.
            if Op_Load = '1' then
                Operand_reg <= ROM_Data;
            end if;

        end if;
    end process;

    -- Multiplexor para elegir qué dato se va a guardar en el banco de registros.
    process(Mux_RegWrite_Sel, alu_result_sig, RAM_Data_In, Operand_reg)
    begin
        case Mux_RegWrite_Sel is

            when "00" =>
                -- Guarda el resultado que viene de la ALU.
                reg_write_data <= alu_result_sig;

            when "01" =>
                -- Guarda el dato leído desde RAM/IO, por ejemplo desde el puerto 0xFE.
                reg_write_data <= RAM_Data_In;

            when "10" =>
                -- Guarda directamente el operando inmediato de la instrucción.
                reg_write_data <= Operand_reg;

            when others =>
                -- Caso de seguridad por si llega un valor no esperado.
                reg_write_data <= (others => '0');

        end case;
    end process;

    -- Instancia de la ALU.
    -- Recibe dos datos del banco de registros y realiza la operación indicada.
    Inst_ALU: alu port map(
        A       => reg_read1_sig,
        B       => reg_read2_sig,
        ALU_Sel => ALU_Sel,
        Result  => alu_result_sig,
        Zero    => Zero_Flag
    );

    -- Instancia del banco de registros.
    -- Permite leer dos registros al mismo tiempo y escribir en uno.
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

    -- La dirección de la ROM sale del Program Counter.
    ROM_Addr <= std_logic_vector(PC_reg);

    -- El opcode actual se manda hacia la unidad de control.
    Opcode <= IR_reg;

    -- La dirección de RAM/IO viene del operando.
    -- Por ejemplo, 0xFE para leer switches y 0xFF para escribir salidas.
    RAM_Addr <= Operand_reg;

    -- El dato que se escribe en RAM/IO viene del primer registro leído.
    RAM_Data_Out <= reg_read1_sig;

end Behavioral;
