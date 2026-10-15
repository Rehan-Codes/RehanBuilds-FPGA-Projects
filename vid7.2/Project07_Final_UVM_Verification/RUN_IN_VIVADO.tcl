# Run in the Tcl Console of an OPEN Vivado 2025.2 Project 07 .xpr.
# Adds simulation-only UVM files, sets simulation top, launches XSim.
# Does NOT change design sources, physical constraints, or synthesis top.
set p7_root [file dirname [file normalize [info script]]]
if {[llength [current_project -quiet]] == 0} {
    error "Open the original video07_instrument.xpr in Vivado before sourcing this file."
}
catch {close_sim -force}
# Remove only older copies of these three UVM files if already imported
# from a previous upgrade package; never remove the original RTL or testbench.
foreach old [get_files -of_objects [get_filesets sim_1]] {
    set tail [file tail $old]
    if {$tail in {instrument_uvm_if.sv instrument_uvm_pkg.sv tb_instrument_uvm.sv}} {
        set desired [file normalize [file join $p7_root uvm $tail]]
        if {[file normalize $old] ne $desired} {
            puts "P7: Detaching earlier simulation file (not deleting): $old"
            remove_files -fileset sim_1 $old
        }
    }
}
foreach fname {instrument_uvm_if.sv instrument_uvm_pkg.sv tb_instrument_uvm.sv} {
    set f [file join $p7_root uvm $fname]
    if {![file exists $f]} { error "Missing $f" }
    set matches [get_files -quiet $f]
    if {[llength $matches] == 0} {
        add_files -fileset sim_1 -norecurse $f
    }
    set f_obj [get_files -quiet $f]
    if {[llength $f_obj] > 0} { set_property file_type SystemVerilog $f_obj }
}
set_property target_simulator XSim [current_project]
set_property top tb_instrument_uvm [get_filesets sim_1]
set_property xsim.simulate.xsim.more_options {-testplusarg SEED=7} [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "P7: Added UVM simulation files and selected tb_instrument_uvm."
puts "P7: Launching XSim seed=7. If simulation pauses after 1000 ns, type: run all"
launch_simulation -simset sim_1 -mode behavioral
run all
puts "P7: Inspect the Tcl Console for FINAL_SCOREBOARD, FINAL_PWM, FINAL_FIFO and FINAL_RESULT."
