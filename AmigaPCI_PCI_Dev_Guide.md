<p align="center"><img src="/Images/AmigaPCI-logo-dark.png"></p>

<h1 align="center">PCI Hardware Developer Reference</h1>

<p align="center">"If I have seen further, it is by standing on the shoulders of giants."<br>-Sir Isaac Newton</p>

**Disclaimer**

This document defines how the PCI Local Bus Rev. 2.3 specification is implemented in the AmigaPCI. It is not a substitute for the PCI Local Bus Specification or relevant Motorola user manuals. It is expected the reader has reviewed and understands the tenants of the PCI Bus as defined in the PCI Local Bus Specification, Rev 2.3, and the relevant Motorola user manuals.

This document is a work in progress and is presented "as-is" with no waranty expressed or implied.

<p align="center"><b>**THIS DOCUMENT IS A WORK IN PROGRESS AND IS SUBJECT TO CHANGE WITHOUT NOTICE.**</b></p>

**Conventions**

1) Signals are presented as bold font, such as **_FRAME** or **_TA**.
2) A leading underscore (**_**) indicates a signal is active low.
3) Examples of bus data are italicized, such as *DATA0* or *ADDRESS1*.  
4) Hex values are presented with a leading 0x and a space inserted every 4 characters for clarity.
5) AmigaPCI refers to this specification or any implementation of this specification, in part or whole.
6) CPU refers to the Motorola MC68040 or MC68060 processor, unless otherwise specified.  

**Revision History**  
Revision|Date|Status
-|-|-
0.0|xx|FIRST DRAFT
</br>
<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/"><a property="dct:title" rel="cc:attributionURL" href="https://github.com/jasonsbeer/AmigaPCI">AmigaPCI PCI Hardware Developer Reference</a> by <a rel="cc:attributionURL dct:creator" property="cc:attributionName" href="https://github.com/jasonsbeer">Jason Neus</a> is licensed under <a href="https://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Creative Commons Attribution-NonCommercial 4.0 International<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1" alt=""></a></p>

---

# 1.0 PCI Bus

The PCI Local Bus (PCI, herein) is a processor independent, 32-bit expasion bus. The AmigaPCI specification is designed to comply with the PCI Local Bus Revision 2.3 specificiation. Each slot supports Universal and 5V cards, as defined in the PCI Local Bus Revision 2.3 specification. Like Zorro 2 and Zorro 3, PCI supports auto configuration of devices on power up. This allows for the use of an Amiga AUTOCONFIG-like appraoch to configure devices at start up.

The PCI Bridge is implemented via a Motorola MC68040/MC68060 to PCI Bridge (Local PCI Bridge, herein). The Local PCI Bridge logic translates data requests from the Motorola processor and PCI devices in order that they may communicate. This specification is compatable with Motorola MC68000 series processors. While this document is written with the Motorola MC68040 in mind, the information can be applied to other Motorola processors, such as the MC68060.

## 1.1 Endianness

Motorola MC68000 series processors are big endian devices. PCI devices, by contrast, are little endian devices. This means the data bus must be byte swapped to provide compatability between devices with different endianness*. The AmigaPCI specification implements an address invariance system with byte swapping to achieve the endian conversion necessary for the CPU and PCI devices to communicate.

Table 1.1a. Order of byte consumption in big and little endian devices.
Endianess|Hex Value<br />Order of Consumption
-|-
&nbsp;|0x0002 0804
Big| START---->
Little| <----START

The smallest unit of data considered by the PCI specification is one byte. With this consideration, data bytes are swapped to accomodate the conversion in endianess. This byte swapping is implemented in the AmigaPCI Local PCI Bridge hardware.

Table 1.1b. Byte swapping between big and little endian devices.
Endianess|Hex Value|Address 0x00|Address 0x01|Address 0x02|Address 0x03
-|-|-|-|-|-
Big|0x0002 0804|0x00|0x02|0x08|0x04
Little|0x0408 0200|0x04|0x08|0x02|0x00

*Application Note AN2285. Data Movement Between Big-Endian and Little-Endian Devices. Rev 2.2. Freescale Semiconductor. 2008

## 1.2 Interrupt Handling

Each PCI slot has four interrupt signals, identified as **_INTA**, **_INTB**, **_INTC**, and **_INTD**. Single function PCI devices are only allowed to use **_INTA**. The remaining signals are used in the event of a multifunction PCI device, with one interrupt line per PCI function. As a hyptothetical example, a multifunction I/O device may use **_INTA** for a floppy drive interface, **_INTB** for a hard drive interface, **_INTC** for a serial interface, etc. For the purposes of the AmigaPCI design, **_INTA**, **_INTB**, **_INTC**, and **_INTD** are OR'd together and connected to the Amiga's **_INT2**. Drivers are expected to look for assertion of **_INT2** to signal an interrupt request from devices on the PCI bus. When an interrupt is asserted, the driver needs to poll its device on the PCI bus to determine if its device is asserting the interrupt. The Local PCI Bridge will continue to assert **_INT2** until all PCI devices have negated their interrupt requests. 

## 1.3 Modes of Operation

Amiga PCI slots can operate in an AUTOCONFIG-like mode or Prometheus compatable mode. Each individual PCI slot may operate in one of these modes, but not both simultaneously.

In AUTOCONFIG mode, the PCI target device will be configured on startup like any Amiga AUTOCONFIG device. The advantage of AUTOCONFIG mode is the ability to use a PCI device upon startup without the need to load drivers from disk. This supports devices such as auto booting hard drives, video, sound cards, etc. Once the PCI target device is configured by the AUTOCONFIG-like process, the target device may be directly accessed by its base address(es). 

Prometheus mode requires the PCI target device be configured in software in order to function.

## 1.4 Developing PCI Cards for the AmigaPCI and Upgrade Path

Hardware developed specifically for the AmigaPCI must should limit address spaces to Memory and Configuration only. The I/O address space is not recommended for new hardware development*. The most likely next step in developing the AmigaPCI concept will be to implement a PCI-Express bus interface.  

*PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 4.1.1. Transition Road Map. pp. 113.  

# 2.0 PCI Configuration

Each PCI target device may be configured by an AUTOCONFIG-like process or by software configuration. During configuration each traget PCI slot is polled to obtain the capabilities and address space needs of the target device(s) present.

## 2.1 PCI Host Bridge

The host bridge base address is $8000 0000. All PCI devices may be accessed through the host bridge, which acts as an interface between devices on the CPU bus and devices on the PCI bus. The host bridge also handles bus arbitration. During each CPU data transfer cycle, the address information is broadcast by the host bridge to the PCI bus. If any devices respond by asserting **_DEVSEL**, the host bridge proceeds with the PCI cycle. Otherwise, the host bridge returns to an idle state.

## 2.2 Accessing Devices on the PCI Bus

The AmigaPCI uses the addressing scheme shown below for accessing the parallel address spaces of each PCI device. The address spaces are as follows: Memory space, I/O space, Type 0 Config space, and Type 1 Config space. The following sections describe how to access each of these spaces on the AmigaPCI.

Table 2.2 PCI Host Bridge Memory Map
Starting Address|Ending Address|Description
-|-|-
$8000 0000|$9FBF FFFF|Memory Expansion Space
$9FC0 0000|$9FC0 FFFF|Bridge Register Space
$9FC1 0000|$9FC8 FFFF|Type 0 Configuration Space
$9FC9 0000|$9FD0 FFFF|Reserved
$9FD1 0000|$9FDF FFFF|Type 1 Configuration Space
$9FE0 0000|$9FFF FFFF|I/O Expansion Space
$A000 0000|$BFFF FFFF|Memory Cache Line Expansion Space

### 2.2.1 PCI Memory Expansion Spaces
There are two memory expansion spaces available to the PCI bus. The space a device is assigned to is determined by whether the PCI device supports cache line burst transfers. When a PCI device is configured, it may be placed in either space, but not both simultaneously. The memory space assigned will dictate the PCI bus commands issued during data transfer cycles.  

#### 2.2.1.1 Memory Expansion Space
Memory Read and Memory Write commands are posted to the PCI bus in this space. If an attempted cache burst transfer is initiated by the CPU, the cycle will be terminated with assertion of transfer burst inhibit. Devices not supporting cache line transfers should be placed in this space.  

#### 2.2.1.2 Memory Cache Line Expansion Space
Memory Read, Memory Write, Memory Read Line, and Memory Write and Invalidate commands are posted to the PCI bus in this space. The exact PCI bus command will be determined by the current CPU cycle type. Devices supporting cache line transfers should be placed in this space.  

### 2.2.2 I/O Space

Two megabytes of space is available for I/O devices. In this space, only I/O read and I/O write commands are posted to the PCI bus. I/O devices are not recommended for new designs. Address bits AD[31:20] on the PCI bus are set to $0 during an I/O space access.

### 2.2.3 PCI Type 0 Configuration Access

The Type 0 configuration space of each device on the PCI bus can be accessed by probing the correct address. The addressing scheme is described below. The data bit order shown in the tables is aligned to big endian accesses from the CPU. The host bridge automatically byte swaps the data bus in both directions. Thus, any data on the CPU side of the bridge will be in big endian order. Conversely, any data on the PCI side of the bus is in little endian order. Becuase of the byte swapping, it is critical to consider how the data will be presented when referencing tables in the PCI specifications. Address translation that may be required is implemented by the host bridge. For example, AD[1:0] must be $0 for accesses to the Type 0 Configuration space. To support this, the host bridge automatically sets AD[1:0] = $0 during this access type. In addition, AD[31:20] are set to $0.

Table 2.2.3a Type 0 Configuration Space Access.
CPU Address Bus Bits|Description
-|-
31:20|Type 0 configuration space ($9FC).
19:16|Slot to Access. See Table 2.2.3b.
15:11|Reserved. Should be $0.
10:8|Value identifying the function ID of target slot.
7:2|Configuration Register Offset.
1:0|Byte start address. Defined by CPU.

Table 2.2.3b Device Access
A[19:16] Binary|Result
-|-
0001|PCI Slot 0 _IDSEL.
0010|PCI Slot 1 _IDSEL.
0100|PCI Slot 2 _IDSEL.
1000|PCI Slot 3 _IDSEL.
0011|PCI Slot 4 _IDSEL.

Table 2.2.3c Access Examples
CPU Address Bus|Read/Write|Result
-|-|-
$9FC0 8000|Read|Returns register 0x0 from the host bridge.
$9FC4 0000|Read|Returns register 0x0 from PCI device 0 on slot 2.
$9FC3 0000|Read|Returns register 0x0 from PCI device 0 on slot 4.
$9FC3 000C|Read|Returns register 0xC from PCI device 0 on slot 4.
$9FC1 0100|Read|Returns register 0x0 from PCI device 1 on slot 1.
$9FC1 0200|Read|Returns register 0x0 from PCI device 2 on slot 1.
$9FC0 8004|Write|Writes to register 0x4 of the host bridge.

### 2.2.4 Type 1 Configuration Access

The Type 1 configuration space of each device on the PCI bus can be accessed by probing the correct address. Up to 14 additional buses can be supported using the addressing scheme described below. Bus 0 is reserved for the system host bridge. The host bridge automatically byte swaps the data bus in both directions. Thus, any data on the CPU side of the bridge will be in big endian order. Conversely, any data on the PCI side of the bus is in little endian order. Becuase of the byte swapping, it is critical to consider how the data will be presented when referencing tables in the PCI specifications. Address translation that may be required is implemented by the host bridge. For example, AD[1:0) must be $1 for accesses to the Type 1 Configuration space. To support this, the host bridge automatically sets AD[1:0] = $1 during this access type. In addition, AD[31:20] is set to $0.  

Table 2.2.4a Type 1 Configuration Space Access
CPU Address Bus|Description
-|-
31:20|Type 1 configuration space ($9FD).
19:16|Bus number ($1 - $FF)
15:11|Target slot on the target bus.
10:8|Value identifying the function ID of target slot.
7:2|Configuration Register Offset.
1:0|Byte start address. Defined by CPU.

## 2.3 AmigaOS Option ROM Cards

PCI cards with AmigaOS ROMs will be configured via an AUTOCONFIG-like process at startup. In order to complete the configuration process, the PCI devices must inclue a ROM or psuedo-ROM to supply the necessary information. The first 64KB of ROM space is designated as the PCI Data Structure. To determine the target architecture of the ROM image, the value **Code Type** must be set. For AmigaOS ROM images, the Code Type at offset **0x14** must be **0x68**. All other values will be ignored.  

Once an AmigaOS ROM is identified, specifications such as the device manufacturer, product number, device capabilities, etc, are read from the device. AmigaOS will assign a base address to each device on the PCI card. This procedure is then repeated for each PCI device installed. Once complete, each PCI device may be accessed by the assigned base address.

# 3.0 Data Transfer Cycles and Bus Mastering

Direct bus* access is available to the CPU and PCI devices via bus mastering. When a device has mastered the bus, it has control of the entire AmigaPCI system and may directly access any valid address location. This is typically done for direct reading and writing of memory (DMA) or direct control of chipset or other functions. The AmigaPCI bus arbiter accepts bus requests from the CPU and each device on the PCI bus. Each slot on the PCI bus has a dedicated bus request signal. The bus arbiter implements a fairness protocol to prevent a single device from owning the bus for extended lengths of time. When there is no pending bus request, the CPU is given implicit ownership of the bus (**_BG** is asserted with **_BB** held in a high impedence state) until it the CPU begins a bus cycle or a bus request from a PCI device is granted. 

*In this discussion, "bus" is a term for the data, address, and AD buses, collectively, of the Amiga.

## 3.1 CPU as a Bus Driver

Unlike previous Motorola MC68000 series processors, the Motorola MC68040 does not preferentially own the bus. It is considered for bus access with all other bus mastering devices on the system. Thus, bus arbitration includes consideration for the CPU when assigning bus ownership. When it is ready to take ownership of the system bus the CPU will assert **_BR** (bus request) to indicate its need to own the system bus. When there are no current bus cycles in progress, the arbiter will assert **_BG** (bus grant) in response so that the CPU may begin its bus activities. Once **_BG** is asserted by the arbiter, the CPU will assert **_BB** (bus busy) to indicate ownership of the bus. **_BG** is asserted until the CPU bus access is complete, indicated by negation of **_BR**. While posessing explicit ownership of the bus, the CPU may start a bus cycle at any time by asserting **_BB**. The CPU is granted implicit ownership of the bus when no other device is requesting, or has been granted, bus ownership. During implicit ownership of the bus, the CPU leaves the bus in an undefined state, while **_BG** is asserted, **_BR** is negated, and **_BB** is tri-state.

### 3.1.1 CPU Driven Data Transfer Cycle

CPU access to PCI target devices supports burst (MOVE16) and non-burst (normal) cycles in read and write modes. The PCI and CPU busses operate at different clock rates. This raises concerns about metastability and honoring setup and hold times for data transfers. In order to account for these concerns, the AmigaPCI Local Bridge implements a FIFO approach. FIFO allows clock domain crossing supporting the quickest release of the CPU, shortening cycle times.

When a data transfer cycle is initiated by the CPU, the Local PCI Bridge broadcasts the address and related bus command to the PCI bus. If a target device responds by asserting **_DEVSEL** within two PCI clock cycles, the Local PCI Bridge completes the transfer. If no device asserts **_DEVSEL** by the second falling edge of the PCI clock, the Local PCI Bridge returns to an idle state. See Master Terminated, Section 8.2.

### 3.1.2 Normal Mode Cycles

A normal mode transfer is capable of moving byte, word, or long word data. The data size to be transfered is determined from **A[1..0]** and the **SIZ0** and **SIZ1** CPU signals. That information is used to drive the correct byte enables on **C/BE[3..0]** during the data transfer.

### 3.1.3 Burst Mode Cycles

A burst mode is defined as a line transfer initiated by the CPU with the MOVE16 instruction*. This results in the burst transfer of four long words to or from the target device. Each long word being aligned to a 16-byte memory boundary. During CPU initiated burst transfers, all four bytes are enabled. The PCI target device must internally increment **A3** and **A2** of the supplied address for each transfer, causing the address to wrap around at the end of the block. This is consistent with the Cacheline Wrap Mode burst order defined in the PCI specifications**.

*Motorola MC68040 User Manual. Motorola. Sections 7.4.2 Line Read Transfer and 7.4.4 Line Write Transfers.
**PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Table 3-2. Burst Ordering Encoding. pp. 29.

## 3.2 PCI Device as a Bus Driver (DMA)

A DMA cycle is defined as a PCI device taking control of the system bus of the AmigaPCI during normal bus arbritration. The PCI device owning the bus may access any valid address space of the AmigaPCI, including other devices on the PCI bus. When accessing memory spaces of the AmigaPCI, only memory space PCI commands are allowed.

### 3.2.1 PCI Driven Data Transfer Cycle (DMA)

When a PCI device wants to take ownership of the system bus, it will assert **_REQx**, where x is the slot designation of the device. Once the arbiter has granted the bus to the requesting PCI device, the arbiter will assert **_GNTx** and **_BB** to indicate a bus operation is in progress, allowing the requesting PCI device to take ownership of the bus and begin the data transfer cycle. The PCI device should never start a DMA cycle until it has been granted exclusive bus access by assertion of the relevant **_GNTx** signal. **_BB** will remain asserted while either the PCI bus or CPU bus remains active in the current cycle.

During DMA cycles, the cycle is directed by the initiating PCI device. The Local PCI Bridge is responsible for driving MC68040 compatable signals on the CPU bus to support the current cycle. These signals are **_TS**, **_TIP**, **R_W**, **TT0**, **TT1**, **SIZ0**, **SIZ1**, **A[31..0]**, and **D[31..0]** (write cycle only). When not actively driving a DMA cycle on the CPU bus, these Local Bridge holds these signals in a high impedence state. The Local PCI Bridge must respond to the assertion of **_TA** in order to recognize when data is placed on **D[31..0]** for read cycles, or when data has been latched by the target device for write cycles. Unless actively driving a DMA cycle against onboard AmigaPCI resources, **AD[31..0]**, **_TRDY**, **_DEVSEL** must be held in a high impedence state by the Local PCI Bridge during DMA cycles.

## 3.3 Cycle Termination

The PCI cycle can end in several ways and may be terminated by the Local PCI Bridge or target device.

### 3.3.1 Master Terminated - Completion

This condition is asserted when the master device has completed the intended transaction without error. This terminiation condition is signaled by negating **_FRAME** while **_IRDY** is asserted.

### 3.3.2 Master Terminated - Abort

This condition exists when no target device responds to the address phase of a PCI cycle. Normally, a PCI Target Device will claim the cycle by asserting the **_DEVSEL** signal in response to the address phase of the cycle. If no device claims the cycle, it is assumed to be the absence of a target device with a matching base address, rather than a bus error. The Local PCI Bridge will return to an idle state. No signals are asserted in response to this condition.

### 3.3.3 Target Terminated - Retry

This condition is signaled when the target device asserts **_STOP** after claiming the cycle, by asserting **_DEVSEL**, before data has been transfered. When the target device asserts the retry condition, the Local PCI Bridge will assert **_TA** and **_TEA** together, which signals the CPU to immediately abort and retry the cycle.

### 3.3.4 Target Terminated - Disconnect

This condition is signaled when the target device asserts **_STOP** while **_TRDY** is asserted. The Disconnect condition is different from the Retry condition in that Disconnect is asserted after some data has already been transfered, but the target device is unable to continue transferring the requested data. When this condition exists, the Local PCI Bridge will assert **_TEA**. This indicates to the CPU that an error condition exists and the cycle cannot continue. This condition can only exist for burst cycles.

### 3.3.5 Target Terminated - Abort

This condition can exist any time after a target device has asserted **_DEVSEL** and is signaled when the target device asserts **_STOP** and negates **_DEVSEL** simultaneously. This is considered an abnormal termination in that the target device will never be able to supply to requested data. When this condition exists, the Local PCI Bridge will assert **_TEA**. This indicates to the CPU that an error condition exists and the cycle cannot continue. This condition may occur for both burst and normal cycles. This condition is treated the same as the Target Terminated - Disconnect condition by the CPU (Section X.X.X). See Figure X.X.X for example timing.

### 3.3.6 Master Terminated Cycle - Timeout

**Add something here**. This is timeout during DMA situations.

## 3.4 Parity

Data transfer cycle errors are detected using an even parity system. Except for video and HID devices, all PCI devices are required to support parity*. Even parity is generated by the initiating device and **PAR** is valid one clock after the associated address or data block. The target device determines even parity on the data received and compares the calculated value to **PAR**. Even parity is set when the number of set bits on **AD[31..0]**, **C/BE[3..0]**, and **PAR** is an even number. Parity error conditions are expected to be reported through the device driver whenever possible**. The reporting chain of target to bus master to driver to operating system enables recovery options at every level. The information below specifically explains how the Local PCI Bridge of the AmigaPCI handles parity errors.

*PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 3.7.2. Parity Checking. pp. 95.  
**PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 3.7.4. Error Reporting. pp. 95. 

### 3.4.1 Address Parity Errors

An address parity error occurs when a parity mismatch is detected during the address phase of the PCI cycle and is generally considered a fatal condition.  When a target device detects an address parity error, it will set the Detected Parity Error bit (Status register, bit 15). If the Parity Error Response bit is set (Command Register, bit 6), the target device will assert **_PERR**. If the _SERR Enable bit is set (Command Register, bit 8), the System Error Bit is set (Command Register, bit 8). 

When a parity mismatch occurs during the address phase, one of three things can happen:

1) A device, possibly an unintended target, claims the transaction and proceeds as normal.
2) A device, possibly an unintended target, claims the transaction and terminates with a Target-Abort.
3) No target device claims the transaction and the cycle will time out with a Master-Abort.

The Local PCI Bridge considers two back-to-back address parity errors to be a fatal condition. In the event of an address parity error during a CPU driven data transfer cycle, the Local PCI Bridge will request the MC68040 retry the cycle one time. In the case of a second address parity error, if the _SERR Enable bit is set (Command Register, bit 8), the Local PCI Bridge will set the Signaled System Error bit (Status Register, bit 14). This is a signal to drivers that a fatal condition exists within the PCI bus and efforts should be made to save any needed data, cease accessing the PCI bus, and warn the user. Once in a fatal condition, the Local PCI Bridge will return 0xFFFF FFFF for all reads and writes will have no effect. Once set, the Signaled System Error bit will remain set until a system reset.

**Note:** During CPU driven cycles, the PCI device is the target device. During DMA cycles, the Local PCI Bridge or other PCI device is the target device.

### 3.4.2 Data Parity Errors

A data parity error occurs when there is a parity mismatch during the data phase of the cycle. Data parity is calculated on all data blocks except during special cycles. When the target device detects a data parity error, it will set the Detected Parity Error bit (Status register, bit 15). If the Parity Error Response bit is set (Command Register, bit 6), it will assert **_PERR**. In response to the assertion of **_PERR**, the Local PCI Bridge will assert **_INT2** and set the Interrupt Status bit (Status Register, Bit 3), indicating the interrupt is generated from a device on the PCI bus. PCI drivers are expected to respond to this interrupt and poll their device's Parity Error Bit. The driver should clear the interrupt from the device and retry the transfer cycle. If an excessive number of parity errors occur, the driver should attempt to gracefully disconnect (cease using) the device with a user warning. All efforts should be made to save the user session. Failure to do so will likely result in a system crash and possibly lost data.

**Note:** During CPU driven cycles, the PCI device is the target device. During DMA cycles, the Local PCI Bridge or other PCI device is the target device.

# Appendix A Definitions

A = The address bus of the AmigaPCI.  
AD = The portion of the PCI bus where address and data signals are duplexed.
D = The data bus of the AmigaPCI.  

**END**
