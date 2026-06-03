# Microcontrolador-RISC-de-8-bits-con-Control-de-Iluminaci-n-y-Ventilaci-n
Microcontrolador RISC de 8 bits en VHDL para FPGA DE0, con arquitectura Harvard, FSM de control, ROM de instrucciones, RAM/IO, modo manual y automático para control de iluminación y ventilación.


# Microcontrolador RISC de 8 bits con Control de Iluminación y Ventilación

## Descripción del proyecto

Este proyecto consiste en el diseño e implementación de un **microcontrolador RISC de 8 bits en VHDL**, desarrollado para la tarjeta **FPGA DE0**. El sistema utiliza una **arquitectura Harvard**, separando la memoria de instrucciones y la memoria de datos/entrada-salida.

El microcontrolador permite controlar una maqueta de **iluminación y ventilación** mediante dos modos de funcionamiento:

* **Modo manual:** el usuario controla directamente la iluminación y el ventilador mediante switches físicos de la FPGA.
* **Modo automático:** el sistema controla automáticamente las salidas mediante temporizadores internos.

El proyecto fue desarrollado como práctica final de diseño digital, integrando conceptos de arquitectura de computadores, máquinas de estados finitos, datapath, ALU, banco de registros, memoria ROM, RAM e interfaces de entrada/salida.

---

## Objetivo general

Diseñar e implementar en VHDL un microcontrolador RISC de 8 bits capaz de ejecutar instrucciones almacenadas en memoria ROM e interactuar con dispositivos externos mediante puertos de entrada y salida en una FPGA DE0.

---

## Características principales

* Microcontrolador RISC de 8 bits.
* Arquitectura Harvard.
* Memoria ROM para programa.
* RAM interna y puertos de entrada/salida.
* Unidad de control basada en una máquina de estados finitos.
* Ciclo de instrucción: `FETCH → DECODE → EXECUTE`.
* Banco de registros de 4 registros de 8 bits.
* ALU con operaciones básicas.
* Modo manual y modo automático.
* Salidas duplicadas hacia LEDs internos y GPIO0.
* Testbench para simulación en ModelSim.
* Restricción de reloj para la FPGA DE0 a 50 MHz.

---

## Arquitectura general

El diseño está dividido en varios módulos VHDL:

```text
cpu_top.vhd
├── rom.vhd
├── ram_io.vhd
├── datapath.vhd
│   ├── alu.vhd
│   └── register_bank.vhd
└── control_unit.vhd
```

---

## Archivos del proyecto

### `cpu_top.vhd`

Es el módulo principal del proyecto. Integra todos los componentes del microcontrolador:

* ROM de instrucciones.
* RAM e interfaz de entrada/salida.
* Datapath.
* Unidad de control.

También duplica las salidas para que puedan observarse en los LEDs internos de la DE0 y utilizarse por GPIO0 para la maqueta física.

---

### `control_unit.vhd`

Contiene la unidad de control del microcontrolador, implementada mediante una máquina de estados finitos.

Los estados principales son:

```text
S_FETCH_OPCODE
S_FETCH_OPERAND
S_DECODE
S_EXECUTE
```

La unidad de control genera las señales necesarias para mover datos, cargar instrucciones, incrementar el PC, escribir registros, seleccionar operaciones de la ALU y habilitar escritura en RAM/IO.

---

### `datapath.vhd`

Contiene el camino de datos del microcontrolador.

Incluye:

* Program Counter.
* Instruction Register.
* Registro de operando.
* Banco de registros.
* ALU.
* Multiplexor de escritura.
* Buses de conexión con ROM y RAM/IO.

---

### `alu.vhd`

Implementa la Unidad Aritmético-Lógica de 8 bits.

Operaciones disponibles:

```text
00 → Suma
01 → Resta
10 → AND
11 → OR
```

Además genera la bandera `Zero`, que se activa cuando el resultado de la operación es cero.

---

### `register_bank.vhd`

Implementa un banco de 4 registros de 8 bits.

Los registros se seleccionan con direcciones de 2 bits:

```text
00 → R0
01 → R1
10 → R2
11 → R3
```

Permite dos lecturas simultáneas y una escritura síncrona por reloj.

---

### `rom.vhd`

Contiene el programa que ejecuta el microcontrolador.

El programa realiza el siguiente flujo:

1. Lee los switches desde la dirección `0xFE`.
2. Revisa el bit de modo mediante una operación AND.
3. Si el modo es manual, lee los switches de iluminación y ventilación.
4. Si el modo es automático, activa la lógica automática.
5. Escribe las salidas en la dirección `0xFF`.
6. Repite el ciclo.

---

### `ram_io.vhd`

Implementa la RAM interna y los puertos de entrada/salida.

Direcciones especiales:

```text
0xFE → Puerto de entrada
0xFF → Puerto de salida
```

En `0xFE` se leen los switches:

```text
00000 | sw_modo | sw_ilum | sw_vent
```

En `0xFF` se escriben las salidas:

```text
bit 1 → iluminación
bit 0 → ventilación
```

También contiene los temporizadores del modo automático.

---

### `cpu_top_tb.vhd`

Testbench del proyecto para simulación en ModelSim.

Prueba:

* Reset inicial.
* Modo manual.
* Iluminación manual.
* Ventilación manual.
* Salidas apagadas.
* Entrada al modo automático.
* Reset durante modo automático.
* Salidas internas y externas.

---

### `Microcontrolador_FSM.qsf`

Archivo de asignación de pines para la tarjeta DE0.

Define la conexión entre señales VHDL y pines físicos de la FPGA.

---

### `Microcontrolador_FSM.sdc`

Archivo de restricciones temporales.

Define el reloj principal del sistema:

```tcl
create_clock -name clk -period 20.000 [get_ports {clk}]
```

Este valor corresponde al reloj de 50 MHz de la tarjeta DE0.

---

## Modos de funcionamiento

## Modo manual

El modo manual se activa cuando:

```text
SW0 = 0
```

En este modo:

```text
SW1 controla la iluminación
SW2 controla la ventilación
```

Comportamiento:

| Switch | Función            |
| ------ | ------------------ |
| SW0    | Selección de modo  |
| SW1    | Iluminación manual |
| SW2    | Ventilación manual |
| SW9    | Reset              |

---

## Modo automático

El modo automático se activa cuando:

```text
SW0 = 1
```

En este modo, las salidas son controladas por temporizadores internos:

```text
Iluminación:
5 segundos encendida
5 segundos apagada

Ventilador:
5 segundos encendido
10 segundos apagado
```

---

## Pineado utilizado en la DE0

| Señal VHDL  | Elemento físico | Pin FPGA |
| ----------- | --------------- | -------- |
| `clk`       | CLOCK_50        | PIN_G21  |
| `reset`     | SW9             | PIN_D2   |
| `sw_modo`   | SW0             | PIN_J6   |
| `sw_ilum`   | SW1             | PIN_H5   |
| `sw_vent`   | SW2             | PIN_H6   |
| `out_ilum`  | LEDG0           | PIN_J1   |
| `out_vent`  | LEDG1           | PIN_J2   |
| `gpio_ilum` | GPIO0_D0        | PIN_AB16 |
| `gpio_vent` | GPIO0_D1        | PIN_AA16 |

---

## Salidas del sistema

El sistema tiene salidas duplicadas:

```text
out_ilum  → LEDG0 interno
out_vent  → LEDG1 interno

gpio_ilum → GPIO0_D0 para maqueta física
gpio_vent → GPIO0_D1 para maqueta física
```

Esto permite visualizar el funcionamiento en la tarjeta y, al mismo tiempo, controlar elementos externos.

---

## Control del ventilador

El ventilador no debe conectarse directamente al GPIO de la FPGA, ya que la FPGA entrega una señal lógica de 3.3V con poca corriente.

Para controlar un ventilador de 5V se recomienda usar un MOSFET canal N de compuerta lógica.

Conexión básica:

```text
GPIO0_D1 / gpio_vent → resistencia 220Ω o 330Ω → Gate del MOSFET
Source del MOSFET → GND
Drain del MOSFET → negativo del ventilador
Positivo del ventilador → +5V externo
GND de la fuente externa → GND de la FPGA
```

La FPGA solo entrega la señal de control. El ventilador se alimenta con una fuente externa.

---

## Simulación en ModelSim

Para simular el proyecto en ModelSim, se pueden usar los siguientes comandos:

```tcl
quit -sim

vlib work
vmap work work

vcom alu.vhd
vcom register_bank.vhd
vcom rom.vhd
vcom ram_io.vhd
vcom control_unit.vhd
vcom datapath.vhd
vcom cpu_top.vhd
vcom cpu_top_tb.vhd

vsim work.cpu_top_tb

add wave -r sim:/cpu_top_tb/*

run -all

wave zoom full
```

Si la simulación es correcta, debe aparecer el mensaje:

```text
SIMULACION FINALIZADA CORRECTAMENTE
```

---

## Instrucciones implementadas

| Instrucción | Código binario | Descripción                          |
| ----------- | -------------- | ------------------------------------ |
| `LOAD_R0`   | `00000001`     | Carga en R0 desde RAM/IO             |
| `LOAD_R1`   | `00000010`     | Carga en R1 desde RAM/IO             |
| `STORE_R0`  | `00000011`     | Guarda R0 en RAM/IO                  |
| `AND_REG`   | `00000100`     | Realiza R0 = R0 AND R1               |
| `JMP_ZERO`  | `00000101`     | Salta si la bandera Zero está activa |
| `JMP`       | `00000110`     | Salto incondicional                  |
| `MOVI_R1`   | `00000111`     | Carga un valor inmediato en R1       |
| `MOVI_R0`   | `00001000`     | Carga un valor inmediato en R0       |

---

## Requisitos cumplidos

* Arquitectura Harvard.
* Microcontrolador RISC de 8 bits.
* Ciclo de instrucción `FETCH → DECODE → EXECUTE`.
* Program Counter.
* Instruction Register.
* Banco de registros mínimo de 4 registros.
* ALU con operaciones básicas.
* Memoria ROM.
* Memoria RAM.
* Unidad de control implementada con FSM.
* Entrada/salida mediante direcciones de memoria.
* Modo manual.
* Modo automático.
* Salidas para iluminación y ventilación.
* Testbench de simulación.

---

## Herramientas utilizadas

* VHDL.
* Quartus II.
* ModelSim Altera Starter Edition.
* FPGA DE0.
* Tarjeta Altera Cyclone III.

---

## Autor

Proyecto desarrollado con fines académicos para la implementación de un microcontrolador RISC de 8 bits en VHDL.
