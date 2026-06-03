-- ==========================================================
-- Archivo: cpu_top.vhd
-- Descripción:
--   Módulo principal, top-level, del microcontrolador.
--
-- Función:
--   Conecta todos los bloques internos del proyecto:
--      - ROM de programa
--      - RAM e interfaz de entrada/salida
--      - Datapath
--      - Unidad de control
--
-- Entradas físicas:
--   clk      : reloj de 50 MHz de la DE0
--   reset    : reset del sistema
--   sw_modo  : selector de modo manual/automático
--   sw_ilum  : switch de iluminación manual
--   sw_vent  : switch de ventilación manual
--
-- Salidas físicas:
--   out_ilum  : salida hacia LEDG0 interno
--   out_vent  : salida hacia LEDG1 interno
--   gpio_ilum : salida hacia GPIO0_D0 para maqueta
--   gpio_vent : salida hacia GPIO0_D1 para ventilador
--
-- Nota:
--   Las salidas internas y las salidas GPIO son duplicadas.
--   Es decir, la misma señal se observa en los LEDs de la FPGA
--   y también sale por GPIO0 para la maqueta física.
-- ==========================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cpu_top is
    Port (
        clk      : in  STD_LOGIC; -- Reloj principal
        reset    : in  STD_LOGIC; -- Reset del microcontrolador

        -- Entradas desde switches físicos
        sw_modo  : in  STD_LOGIC; -- SW0: 0 = manual, 1 = automático
        sw_ilum  : in  STD_LOGIC; -- SW1: iluminación manual
        sw_vent  : in  STD_LOGIC; -- SW2: ventilación manual

        -- Salidas hacia LEDs internos de la DE0
        out_ilum : out STD_LOGIC; -- LEDG0
        out_vent : out STD_LOGIC; -- LEDG1

        -- Salidas hacia GPIO0 para la maqueta física
        gpio_ilum : out STD_LOGIC; -- GPIO0_D0
        gpio_vent : out STD_LOGIC  -- GPIO0_D1
    );
end cpu_top;

architecture Structural of cpu_top is

    -- ==========================================================
    -- Declaración del componente ROM
    -- ==========================================================

    component rom
        Port (
            address     : in  STD_LOGIC_VECTOR(7 downto 0);
            instruction : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- ==========================================================
    -- Declaración del componente RAM/IO
    -- ==========================================================

    component ram_io
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            we          : in  STD_LOGIC;
            address     : in  STD_LOGIC_VECTOR(7 downto 0);
            write_data  : in  STD_LOGIC_VECTOR(7 downto 0);
            read_data   : out STD_LOGIC_VECTOR(7 downto 0);

            sw_modo     : in  STD_LOGIC;
            sw_ilum     : in  STD_LOGIC;
            sw_vent     : in  STD_LOGIC;

            out_ilum    : out STD_LOGIC;
            out_vent    : out STD_LOGIC
        );
    end component;

    -- ==========================================================
    -- Declaración del componente Datapath
    -- ==========================================================

    component datapath
        Port (
            clk              : in  STD_LOGIC;
            reset            : in  STD_LOGIC;

            PC_Load          : in  STD_LOGIC;
            PC_Inc           : in  STD_LOGIC;
            IR_Load          : in  STD_LOGIC;
            Op_Load          : in  STD_LOGIC;
            Reg_WE           : in  STD_LOGIC;
            Reg_Dest         : in  STD_LOGIC_VECTOR(1 downto 0);
            Reg_SrcA         : in  STD_LOGIC_VECTOR(1 downto 0);
            Reg_SrcB         : in  STD_LOGIC_VECTOR(1 downto 0);
            ALU_Sel          : in  STD_LOGIC_VECTOR(1 downto 0);
            Mux_RegWrite_Sel : in  STD_LOGIC_VECTOR(1 downto 0);

            Opcode           : out STD_LOGIC_VECTOR(7 downto 0);
            Zero_Flag        : out STD_LOGIC;

            ROM_Addr         : out STD_LOGIC_VECTOR(7 downto 0);
            ROM_Data         : in  STD_LOGIC_VECTOR(7 downto 0);

            RAM_Addr         : out STD_LOGIC_VECTOR(7 downto 0);
            RAM_Data_In      : in  STD_LOGIC_VECTOR(7 downto 0);
            RAM_Data_Out     : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- ==========================================================
    -- Declaración del componente Unidad de Control
    -- ==========================================================

    component control_unit
        Port (
            clk              : in  STD_LOGIC;
            reset            : in  STD_LOGIC;

            Opcode           : in  STD_LOGIC_VECTOR(7 downto 0);
            Zero_Flag        : in  STD_LOGIC;

            PC_Load          : out STD_LOGIC;
            PC_Inc           : out STD_LOGIC;
            IR_Load          : out STD_LOGIC;
            Op_Load          : out STD_LOGIC;
            Reg_WE           : out STD_LOGIC;
            Reg_Dest         : out STD_LOGIC_VECTOR(1 downto 0);
            Reg_SrcA         : out STD_LOGIC_VECTOR(1 downto 0);
            Reg_SrcB         : out STD_LOGIC_VECTOR(1 downto 0);
            ALU_Sel          : out STD_LOGIC_VECTOR(1 downto 0);
            Mux_RegWrite_Sel : out STD_LOGIC_VECTOR(1 downto 0);

            RAM_WE           : out STD_LOGIC
        );
    end component;

    -- ==========================================================
    -- Señales internas de control
    -- ==========================================================

    signal ctrl_PC_Load          : STD_LOGIC;
    signal ctrl_PC_Inc           : STD_LOGIC;
    signal ctrl_IR_Load          : STD_LOGIC;
    signal ctrl_Op_Load          : STD_LOGIC;
    signal ctrl_Reg_WE           : STD_LOGIC;
    signal ctrl_Reg_Dest         : STD_LOGIC_VECTOR(1 downto 0);
    signal ctrl_Reg_SrcA         : STD_LOGIC_VECTOR(1 downto 0);
    signal ctrl_Reg_SrcB         : STD_LOGIC_VECTOR(1 downto 0);
    signal ctrl_ALU_Sel          : STD_LOGIC_VECTOR(1 downto 0);
    signal ctrl_Mux_RegWrite_Sel : STD_LOGIC_VECTOR(1 downto 0);
    signal ctrl_RAM_WE           : STD_LOGIC;

    -- ==========================================================
    -- Señales de estado entre datapath y control_unit
    -- ==========================================================

    signal status_Opcode    : STD_LOGIC_VECTOR(7 downto 0);
    signal status_Zero_Flag : STD_LOGIC;

    -- ==========================================================
    -- Buses de ROM y RAM/IO
    -- ==========================================================

    signal bus_ROM_Addr     : STD_LOGIC_VECTOR(7 downto 0);
    signal bus_ROM_Data     : STD_LOGIC_VECTOR(7 downto 0);

    signal bus_RAM_Addr     : STD_LOGIC_VECTOR(7 downto 0);
    signal bus_RAM_Data_In  : STD_LOGIC_VECTOR(7 downto 0);
    signal bus_RAM_Data_Out : STD_LOGIC_VECTOR(7 downto 0);

    -- ==========================================================
    -- Señales internas de salida
    -- ==========================================================
    -- Estas señales salen de ram_io.vhd y luego se duplican hacia
    -- LEDs internos y GPIO0.
    -- ==========================================================

    signal sig_ilum : STD_LOGIC;
    signal sig_vent : STD_LOGIC;

begin

    -- ==========================================================
    -- Duplicación de salidas físicas
    -- ==========================================================
    -- La misma señal de iluminación se envía al LED interno
    -- y también a GPIO0_D0.
    --
    -- La misma señal de ventilación se envía al LED interno
    -- y también a GPIO0_D1.
    -- ==========================================================

    out_ilum  <= sig_ilum;
    out_vent  <= sig_vent;

    gpio_ilum <= sig_ilum;
    gpio_vent <= sig_vent;

    -- ==========================================================
    -- Instancia de la ROM de programa
    -- ==========================================================

    Inst_ROM: rom port map(
        address     => bus_ROM_Addr,
        instruction => bus_ROM_Data
    );

    -- ==========================================================
    -- Instancia de RAM e interfaz de entrada/salida
    -- ==========================================================

    Inst_RAM_IO: ram_io port map(
        clk         => clk,
        reset       => reset,
        we          => ctrl_RAM_WE,
        address     => bus_RAM_Addr,
        write_data  => bus_RAM_Data_Out,
        read_data   => bus_RAM_Data_In,

        sw_modo     => sw_modo,
        sw_ilum     => sw_ilum,
        sw_vent     => sw_vent,

        out_ilum    => sig_ilum,
        out_vent    => sig_vent
    );

    -- ==========================================================
    -- Instancia del datapath
    -- ==========================================================

    Inst_Datapath: datapath port map(
        clk              => clk,
        reset            => reset,

        PC_Load          => ctrl_PC_Load,
        PC_Inc           => ctrl_PC_Inc,
        IR_Load          => ctrl_IR_Load,
        Op_Load          => ctrl_Op_Load,
        Reg_WE           => ctrl_Reg_WE,
        Reg_Dest         => ctrl_Reg_Dest,
        Reg_SrcA         => ctrl_Reg_SrcA,
        Reg_SrcB         => ctrl_Reg_SrcB,
        ALU_Sel          => ctrl_ALU_Sel,
        Mux_RegWrite_Sel => ctrl_Mux_RegWrite_Sel,

        Opcode           => status_Opcode,
        Zero_Flag        => status_Zero_Flag,

        ROM_Addr         => bus_ROM_Addr,
        ROM_Data         => bus_ROM_Data,

        RAM_Addr         => bus_RAM_Addr,
        RAM_Data_In      => bus_RAM_Data_In,
        RAM_Data_Out     => bus_RAM_Data_Out
    );

    -- ==========================================================
    -- Instancia de la unidad de control
    -- ==========================================================

    Inst_ControlUnit: control_unit port map(
        clk              => clk,
        reset            => reset,

        Opcode           => status_Opcode,
        Zero_Flag        => status_Zero_Flag,

        PC_Load          => ctrl_PC_Load,
        PC_Inc           => ctrl_PC_Inc,
        IR_Load          => ctrl_IR_Load,
        Op_Load          => ctrl_Op_Load,
        Reg_WE           => ctrl_Reg_WE,
        Reg_Dest         => ctrl_Reg_Dest,
        Reg_SrcA         => ctrl_Reg_SrcA,
        Reg_SrcB         => ctrl_Reg_SrcB,
        ALU_Sel          => ctrl_ALU_Sel,
        Mux_RegWrite_Sel => ctrl_Mux_RegWrite_Sel,

        RAM_WE           => ctrl_RAM_WE
    );

end Structural;
