# Programming the FPGA Flash Memory
There are four Lattice iCE40 FPGAs on the AmigaPCI board. Each FPGA has an associated flash memory module to store the FPGA configuration, which is loaded by the FPGA at startup. Each flash memory module has a programming header. The header is identified similarly to the associated FPGA. For example, CN712 programs the flash module for U712. CN409 for U409, etc.

## Programming with a FT232H USB to SPI Board
We will discuss programming the flash memory modules using iceprog with cheap FTDI FT232H interface boards. Such an example is the [Adafruit FT232H](https://www.adafruit.com/product/2264). Similar boards can be obtained from other manufacturers. The following steps describe how to program the flash modules. Do not leave the AmigaPCI powered on for longer than necessary during the programming process.

It is recommended to program the FPGA's in specific order. Program any FPGAs on the local bus card first. If you have the AmigaPCI local bus card ("THE BRAIN") program these in this order: U400, U111. Then, on the AmigaPCI, program these in this order: U409, U712, U110, U109.

### Obtain ICEPROG programming tool
#### Linux
   Install [icestorm](https://github.com/YosysHQ/icestorm).  

   Debian:
   ```
   sudo apt install fpga-icestorm
   ```
   Fedora:
   ```
   sudo dnf install icestorm
   ```
#### Windows
   Download from [FPGAwars](https://github.com/FPGAwars/toolchain-icestorm/wiki#testing-in-windows) GitHub.  

### Install FPGA Firmware
1. If it is on, turn off the AmigaPCI.
2. Connect the FT232H board to the desired FPGA programming port.
   
   AmigaPCI|Adafruit FT232H|C232HM MPSSE
   -|-|-
   GND|GND|Black/GND
   SDI|D1/MOSI|Yellow/DO
   SCLK|D0/SCK/SCL|Orange/SK
   SDO|D2/MISO|Green/DI
   SS|D4|Gray/GPIOL0
   CRST|D7|Blue/GPIOL3

   
3. Turn the AmigaPCI on.  
4. Execute iceprog with the correct BIN file.  

   ```
   iceprog U712.bin
   ```
5. Repeat steps 2 through 5 for each FPGA. Power cycle the AmigaPCI once complete.  
