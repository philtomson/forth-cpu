# Forth computing system

Author:

* Richard James Howe.

Copyright:

* Copyright 2013-2017 Richard James Howe.

License:

* MIT/LGPL

Email:

* howe.r.j.89@gmail.com

## Introduction

This project implements a small stack computer tailored to executing Forth
based on the [J1][] CPU. The processor has been rewritten in [VHDL][] from
[Verilog][], and extended slightly. The project is a work in progress and is
needs a lot of work before become usable.

The goals of the project are as follows:

* Create a working version of [J1][] processor (called the H2).
* Make a working toolchain for the processor.
* Create a [FORTH][] for the processor which can take its input either from a
  [UART][] or a USB keyboard and a [VGA][] adapter.

The H2 processor, like the [J1][], is a stack based processor that executes an
instruction set especially suited for [FORTH][].

The current target is the [Nexys3][] board, new boards will be targeted in the
future as this board is reaching it's end of life. The [VHDL][] is written in a
generic way, with hardware components being inferred instead of explicitly
instantiated, this should make the code fairly portable.

## License

The licenses used by the project are mixed and are on a per file basis. For my
code I use the [MIT][] license - so feel free to use it as you wish. The other
licenses used are the [LGPL][], they are confined to single modules so could be
removed if you have some aversion to [LGPL][] code.

## Target Board

The only target board available at the moment is the [Nexys3][], this should
change in the future as the board is currently at it's End Of Life. The next
boards I am looking to support are it's successor, the Nexys 4, and the myStorm
BlackIce (<https://mystorm.uk/>). The myStorm board uses a completely open
source toolchain for synthesis, place and route and bit file generation.

## Build requirements

The build has been tested under [Debian][] [Linux][], version 8.

You will require:

* [GCC][], or a suitable [C][] compiler capable of compiling [C99][]
* [Make][]
* [Xilinx ISE][] version 14.7
* [GHDL][]
* [GTKWave][]
* [tcl][] version 8.6
* Digilent Adept2 runtime and Digilent Adept2 utilities available at
  <http://store.digilentinc.com/digilent-adept-2-download-only/>

[Xilinx ISE][] can (or could be) downloaded for free, but requires
registration. ISE needs to be on your path:

	PATH=$PATH:/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64;
	PATH=$PATH:/opt/Xilinx/14.7/ISE_DS/ISE/lib/lin64;

## Building

To make a bit file that can be flashed to the target board:

	make simulation synthesis implementation bitfile

To upload the bitfile to the target board:

	make upload

To make the [C][] based toolchain:

	make h2

To view the wave form generated by "make simulation":

	make viewer

## Manual

The H2 processor and associated peripherals are subject to change, so the code
is the definitive source what instructions are available, the register map, and
how the peripherals behave.

There are a few modifications to the [J1][] CPU which include:

* New instructions
* A CPU hold line which keeps the processor in the same state so long as it is
high.
* Interrupt Service Routines have been added.

The Interrupt Service Routines (ISR) have not been throughly tested and will be
subject to the most change.

### H2 CPU

The H2 CPU behaves very similarly to the [J1][] CPU, and the [J1 PDF][] can be
read in order to better understand this processor.

	*---------------------------------------------------------------*
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	*---------------------------------------------------------------*
	| 1 |                    LITERAL VALUE                          |
	*---------------------------------------------------------------*
	| 0 | 0 | 0 |            BRANCH TARGET ADDRESS                  |
	*---------------------------------------------------------------*
	| 0 | 0 | 1 |            CONDITIONAL BRANCH TARGET ADDRESS      |
	*---------------------------------------------------------------*
	| 0 | 1 | 0 |            CALL TARGET ADDRESS                    |
	*---------------------------------------------------------------*
	| 0 | 1 | 1 |   ALU OPERATION   |T2N|T2R|N2A|R2P| RSTACK| DSTACK|
	*---------------------------------------------------------------*
	| F | E | D | C | B | A | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
	*---------------------------------------------------------------*

	T   : Top of data stack
	N   : Next on data stack
	PC  : Program Counter

	LITERAL VALUES : push a value onto the data stack
	CONDITIONAL    : BRANCHS pop and test the T
	CALLS          : PC+1 onto the return stack

	T2N : Move T to N
	T2R : Move T to top of return stack
	N2A : STORE T to memory location addressed by N
	R2P : Move top of return stack to PC

	RSTACK and DSTACK are signed values (twos compliment) that are
	the stack delta (the amount to increment or decrement the stack
	by for their respective stacks: return and data)

#### ALU OPERATIONS

All ALU operations replace T:

	*-------*----------------*-----------------------*
	| Value |   Operation    |     Description       |
	*-------*----------------*-----------------------*
	|   0   |       T        |  Top of Stack         |
	|   1   |       N        |  Copy T to N          |
	|   2   |     T + N      |  Addition             |
	|   3   |     T & N      |  Bitwise AND          |
	|   4   |     T | N      |  Bitwise OR           |
	|   5   |     T ^ N      |  Bitwise XOR          |
	|   6   |      ~T        |  Bitwise Inversion    |
	|   7   |     T = N      |  Equality test        |
	|   8   |     N < T      |  Signed comparison    |
	|   9   |     N >> T     |  Logical Right Shift  |
	|  10   |     T - 1      |  Decrement            |
	|  11   |       R        |  Top of return stack  |
	|  12   |      [T]       |  Load from address    |
	|  13   |     N << T     |  Logical Left Shift   |
	|  14   |     depth      |  Depth of stack       |
	|  15   |     N u< T     |  Unsigned comparison  |
	|  16   | set interrupts |  Enable interrupts    |
	|  17   | interrupts on? |  Are interrupts on?   |
	|  18   |     rdepth     |  Depth of return stk  |
	|  19   |      0=        |  T == 0?              |
	*-------*----------------*-----------------------*

### Peripherals and registers

Registers marked prefixed with an 'o' are output registers, those with an 'i'
prefix are input registers.

	*---------------------------------------------------------*
	|                   Input Registers                       |
	*-------------*---------*---------------------------------*
	| Register    | Address | Description                     |
	*-------------*---------*---------------------------------*
	| iUart       | 0x6000  | UART register                   |
	| iSwitches   | 0x6001  | Buttons and switches            |
	| iTimerCtrl  | 0x6002  | Timer control Register          |
	| iTimerDin   | 0x6003  | Current Timer Value             |
	| iVgaTxtDout | 0x6004  | Contents of address oVgaTxtAddr |
	| iPs2        | 0x6005  | PS2 Keyboard Register           |
	*-------------*---------*---------------------------------*

	*---------------------------------------------------------*
	|                   Output Registers                      |
	*-------------*---------*---------------------------------*
	| Register    | Address | Description                     |
	*-------------*---------*---------------------------------*
	| oUart       | 0x6000  | UART register                   |
	| oLeds       | 0x6001  | LED outputs                     |
	| oTimerCtrl  | 0x6002  | Timer control                   |
	| oVgaCursor  | 0x6003  | VGA Cursor X/Y cursor position  |
	| oVgaCtrl    | 0x6004  | VGA control registers           |
	| oVgaTxtAddr | 0x6005  | VGA Address to write to         |
	| oVgaTxtDin  | 0x6006  | VGA Data to write to            |
	| oVgaWrite   | 0x6007  | Write oVgaTxtDin to oVgaTxtAddr |
	| o8SegLED_0  | 0x6008  | LED 8 Segment display 0         |
	| o8SegLED_1  | 0x6009  | LED 8 Segment display 1         |
	| o8SegLED_2  | 0x600a  | LED 8 Segment display 2         |
	| o8SegLED_3  | 0x600b  | LED 8 Segment display 3         |
	| oIrcMask    | 0x600c  | CPU Interrupt Mask              |
	*-------------*---------*---------------------------------*

#### oUart

A UART with a fixed baud rate and format (115200, 8 bits, 1 stop bit) is
present on the SoC. The UART has a FIFO of depth 8 on both the RX and TX
channels. The control of the UART is split across oUart and iUart. 

To write a value to the UART assert TXWE along with putting the data in TXDO.
The FIFO state can be analyzed by looking at the iUart register.

To read a value from the UART: iUart can be checked to see if data is present
in the FIFO, if it is assert RXRE in the oUart register, on the next clock
cycle the data will be present in the iUart register.

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |TXWE|  X |  X |RXRE|  X |  X |               TXDO                    |
	*-------------------------------------------------------------------------------*

	TXWE: UART RT Write Enable
	RXRE: UART RX Read Enable
	TXDO: Uart TX Data Output


#### oLeds

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |              LEDO                     |
	*-------------------------------------------------------------------------------*

	LEDO: LED Output

#### oTimerCtrl

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	| TE | RST|INTE|                      TCMP                                      |
	*-------------------------------------------------------------------------------*

	TE:   Timer Enable
	RST:  Timer Reset
	INTE: Interrupt Enable
	TCMP: Timer Compare Value

#### oVgaCursor

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |          POSY               |  X |            POSX                  |
	*-------------------------------------------------------------------------------*

	POSY: VGA Text Cursor Position Y
	POSX: VGA Text Cursor Position X


#### oVgaCtrl

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X | VEN| CEN| BLK| MOD| RED| GRN| BLU|
	*-------------------------------------------------------------------------------*

	VEN: VGA Enable
	CEN: Cursor Enable
	BLK: Cursor Blink
	MOD: Cursor Mode
	RED: Red Enable
	GRN: Green Enable
	BLU: Blue Enable

#### oVgaTxtAddr

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |                      VRAD                                      |
	*-------------------------------------------------------------------------------*

	VRAD: VGA RAM Address

#### oVgaTxtDin

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|                                     VRDI                                      |
	*-------------------------------------------------------------------------------*

	VRDI: VGA RAM Data Input

#### oVgaWrite

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |VRWE|
	*-------------------------------------------------------------------------------*

	VRWE: VGA Ram Write Enable

#### o8SegLED\_0

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |       L8SD        |
	*-------------------------------------------------------------------------------*

	L8SD: LED 8 Segment Display

#### o8SegLED\_1

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |       L8SD        |
	*-------------------------------------------------------------------------------*

	L8SD: LED 8 Segment Display

#### o8SegLED\_2

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |       L8SD        |
	*-------------------------------------------------------------------------------*

	L8SD: LED 8 Segment Display

#### o8SegLED\_3

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |  X |       L8SD        |
	*-------------------------------------------------------------------------------*

	L8SD: LED 8 Segment Display

#### oIrcMask

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |  X |                 IMSK                  |
	*-------------------------------------------------------------------------------*

	IMSK: Interrupt Mask

#### iUart

The iUart register works in conjunction with the oUart register. The status of
the FIFO that buffers both transmission and reception of bytes is available in
the iUart register, as well as any received bytes.

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |TFFL|TFEM|  X |RFFL|RFEM|                RXDI                   |
	*-------------------------------------------------------------------------------*

	TFFL: UART TX FIFO Full
	TFEM: UART TX FIFO Empty
	RFFL: UART RX FIFO Full
	RFEM: UART RX FIFO Empty
	RXDI: UART RX Data Input

#### iSwitches

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X | RX | BUP|BDWN|BLFT|BRGH|BCNT|               TSWI                    |
	*-------------------------------------------------------------------------------*

	RX:   UART RX Line
	DUP:  Button Up
	BDWN: Button Down
	BLFT: Button Left
	BRGH: Button Right
	BCNT: Button Center
	TSWI: Two Position Switches


#### iTimerCtrl

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	| TE | RST|INTE|                      TCMP                                      |
	*-------------------------------------------------------------------------------*

	TE:   Timer Enable
	RST:  Timer Reset
	INTE: Interrupt Enable
	TCMP: Timer Compare Value

#### iTimerDin

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |                       TCNT                                     |
	*-------------------------------------------------------------------------------*

	TCNT: Timer Counter Value

#### iVgaTxtDout

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|                                     VRDO                                      |
	*-------------------------------------------------------------------------------*

	VRDO: VGA RAM Data Output

#### iPs2

	*-------------------------------------------------------------------------------*
	| 15 | 14 | 13 | 12 | 11 | 10 |  9 |  8 |  7 |  6 |  5 |  4 |  3 |  2 |  1 |  0 |
	*-------------------------------------------------------------------------------*
	|  X |  X |  X |  X |  X |  X |  X |PS2N|  X |              ACHR                |
	*-------------------------------------------------------------------------------*

	PS2N: New character available on PS2 Keyboard
	ACHR: ASCII Character

#### Interrupt Service Routines

### Assembler, Disassembler and Simulator

The Assembler, Disassembler and [C][] based simulator for the H2 is in a single
program (see [h2.c][]). This simulator complements the [VHDL][] test bench
[tb.vhd][] and is not a replacement for it.

#### Assembler

The assembler is actually a compiler for a pseudo Forth like language with a
fixed grammar. 

### Coding standards

#### VHDL

#### C

#### FORTH

## To Do

* Make a bootloader/program loader
* Implement Forth interpreter on device
* Memory interface to Nexys 3 board on board memory
* A [Wishbone interface][] could be implemented for the H2 core
and peripherals


## Forth

* The on board memory could be linked up to the Forth block
word set.
* Most of the Forth code could be taken from my [libforth][]
project.

## Resources

* <https://nanode0000.wordpress.com/2017/04/08/exploring-the-j1-instruction-set-and-architecture/>
* <https://www.fpgarelated.com/showarticle/790.php>
* <https://opencores.org/>
* <https://en.wikipedia.org/wiki/Peephole_optimization>
* <https://en.wikipedia.org/wiki/Superoptimization>
* <https://github.com/samawati/j1eforth>
* <https://github.com/jamesbowman/j1>

[h2.c]: h2.c
[tb.vhd]: tb.vhd
[J1]: http://www.excamera.com/sphinx/fpga-j1.html
[J1 PDF]: excamera.com/files/j1.pdf
[PL/0]: https://github.com/howerj/pl0
[libforth]: https://github.com/howerj/libforth/
[MIT]: https://en.wikipedia.org/wiki/MIT_License
[LGPL]: https://www.gnu.org/licenses/lgpl-3.0.en.html
[VHDL]: https://en.wikipedia.org/wiki/VHDL
[Verilog]: https://en.wikipedia.org/wiki/Verilog
[UART]: https://en.wikipedia.org/wiki/Universal_asynchronous_receiver/transmitter
[FORTH]: https://en.wikipedia.org/wiki/Forth_%28programming_language%29
[VGA]: https://en.wikipedia.org/wiki/VGA
[Nexys3]: http://store.digilentinc.com/nexys-3-spartan-6-fpga-trainer-board-limited-time-see-nexys4-ddr/
[Make]: https://en.wikipedia.org/wiki/Make_%28software%29
[C]: https://en.wikipedia.org/wiki/C_%28programming_language%29
[Debian]: https://en.wikipedia.org/wiki/Debian
[Linux]: https://en.wikipedia.org/wiki/Linux
[GCC]: https://en.wikipedia.org/wiki/GNU_Compiler_Collection
[Xilinx ISE]: https://www.xilinx.com/products/design-tools/ise-design-suite.html
[GHDL]: http://ghdl.free.fr/
[GTKWave]: http://gtkwave.sourceforge.net/
[C99]: https://en.wikipedia.org/wiki/C99
[tcl]: https://en.wikipedia.org/wiki/Tcl
[Wishbone interface]: https://en.wikipedia.org/wiki/Wishbone_%28computer_bus%29

<style type="text/css">body{margin:40px auto;max-width:850px;line-height:1.6;font-size:16px;color:#444;padding:0 10px}h1,h2,h3{line-height:1.2}</style>
