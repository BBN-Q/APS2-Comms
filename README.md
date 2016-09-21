# APS2-Comms

HDL modules for Etherent communications with APS2 and TDM modules.

## Dependencies

1. [VHDL-Components](https://github.com/BBN-Q/VHDL-Components) for clock crossing synchronizer
2. [verilog-axis](https://github.com/alexforencich/verilog-axis) for AXI stream FIFOs, muxes and demuxes.
3. [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) for an ethernet MAC.
4. [Comblock 5402](http://comblock.com/com5402soft.html) for IP server stack - UDP/TCP/DHCP/ARP/PING.
5. [Xilinx Ethernet 1G/2.5G BASE-X PCS/PMA or SGMII](https://www.xilinx.com/products/intellectual-property/do-di-gmiito1gbsxpcs.html) for the PCS/PMA layer.

## License

BBN source files are licensed under the Mozilla Public License 2.0.  Dependencies
listed above carry their own licenses.
