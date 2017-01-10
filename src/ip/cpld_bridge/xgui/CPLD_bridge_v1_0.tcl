# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  ipgui::add_page $IPINST -name "Page 0"

  ipgui::add_param $IPINST -name "BOARD_TYPE" -widget comboBox

}

proc update_PARAM_VALUE.BOARD_TYPE { PARAM_VALUE.BOARD_TYPE } {
	# Procedure called to update BOARD_TYPE when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.BOARD_TYPE { PARAM_VALUE.BOARD_TYPE } {
	# Procedure called to validate BOARD_TYPE
	return true
}


proc update_MODELPARAM_VALUE.BOARD_TYPE { MODELPARAM_VALUE.BOARD_TYPE PARAM_VALUE.BOARD_TYPE } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.BOARD_TYPE}] ${MODELPARAM_VALUE.BOARD_TYPE}
}

