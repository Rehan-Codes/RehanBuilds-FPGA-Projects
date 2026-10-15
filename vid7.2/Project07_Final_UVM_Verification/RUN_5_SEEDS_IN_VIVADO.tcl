# Run only AFTER RUN_IN_VIVADO.tcl passes.
# From original Vivado project Tcl Console:
# source {C:/path/Project07_Final_UVM_Verification/RUN_5_SEEDS_IN_VIVADO.tcl}
set p7_root [file dirname [file normalize [info script]]]
if {[llength [current_project -quiet]] == 0} {error "Open Project 07 .xpr first"}
# Can be run on its own; this ensures UVM sources are installed.
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
    if {![file exists $f]} {error "Missing $f"}
    if {[llength [get_files -quiet $f]]==0} {add_files -fileset sim_1 -norecurse $f}
    set f_obj [get_files -quiet $f]
    if {[llength $f_obj]>0} {set_property file_type SystemVerilog $f_obj}
}
set_property target_simulator XSim [current_project]
set_property top tb_instrument_uvm [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "P7: Starting five full Vivado UVM runs. Inspect each FINAL_RESULT line."
foreach seed {7 11 23 41 83} {
    catch {close_sim -force}
    puts "================ PROJECT 07 SEED $seed ================"
    set_property xsim.simulate.xsim.more_options "-testplusarg SEED=$seed" [get_filesets sim_1]
    launch_simulation -simset sim_1 -mode behavioral
    run all
    puts "================ END SEED $seed ========================="
}
puts "P7: Finished launching all five simulations. Confirm each FINAL_RESULT is PASS and each UVM report has zero ERROR and FATAL."
