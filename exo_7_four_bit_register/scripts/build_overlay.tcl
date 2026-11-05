# Vivado 2024.1, separate project. Default: create/validate/generate products.
# Full build: vivado -mode batch -source scripts/build_overlay.tcl -tclargs build
if {![string match "2024.1*" [version -short]]} {
    error "Use Vivado 2024.1 for this integration script."
}
set exo [file normalize [file join [file dirname [info script]] ..]]
set board_repo [file join $exo build board_files]
if {[info exists ::env(PYNQ_BOARD_REPO)]} {
    set board_repo [file normalize $::env(PYNQ_BOARD_REPO)]
}
set_param board.repoPaths [list $board_repo]
set out [file join $exo build pynq_overlay]
if {[info exists ::env(PYNQ_OVERLAY_DIR)]} {
    set out [file normalize $::env(PYNQ_OVERLAY_DIR)]
}
set project_file [file join $out registers.xpr]
set action "validate"
if {$argc > 0} {set action [lindex $argv 0]}
if {$action ni {validate build implement}} {error "Expected validate, build or implement"}

if {$action eq "implement"} {
    if {![file exists $project_file]} {error "No existing project: $project_file"}
    open_project $project_file
    open_bd_design [get_files */registers.bd]
    validate_bd_design
} else {

if {[file exists $project_file]} {
    # Never silently overwrite an existing design or its results.
    error "Project already exists: $project_file. Open it in Vivado, or use a fresh build directory."
}
set boards [get_board_parts -quiet *pynq-z2*]
if {[llength $boards] != 1} {
    error "Expected one PYNQ-Z2 board definition under $board_repo; run scripts/fetch_board_files.py first."
}
create_project registers $out -part xc7z020clg400-1
set_property board_part [lindex $boards 0] [current_project]
set_property target_language VHDL [current_project]
foreach source {parallel_register shift_register register_system command_adapter register_axi_wrapper} {
    add_files -norecurse [file join $exo src ${source}.vhd]
}
update_compile_order -fileset sources_1
create_bd_design registers

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} $ps
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_EN_CLK0_PORT {1} CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.000000}] $ps
# The old board preset fixes this derived, read-only value at 10 MHz.
# Let the connected FCLK propagate its actual frequency instead.
set_property CONFIG.PCW_M_AXI_GP0_FREQMHZ.VALUE_SRC DEFAULT $ps

set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 register_gpio]
set_property -dict [list CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO_WIDTH {9} \
    CONFIG.C_GPIO2_WIDTH {4} CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_ALL_INPUTS {0} \
    CONFIG.C_ALL_INPUTS_2 {1} CONFIG.C_ALL_OUTPUTS_2 {0} \
    CONFIG.C_DOUT_DEFAULT {0x00000000}] $gpio
set fabric [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_fabric]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1} CONFIG.NUM_CLKS {1}] $fabric
set reset [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset_100m]
# C_EXT_RESET_HIGH is read-only and inferred from the active-low PS reset.
set one [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_one]
set_property CONFIG.CONST_VAL {1} $one
set zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero]
set_property CONFIG.CONST_VAL {0} $zero
create_bd_cell -type module -reference register_axi_wrapper register_logic
set_property CONFIG.FREQ_HZ {100000000} [get_bd_pins register_logic/clk]

connect_bd_intf_net [get_bd_intf_pins ps7/M_AXI_GP0] [get_bd_intf_pins axi_fabric/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_fabric/M00_AXI] [get_bd_intf_pins register_gpio/S_AXI]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins ps7/M_AXI_GP0_ACLK] \
    [get_bd_pins axi_fabric/aclk] [get_bd_pins register_gpio/s_axi_aclk] \
    [get_bd_pins register_logic/clk] [get_bd_pins reset_100m/slowest_sync_clk]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins reset_100m/ext_reset_in]
connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins reset_100m/dcm_locked]
connect_bd_net [get_bd_pins const_zero/dout] [get_bd_pins reset_100m/aux_reset_in] \
    [get_bd_pins reset_100m/mb_debug_sys_rst]
connect_bd_net [get_bd_pins reset_100m/interconnect_aresetn] [get_bd_pins axi_fabric/aresetn]
connect_bd_net [get_bd_pins reset_100m/peripheral_aresetn] \
    [get_bd_pins register_gpio/s_axi_aresetn] [get_bd_pins register_logic/aresetn]
connect_bd_net [get_bd_pins register_gpio/gpio_io_o] [get_bd_pins register_logic/command]
connect_bd_net [get_bd_pins register_logic/q] [get_bd_pins register_gpio/gpio2_io_i]
assign_bd_address
validate_bd_design
if {[get_property CONFIG.C_EXT_RESET_HIGH $reset] != 0} {
    error "The PS reset must propagate as active-low into proc_sys_reset."
}
save_bd_design
write_bd_tcl -force [file join $out recreate_bd.tcl]
puts "EXO7_BD_VALIDATED"

set bd [get_files */registers.bd]
generate_target all $bd
set wrappers [make_wrapper -files $bd -top]
add_files -norecurse $wrappers
set_property top registers_wrapper [current_fileset]
update_compile_order -fileset sources_1
}
set hwh [file join $out registers.gen sources_1 bd registers hw_handoff registers.hwh]
if {![file exists $hwh]} {error "Missing generated HWH: $hwh"}

if {$action in {build implement}} {
    launch_runs synth_1 -jobs 2
    wait_on_run synth_1
    if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {
        error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    }
    launch_runs impl_1 -to_step route_design -jobs 2
    wait_on_run impl_1
    if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} {
        error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    set reports [file join $out reports]
    file mkdir $reports
    report_timing_summary -report_unconstrained -check_timing_verbose \
        -file [file join $reports timing_post_route.rpt]
    report_cdc -details -file [file join $reports cdc_post_route.rpt]
    report_methodology -file [file join $reports methodology_post_route.rpt]
    report_drc -file [file join $reports drc_post_route.rpt]
    foreach delay_type {max min} {
        set paths [get_timing_paths -delay_type $delay_type -max_paths 1]
        if {[llength $paths] == 0 || [get_property SLACK $paths] < 0} {
            error "Post-route $delay_type timing failed or absent. Inspect reports."
        }
    }
    close_design
    launch_runs impl_1 -to_step write_bitstream -jobs 2
    wait_on_run impl_1
    set bit [file join $out registers.runs impl_1 registers_wrapper.bit]
    if {![file exists $bit]} {error "Bitstream not generated"}
    file mkdir [file join $exo overlay]
    file copy -force $hwh [file join $exo overlay registers.hwh]
    file copy -force $bit [file join $exo overlay registers.bit]
    puts "EXO7_BITSTREAM_READY: [file join $exo overlay registers.bit]"
}
close_project
exit
