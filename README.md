<h1 align="center"><img src="/Images/AmigaPCI-logo-dark.png"></h1>

The AmigaPCI is an OCS/ECS Amiga computer in the ATX form factor. It provides a flexible CPU Local Bus port, five PCI slots for expansion purposes such as video and sound, an on-board dual port ATA controller, and offers performance improvements over legacy Amiga designs.

## Features  
<list>
  <li>CPU Local Bus Card supports multiple CPU and fast RAM options</li>
  <li>Five PCI 5V/Univeral slots</li>
  <li>PCI DMA allowing access to all Amiga and PCI address spaces</li>  
  <li>HID mouse and keyboard inputs</li>
  <li>Dual port IDE interface supporting up to 4 total devices</li>
  <li>Agnus 8372A or 8375 selectable by jumper</li>
  <li>Amiga Video Slot</li>
  <li>Floppy disk interface supports Amiga and PC drives in DD mode</li>
</list></br>

<p align="center"><img src="/Images/AmigaPCIMainboard-30.jpg"></p>

## Project Status  
**THIS IS A WORK IN PROGRESS AND IS SUBJECT TO CHANGE WITHOUT NOTICE.**

This is an active project and is currently in the prototype stage. Specifications are subject to change. Because this project is in the prototype stage, it is not recommended for general use at this time. There will be errors that adversely affect performance and the logic equations are not complete. If you choose to build this before final release, you accept all cost and risk associated with the decision.

I am not seeking hardware enhancement requests at this time, but feel free to post these in the issues section. Discussions can be found at Discord: https://discord.gg/NU7SPYfNFj.

## About the AmigaPCI Project

This is a hobby project. To me, the Amiga has a personality that PCs of any era cannot hope to replicate. I got my first Amiga, an A500, in 1992. In 1995, despite Commodore having gone out of business, I upgraded to a used A2000 with a GVP 030/SCSI card and flicker fixer. Even at this time we had a few Amiga shops hanging on. Around 1998 I relented and built a PC. The writing was on the wall for the Amiga and it was time to move on. The Amigas went into the closet, rarely to see the light. Sadly, like so many, I ended up selling my original machines only for my interest to rekindle years later. The purpose of my Amiga projects are to learn and hopefully share something of value with fellow Amigans by providing options for machines using modern components, whenever possible. This gave rise to the [A2000 EATX](https://github.com/jasonsbeer/Amiga-2000-EATX), the [N2630](https://github.com/jasonsbeer/Amiga-N2630), and now, the AmigaPCI.

# Building the AmigaPCI

Review the project [Wiki](https://github.com/AmigaPCI/AmigaPCI-MainBoard/wiki) to understand how to order, build, and use the AmigaPCI.

# Overview

## PCI Local Bus  
The PCI bus is based on the [PCI Local Bus Revision 2.3 specifications](/DataSheets/PCI/pci_23.pdf). The PCI Bridge implements a bidirectional asynchronous FIFO to facilitate data movements between the buses. Each slot is compatable with Universal and 5V PCI devices. All efforts are made to align implemented PCI features completely with the PCI Local Bus Revision 2.3. There are no undocumented PCI commands. Each slot is capable of supporting Amiga specific devices. The AmigaPCI supports true DMA, with each PCI device having total access to all PCI and Amiga address spaces.

## CPU Local Bus
The AmigaPCI main board has no CPU or fast ram. Instead, the CPU Local Bus port supports CPUs and AUTOCONFIG devices. This approach allows fast RAM and other AUTOCONFIG devices be optimized for the clock speed and capabilities of the CPU device implemented. The CPU local bus is discussed further in Section 3.0  of the [AmigaPCI Wiki](https://github.com/AmigaPCI/AmigaPCI-MainBoard/wiki/3.0-Local-Bus-Port).

<p align="center"><img src="/Images/CPULocalBus-30.jpg" width="425"></p>

## Amiga Custom Chips  
The AmigaPCI must be populated with the Amiga OCS or ECS custom chips. See Section 1.0 of the [AmigaPCI Wiki](https://github.com/AmigaPCI/AmigaPCI-MainBoard/wiki/1.0-AmigaPCI-Hardware-Guide) for more information.

## Kickstart ROM  
Kickstart ROM version 3.2 or greater for the Amiga 1200 should be burned to 27C4096 EPROMs (DIP-40 footprint) for use by the AmigaPCI. Original Commodore Amiga Kickstart ROMs are not supported. 

## STM32F205 Microcontroller
The STM32F205 microcontroller supplies several functions to the AmigaPCI.

### HID
The AmigaPCI support human interface devices (HID) via the two USB ports. The mouse HID signals are shared with the JOY1 port (see Mouse and Joystick) via buffers. When there is active input from the HID mouse, the buffers are switched to only allow input from the HID port. When the HID mouse is not in active use, the buffers switch to allow input from JOY1. With this method, input from only one device is allowed at any time, with the mouse HID having priority.

### I2C
An internal I2C header is present on the AmigaPCI board as well as at the Local Bus Card.

### Real Time Clock
The STM32F205 emulates the capabilities of the xxxx real time clock chip. The clock is timed by an external 32.xxxkhz crystal and can be fine tuned by a variable capacitot.

### Voltage Monitors
All voltages can be monitored by reading registers from the real time clock address space.

### Internal temperature
The internal fan header RPM is controlled by a PWM signal.

## Audio  
The audio output is generated by Paula and run through the filter circuit as in the Amiga 4000. The audio output is supplied from a line level 3.5mm stereo jack. A CD audio header is included to support the input of analog line-level audio from optical drives or other devices. It is a 4-pin 2.54 pitch connector in the RGGL footprint, with pin 1 = R. This may be installed as a standard 4-pin male header or TE Connectivity part 5-103639-3, which is the MPC-2 locking header that has become ubiquitous.

## Video  
The 15KHz standard Amiga video is output via an HD15 connector. This allows easy connection to converter boxes or any monitors that support the 15KHz standard. This connector only includes the signals needed for video output. Other signals present on the orignal Amiga video port are not included.

## Mouse and Joystick
There are two legacy DB9 joystick port headers on the board. JOY1 is shared with the HID mouse input. In order to prevent signal contention with the HID mouse, the inputs from JOY1 are disconnected when the HID mouse is actively used. This prevents undesired behavior and allows only one device at a time to input signals, with the HID device having priority. See [HID](#hid). The input of JOY2 is not shared with other ports. 

## Serial  
The serial port is a male DB25 connector, which is stacked with the parallel female DB25 connector. The serial port is completely compatable with Amiga peripherals designed for the Amiga 500, 600, 1200, 2000, 3000, and 4000.

## Parallel  
The parallel port is a female DB25 connector, which is stacked with the serial male DB25 connector. The parallel port is completely compatable with legacy Amiga devices.

## Floppy Disk Drive  
The floppy disk interface is the primary way Amiga based computers store and retrieve external data. The AmigaPCI includes a header that supports two internal double density floppy disk drives.

In addition to supporting original Amiga floppy disk drives, the AmigaPCI supports PC floppy disk drives with double density floppies. An adaptation of Ian Steadman's [PC floppy interface](https://github.com/istedman/Floppy_adaptor) is implemented. The floppy drive hardware type (Amiga or PC) is set by jumper.

>[!NOTE]
>You must use either Amiga disk drives or PC disk drives. Do not mix the two types.  

## ATA  
The AmigaPCI includes a dual-port host terminated ATA device interface using [lide.device](https://github.com/LIV2/lide.device).

## Video Slot  
The AmigaPCI includes the Amiga OCS/ECS video bus. This allows for the use of OCS/ECS compatable video devices with the AmigaPCI.

# Acknowledgements  
Ian Steadman for his [Amiga PC floppy interface](https://github.com/istedman/Floppy_adaptor) design.

# License
Floppy interface modifications from Ian Steadman (noted in schematic) released under the GNU GENERAL PUBLIC LICENSE, Version 3.

<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/"><a property="dct:title" rel="cc:attributionURL" href="https://github.com/jasonsbeer/AmigaPCI">AmigaPCI</a> by <a rel="cc:attributionURL dct:creator" property="cc:attributionName" href="https://github.com/jasonsbeer">Jason Neus</a> is licensed under <a href="https://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Creative Commons Attribution-NonCommercial 4.0 International<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1" alt=""></a></p>

**Last Update: 04-NOV-2026**
