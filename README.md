# APB-interfaced-SPI-Master-IP-core-hardware-RTL-Design
This project is an RTL design of an SPI (Serial Peripheral Interface) master controller with an AMBA APB slave interface, written in Verilog. It lets a processor or bus master configure and run SPI transfers by reading and writing memory-mapped registers over APB.
# SPI Baud Rate Generator

Verilog RTL for the SPI master baud rate generator. It generates SCLK
(PCLK / divisor) and the MISO sample and MOSI shift pulses for all four
CPOL/CPHA modes.

Divisor = (SPPR + 1) x 2^(SPR + 1)

## Files
- rtl/baudrategenerator.v : design
- tb/baudrategenerator_tb.v : testbench
- docs/ : design notes, mistakes log, waveforms

## Simulation
Tool: ModelSim Intel FPGA Starter Edition 2020.1

## Status
Verified: modes (0,0) and (0,1), divisor 8.
To do: modes (1,0) and (1,1), other divisors, ss_i and spiswai_i cases.
