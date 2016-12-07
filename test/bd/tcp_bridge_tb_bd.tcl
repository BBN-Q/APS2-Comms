
################################################################
# This is a generated script based on design: tcp_bridge_tb_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2016.3
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source tcp_bridge_tb_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# tcp_bridge

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7a200tfbv676-2
}


# CHANGE DESIGN NAME HERE
set design_name tcp_bridge_tb_bd

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_msg_id "BD_TCL-001" "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_msg_id "BD_TCL-002" "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_msg_id "BD_TCL-003" "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_msg_id "BD_TCL-004" "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_msg_id "BD_TCL-005" "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_msg_id "BD_TCL-114" "ERROR" $errMsg}
   return $nRet
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_msg_id "BD_TCL-100" "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_msg_id "BD_TCL-101" "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set cpld_rx [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 cpld_rx ]
  set cpld_tx [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 cpld_tx ]
  set_property -dict [ list \
CONFIG.HAS_TKEEP {0} \
CONFIG.HAS_TLAST {1} \
CONFIG.HAS_TREADY {1} \
CONFIG.HAS_TSTRB {0} \
CONFIG.LAYERED_METADATA {undef} \
CONFIG.TDATA_NUM_BYTES {4} \
CONFIG.TDEST_WIDTH {0} \
CONFIG.TID_WIDTH {0} \
CONFIG.TUSER_WIDTH {0} \
 ] $cpld_tx
  set tcp_rx [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_rx ]
  set_property -dict [ list \
CONFIG.HAS_TKEEP {0} \
CONFIG.HAS_TLAST {0} \
CONFIG.HAS_TREADY {1} \
CONFIG.HAS_TSTRB {0} \
CONFIG.LAYERED_METADATA {undef} \
CONFIG.TDATA_NUM_BYTES {1} \
CONFIG.TDEST_WIDTH {0} \
CONFIG.TID_WIDTH {0} \
CONFIG.TUSER_WIDTH {0} \
 ] $tcp_rx
  set tcp_tx [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 tcp_tx ]
  set_property -dict [ list \
CONFIG.FREQ_HZ {125000000} \
 ] $tcp_tx

  # Create ports
  set axi_resetn [ create_bd_port -dir I -type rst axi_resetn ]
  set clk [ create_bd_port -dir I -type clk clk ]
  set_property -dict [ list \
CONFIG.ASSOCIATED_BUSIF {cpld_rx:cpld_tx} \
CONFIG.ASSOCIATED_RESET {axi_resetn:rst} \
 ] $clk
  set clk_tcp [ create_bd_port -dir I -type clk clk_tcp ]
  set_property -dict [ list \
CONFIG.ASSOCIATED_BUSIF {tcp_rx:tcp_tx} \
CONFIG.ASSOCIATED_RESET {rst_tcp} \
CONFIG.FREQ_HZ {125000000} \
 ] $clk_tcp
  set mm2s_err [ create_bd_port -dir O mm2s_err ]
  set rst [ create_bd_port -dir I -type rst rst ]
  set_property -dict [ list \
CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $rst
  set rst_tcp [ create_bd_port -dir I -type rst rst_tcp ]
  set_property -dict [ list \
CONFIG.POLARITY {ACTIVE_HIGH} \
 ] $rst_tcp
  set s2mm_err [ create_bd_port -dir O s2mm_err ]

  # Create instance: axi_bram_ctrl_0, and set properties
  set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.0 axi_bram_ctrl_0 ]
  set_property -dict [ list \
CONFIG.SINGLE_PORT_BRAM {1} \
 ] $axi_bram_ctrl_0

  # Create instance: axi_datamover_0, and set properties
  set axi_datamover_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_datamover:5.1 axi_datamover_0 ]

  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [ list \
CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
CONFIG.NUM_MI {1} \
CONFIG.NUM_SI {2} \
 ] $axi_interconnect_0

  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.3 blk_mem_gen_0 ]
  set_property -dict [ list \
CONFIG.use_bram_block {BRAM_Controller} \
 ] $blk_mem_gen_0

  # Need to retain value_src of defaults
  set_property -dict [ list \
CONFIG.use_bram_block.VALUE_SRC {DEFAULT} \
 ] $blk_mem_gen_0

  # Create instance: tcp_bridge_0, and set properties
  set block_name tcp_bridge
  set block_cell_name tcp_bridge_0
  if { [catch {set tcp_bridge_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_msg_id "BD_TCL-105" "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $tcp_bridge_0 eq "" } {
     catch {common::send_msg_id "BD_TCL-106" "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create interface connections
  connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S] [get_bd_intf_pins tcp_bridge_0/MM2S]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_MM2S_STS [get_bd_intf_pins axi_datamover_0/M_AXIS_MM2S_STS] [get_bd_intf_pins tcp_bridge_0/MM2S_STS]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXIS_S2MM_STS [get_bd_intf_pins axi_datamover_0/M_AXIS_S2MM_STS] [get_bd_intf_pins tcp_bridge_0/S2MM_STS]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_MM2S [get_bd_intf_pins axi_datamover_0/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_datamover_0_M_AXI_S2MM [get_bd_intf_pins axi_datamover_0/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_bram_ctrl_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net cpld_tx_1 [get_bd_intf_ports cpld_tx] [get_bd_intf_pins tcp_bridge_0/cpld_tx]
  connect_bd_intf_net -intf_net tcp_bridge_0_MM2S_CMD [get_bd_intf_pins axi_datamover_0/S_AXIS_MM2S_CMD] [get_bd_intf_pins tcp_bridge_0/MM2S_CMD]
  connect_bd_intf_net -intf_net tcp_bridge_0_S2MM [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM] [get_bd_intf_pins tcp_bridge_0/S2MM]
  connect_bd_intf_net -intf_net tcp_bridge_0_S2MM_CMD [get_bd_intf_pins axi_datamover_0/S_AXIS_S2MM_CMD] [get_bd_intf_pins tcp_bridge_0/S2MM_CMD]
  connect_bd_intf_net -intf_net tcp_bridge_0_cpld_rx [get_bd_intf_ports cpld_rx] [get_bd_intf_pins tcp_bridge_0/cpld_rx]
  connect_bd_intf_net -intf_net tcp_bridge_0_tcp_tx [get_bd_intf_ports tcp_tx] [get_bd_intf_pins tcp_bridge_0/tcp_tx]
  connect_bd_intf_net -intf_net tcp_rx_1 [get_bd_intf_ports tcp_rx] [get_bd_intf_pins tcp_bridge_0/tcp_rx]

  # Create port connections
  connect_bd_net -net axi_datamover_0_mm2s_err [get_bd_ports mm2s_err] [get_bd_pins axi_datamover_0/mm2s_err]
  connect_bd_net -net axi_datamover_0_s2mm_err [get_bd_ports s2mm_err] [get_bd_pins axi_datamover_0/s2mm_err]
  connect_bd_net -net axi_resetn_1 [get_bd_ports axi_resetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_datamover_0/m_axi_mm2s_aresetn] [get_bd_pins axi_datamover_0/m_axi_s2mm_aresetn] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aresetn] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_aresetn] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN]
  connect_bd_net -net clk_1 [get_bd_ports clk] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_datamover_0/m_axi_mm2s_aclk] [get_bd_pins axi_datamover_0/m_axi_s2mm_aclk] [get_bd_pins axi_datamover_0/m_axis_mm2s_cmdsts_aclk] [get_bd_pins axi_datamover_0/m_axis_s2mm_cmdsts_awclk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins tcp_bridge_0/clk]
  connect_bd_net -net clk_tcp_1 [get_bd_ports clk_tcp] [get_bd_pins tcp_bridge_0/clk_tcp]
  connect_bd_net -net rst_1 [get_bd_ports rst] [get_bd_pins tcp_bridge_0/rst]
  connect_bd_net -net rst_tcp_1 [get_bd_ports rst_tcp] [get_bd_pins tcp_bridge_0/rst_tcp]

  # Create address segments
  create_bd_addr_seg -range 0x00002000 -offset 0xC0000000 [get_bd_addr_spaces axi_datamover_0/Data_MM2S] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0
  create_bd_addr_seg -range 0x00002000 -offset 0xC0000000 [get_bd_addr_spaces axi_datamover_0/Data_S2MM] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] SEG_axi_bram_ctrl_0_Mem0

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   guistr: "# # String gsaved with Nlview 6.6.5b  2016-09-06 bk=1.3687 VDI=39 GEI=35 GUI=JA:1.6
#  -string -flagsOSRD
preplace port s2mm_err -pg 1 -y 240 -defaultsOSRD
preplace port tcp_rx -pg 1 -y 480 -defaultsOSRD
preplace port mm2s_err -pg 1 -y 220 -defaultsOSRD
preplace port cpld_tx -pg 1 -y 460 -defaultsOSRD
preplace port rst_tcp -pg 1 -y 560 -defaultsOSRD
preplace port rst -pg 1 -y 520 -defaultsOSRD
preplace port axi_resetn -pg 1 -y 150 -defaultsOSRD
preplace port clk_tcp -pg 1 -y 540 -defaultsOSRD
preplace port clk -pg 1 -y 130 -defaultsOSRD
preplace port tcp_tx -pg 1 -y 510 -defaultsOSRD
preplace port cpld_rx -pg 1 -y 490 -defaultsOSRD
preplace inst tcp_bridge_0 -pg 1 -lvl 2 -y 480 -defaultsOSRD
preplace inst blk_mem_gen_0 -pg 1 -lvl 4 -y 300 -defaultsOSRD
preplace inst axi_datamover_0 -pg 1 -lvl 1 -y 170 -defaultsOSRD
preplace inst axi_interconnect_0 -pg 1 -lvl 2 -y 140 -defaultsOSRD
preplace inst axi_bram_ctrl_0 -pg 1 -lvl 3 -y 300 -defaultsOSRD
preplace netloc tcp_bridge_0_tcp_tx 1 2 3 NJ 510 NJ 510 NJ
preplace netloc cpld_tx_1 1 0 2 NJ 460 NJ
preplace netloc axi_datamover_0_M_AXIS_S2MM_STS 1 1 1 490
preplace netloc axi_datamover_0_M_AXIS_MM2S_STS 1 1 1 480
preplace netloc axi_datamover_0_mm2s_err 1 1 4 500J 290 810J 210 NJ 210 1320J
preplace netloc tcp_rx_1 1 0 2 NJ 480 NJ
preplace netloc rst_tcp_1 1 0 2 NJ 560 NJ
preplace netloc axi_bram_ctrl_0_BRAM_PORTA 1 3 1 NJ
preplace netloc rst_1 1 0 2 NJ 520 NJ
preplace netloc axi_datamover_0_M_AXI_S2MM 1 1 1 470
preplace netloc clk_tcp_1 1 0 2 NJ 540 NJ
preplace netloc axi_datamover_0_s2mm_err 1 1 4 460J 300 830J 230 NJ 230 1320J
preplace netloc tcp_bridge_0_MM2S_CMD 1 0 3 60 340 NJ 340 820
preplace netloc clk_1 1 0 3 30 500 510 310 840J
preplace netloc tcp_bridge_0_S2MM 1 0 3 40 350 NJ 350 810
preplace netloc axi_datamover_0_M_AXIS_MM2S 1 1 1 470
preplace netloc tcp_bridge_0_cpld_rx 1 2 3 NJ 490 NJ 490 NJ
preplace netloc axi_interconnect_0_M00_AXI 1 2 1 820
preplace netloc axi_resetn_1 1 0 3 20 320 520 320 NJ
preplace netloc tcp_bridge_0_S2MM_CMD 1 0 3 50 330 NJ 330 840
preplace netloc axi_datamover_0_M_AXI_MM2S 1 1 1 460
levelinfo -pg 1 0 260 670 970 1210 1340 -top 0 -bot 610
",
}

  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


