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
</br>

**Revision History**  
Revision|Date|Status
-|-|-
0.0|xx|FIRST DRAFT
</br>
<p xmlns:cc="http://creativecommons.org/ns#" xmlns:dct="http://purl.org/dc/terms/"><a property="dct:title" rel="cc:attributionURL" href="https://github.com/jasonsbeer/AmigaPCI">AmigaPCI PCI Hardware Developer Reference</a> by <a rel="cc:attributionURL dct:creator" property="cc:attributionName" href="https://github.com/jasonsbeer">Jason Neus</a> is licensed under <a href="https://creativecommons.org/licenses/by-nc/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">Creative Commons Attribution-NonCommercial 4.0 International<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1" alt=""><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/nc.svg?ref=chooser-v1" alt=""></a></p>

---

# 1.0 PCI Bus

The PCI Local Bus (PCI, herein) is a processor independent, 32-bit expasion bus. The AmigaPCI specification is designed to comply with the PCI Local Bus Revision 2.3 specificiation. Each slot supports Universal and 5V cards, as defined in the PCI Local Bus Revision 2.3 specification. Like Zorro 2 and Zorro 3, PCI supports auto configuration of devices on power up. This allows for the use of Amiga AUTOCONFIG to configure devices at start up. This fits well with Amiga OS as PCI devices can be configured as Zorro 3 devices, which function natively with Amiga OS. 

The PCI Bridge is implemented via a Motorola MC68040/MC68060 to PCI Bridge (Local PCI Bridge, herein). The Local PCI Bridge logic translates data requests from the Motorola processor and PCI devices in order that they may communicate. This specification is compatable with Motorola MC68040 and newer predecessors. While this document is written with the Motorola MC68040 in mind, the information can be applied to newer Motorola processors, such as the MC68060.

Each PCI slot on the PCI Local Bridge can operate in either AUTOCONFIG mode or Prometheus mode, but not both simultaneously. 

## 1.1 Endianness

Motorola MC68000 series processors are big endian devices. PCI devices, by contrast, are little endian devices. This means we must byte swap the data signals to provide compatability between devices with different endianness*. The AmigaPCI specification implements address invariance to achieve the endian conversion necessary for the CPU and PCI devices to communicate.

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

Each PCI slot has four interrupt signals, identified as **_INTA**, **_INTB**, **_INTC**, and **_INTD**. Single function PCI devices are only allowed to use **_INTA**. The remaining signals are used in the event of a multifunction PCI device, with one interrupt line per PCI function. As a hyptothetical example, a multifunction I/O device may use **_INTA** for a floppy drive interface, **_INTB** for a hard drive interface, **_INTC** for a serial interface, etc. For the purposes of the AmigaPCI design, **_INTA**, **_INTB**, **_INTC**, and **_INTD** are OR'd together and connected to **_INT2**. Drivers are expected to look for assertion of **_INT2** to signal an interrupt request from devices on the PCI bus. When an interrupt is asserted, the driver needs to poll its device on the PCI bus to determine if its device is asserting the interrupt. The Local PCI Bridge will continue to assert **_INT2** until all PCI devices have negated their interrupt requests. 

## 1.3 Modes of Operation

Amiga PCI slots can operate in AUTOCONFIG mode or Prometheus compatable mode. Each individual PCI slot may operate in one of these modes, but never both simultaneously.

In AUTOCONFIG mode, the PCI target device will be configured on startup like any Amiga AUTOCONFIG device. The advantage of AUTOCONFIG mode is the ability to use a PCI device upon startup without the need to load drivers from disk. This supports devices such as auto booting hard drives, video, sound cards, etc. Once the PCI target device is configured by the AUTOCONFIG process, the target device may be directly accessed by its base address(es). 

Prometheus mode requires the PCI target device be configured in software in order to function. This mode can support PCI target devices not designed for the Amiga. During startup, the Local PCI Bridge is configured via AUTOCONFIG in the 32-bit Zorro 3 address space, which will supply a base address for the Local PCI Bridge through which the slots in Prometheus mode may be accessed. Driver software may then poll the Local PCI Bridge base address with each device selection bit. The Local PCI bridge will return 0xFFFF FFFF if an AUTOCONFIG slot is polled via the Local PCI Bridge base address. 

## 1.4 Developing PCI Cards for the AmigaPCI and Upgrade Path

New PCI hardware developed specifically for the AmigaPCI should be based on specifications for the Universal* PCI card. Should demand justify it, future upgrade options may include the move to a 3.3V signaling environment capable of running at 66MHz**. Plug in hardware based on the Universal concept will permit cards to work in either 5V or 3.3V signaling environments. In addition, any hardware developed for the AmigaPCI must limit address spaces to Memory and Configuration only. The I/O address space is not recommended for new hardware development*** and is not supported by the AmigaPCI with AUTOCONFIG devices.  

*PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 4.1.1. Transition Road Map. pp. 113.  
**PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 7.6.3. Signaling Environment. pp. 230.  
***PCI Local Bus Specification Revision 2.3. PCI Special Interest Group. Section 3.2.2. Addressing. pp. 27.  

# 2.0 PCI Configuration

Each PCI target device may be configured by the Amiga AUTOCONFIG process or by software configuration (Prometheus). During configuration, each PCI slot in turn, is polled to obtain the capabilities and address space needs of the target device.

## 2.1 Local PCI Bridge

The host bridge base address is $8000 0000. The base address allows direct access of the host bridge configuration registers and a means to access the configuration spaces of PCI cards on the PCI bus (See 2.3  Prometheus Configuration). All PCI devices are accessed through the host bridge, which acts as an interface between devices on the CPU bus and devices on the PCI bus. The host bridge also handles bus arbitration. During each CPU data transfer cycle, the address information is broadcast by the host bridge to the PCI bus. If any devices respond by asserting **_DEVSEL**, the host bridge proceeds with the PCI cycle. Otherwise, the host bridge returns to an idle state.

## 2.2 AUTOCONFIG

PCI cards with Amiga option ROMs will be configured via the AUTOCONFIG process at startup. AUTOCONFIG capable PCI devices will be configured by the in the 32-bit memory expansion space range. In order to complete the AUTOCONFIG process, all AUTOCONFIG capable PCI devices must inclue a ROM or psuedo-ROM to support the process. The first 64KB of ROM space is designated as the PCI Data Structure.* To determine the target architecture of the ROM image, the value Code Type must be set. For AmigaOS ROM images, the Code Type at offset 0x14 must be **0x68**. All other values will be ignored.  

Once an AmigaOS option ROM is identified, specifications such as the device manufacturer, product number, device capabilities, etc, are read from the device. Amiga OS will assign a base address to each device on the PCI card. This procedure is then repeated for each PCI device installed. Once complete, each PCI device may be accessed by the assigned base address. PCI target devices configured by the AUTOCONFIG process may only access memory and configuration spaces. Use of the I/O space is not recommended for new PCI designs and is not supported.

> [!NOTE]
> The Code Type value of 0x68 is an unofficial implementation of this register. By selecting a high value, it is expected this will never be officially assigned and should be safe far into the future.  
> AmigaOS AUTOCONFIG 8-bit Product IDs, so the Device ID field must consider this.  
> AmigaOS AUTOCONFIG supports 16-bit Vendor IDs, which is the same as PCI.  

## 2.3 Accessing Devices on the PCI Bus

Table 2.3 PCI Host Bridge Memory Map
Starting Address|Ending Address|Description
-|-|-
$8000 0000|$9FBF FFFF|Memory Expansion Space
$9FC0 0000|$9FC0 7FFF|Reserved
$9FC0 8000|$9FC0 8FFF|Host Bridge Type 0 Configuration Space
$9FC1 0000|$9FC1 FFFF|PCI Slot 0 Type 0 Configuration Space
$9FC2 0000|$9FC2 FFFF|PCI Slot 1 Type 0 Configuration Space
$9FC3 0000|$9FC3 FFFF|PCI Slot 4 Type 0 Configuration Space
$9FC4 0000|$9FC4 FFFF|PCI Slot 2 Type 0 Configuration Space
$9FC8 0000|$9FC8 FFFF|PCI Slot 3 Type 0 Configuration Space
$9FC9 0000|$9FD0 FFFF|Reserved
$9FD1 0000|$9FDF FFFF|Type 1 Configuration Space
$9FE0 0000|$9FFF FFFF|I/O Expansion Space

### 2.3.1 Memory Space Access

### 2.3.2 Type 0 Configuration Access

Accesses to each device on the PCI bus is possible by implementing the correct offset from the base address. Some examples are below.

Table 2.3.2a Configuration Space Access
Address Bits|Description
-|-
31:20|Type 0 configuration space.
19:15|Device to Access. See Table 2.3.2b.
14:11|Reserved. Should be 0x0.
10:8|Value identifying the function ID of target slot.
7:2|Configuration Register Offset.
1:0|Port Size

Table 2.3.2b Device Access
A[19:15] Binary|Result
-|-
00001|Host bridge.
00010|PCI Slot 0 _IDSEL.
00100|PCI Slot 1 _IDSEL.
01000|PCI Slot 2 _IDSEL.
10000|PCI Slot 3 _IDSEL.
00011|PCI Slot 4 _IDSEL.

Table 2.3.2c Access Examples
Address|Read/Write|Result
-|-|-
$9FC0 8000|Read|Returns register 0x0 from the host bridge.
$9FC4 0000|Read|Returns register 0x0 from PCI device 0 on slot 2.
$9FC3 0000|Read|Returns register 0x0 from PCI device 0 on slot 4.

Table 2.3.2d Host Bridge CONFIG0 Registers.  
<table>
    <thead>
      <td colspan=8><p align="center">Data Bits</p></td><td></td>
    </thead>
    <tbody>
    <tr>
    <td width="70px">31</td><td width="70px"></td><td width="70px"></td><td width="70px"><p align="right">16</p></td>
      <td  width="70px">15</td><td width="70px"></td><td width="70px"></td><td width="70px"><p align="right">0</p></td>
      <td width="60px"><p align="center">Offset</p></td>
      </tr>
      <tr>
        <td><p align="center">Prometheus Control</p></td><td colspan=3><p align="center">Device ID</p></td><td colspan=4><p align="center">Vendor ID</p></td><td><p align="center">0x0</p></td>
      </tr>
      <tr>
        <td colspan=4><p align="center">Status</p></td><td colspan=4><p align="center">Command</p></td><td><p align="center">0x4</p></td>
      </tr>
      <tr>
        <td colspan=6><p align="center">Class Code</p></td><td colspan=2><p align="center">Revision ID</p></td><td><p align="center">0x8</p></td>      
      </tr>
    </tbody>
</table>

### 2.3.3 Type 1 Configuration Access

### 2.3.4 I/O Space Access


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

During DMA cycles, the cycle is directed by the initiating PCI device. The Local PCI Bridge is responsible for driving MC68040 compatable signals on the CPU bus to support the current cycle. These signals are **_TS**, **_TIP**, **R_W**, **TT0**, **TT1**, **SIZ0**, **SIZ1**, **A[31..0]**, and **D[0..31]** (write cycle only). When not actively driving a DMA cycle on the CPU bus, these Local Bridge holds these signals in a high impedence state. The Local PCI Bridge must respond to the assertion of **_TA** in order to recognize when data is placed on **D[0..31]** for read cycles, or when data has been latched by the target device for write cycles. Unless actively driving a DMA cycle against onboard AmigaPCI resources, **AD[31..0]**, **_TRDY**, **_DEVSEL** must be held in a high impedence state by the Local PCI Bridge during DMA cycles.

#### 3.2.1.1 Transfer Type

The Local PCI Bridge will assert **TT0** and **TT1**, as required, in response to a normal or burst transfer request from the PCI initiating device. The assertion of transfer type (**TT0** and **TT1**) is determined by whether **_FRAME** is held asserted after the address phase of the current cycle. If **_FRAME** is negated on the first rising PCI clock edge after the address phase, this is a normal cycle. If **_FRAME** is held asserted on the first rising PCI clock edge after the address phase, this is a burst cycle. This means the Local PCI Bridge cannot set **TT0** and **TT1** until the first falling BCLK edge after the first rising PCLK edge after the cycle address phase.

#### 3.2.1.2 Bus Synchronization

It must be considered that the PCI bus clock and the MC68040 bus clocks are asynchronous. If not handled correctly, this can lead to a condition where the devices become out of sync. This will result in data transfer errors. While PCI initiator devices may, or may not, insert wait states, we must consider this possiblity as wait states are defined in the PCI specification for all cycle types. Synchronozation of the bus clocks is acheived by the PCI Local Bridge implementing a FIFO approach. Data is latched into a register in one clock domain and passed out to the other clock domain at the appropriate timings.

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


**END**
