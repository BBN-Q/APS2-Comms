# Calls `export_simulation` for all current testbench script directories

# figure out the script path
set SCRIPT_PATH [file normalize [info script]]
set REPO_PATH [file dirname $SCRIPT_PATH]/../

set testbenches [glob -type d -directory ../test/scripts/ -tails *_tb]

foreach tb $testbenches {
	puts "Updating $tb"
	set_property top $tb [get_filesets sim_1]
	set_property top_lib xil_defaultlib [get_filesets sim_1]
	export_ip_user_files -no_script -force
	export_simulation  -force -directory $REPO_PATH/test/scripts/$tb -simulator xsim
}
