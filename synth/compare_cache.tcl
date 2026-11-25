# Invoked separately for each top by run_fpga_comparison.sh.
if {$argc != 4} {
    error "Expected repository root, top module, FPGA part and clock period"
}
lassign $argv repo_root top part period_ns
if {![regexp {^[0-9]+([.][0-9]+)?$} $period_ns] || $period_ns <= 0} {
    error "Clock period must be a positive decimal number in ns"
}
set period_ns [format %.6f $period_ns]
if {$period_ns <= 0} {
    error "Clock period rounds to zero at six decimal places"
}

switch -- $top {
    cache_2way {
        read_verilog [file join $repo_root rtl cache_2way_store.v]
        read_verilog [file join $repo_root rtl cache_2way.v]
    }
    cache_direct {
        read_verilog [file join $repo_root rtl cache_direct.v]
    }
    default { error "Unknown cache top: $top" }
}

set constraint [open comparison.xdc w]
puts $constraint [format {create_clock -name cache_clk -period %s [get_ports clk]} $period_ns]
close $constraint
read_xdc comparison.xdc

# Use the same constraints and implementation settings for both isolated cores.
set_param general.maxThreads 1
synth_design -top $top -part $part -mode out_of_context
report_utilization -file post_synth_utilization.rpt
opt_design
place_design
route_design
report_route_status -file route_status.rpt
report_utilization -file post_route_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file post_route_timing.rpt

# Restrict the estimate to internal register-to-register paths on the cache clock.
# Top-level data/control inputs and outputs have no external timing budget.
set registers [all_registers -clock [get_clocks cache_clk]]
if {[llength $registers] == 0} {
    error "No registers found on cache_clk for $top"
}
set paths [get_timing_paths -from $registers -to $registers -delay_type max -max_paths 1]
if {[llength $paths] != 1} {
    error "No internal setup timing path found for $top"
}
report_timing -from $registers -to $registers -delay_type max -max_paths 5 \
    -file post_route_internal_setup.rpt
set slack_ns [get_property SLACK [lindex $paths 0]]
set estimated_period_ns [expr {$period_ns - $slack_ns}]
if {$estimated_period_ns <= 0} {
    error "Invalid estimated internal period for $top: $estimated_period_ns ns"
}
set estimated_mhz [expr {1000.0 / $estimated_period_ns}]

set csv [open result.csv w]
puts $csv "top,part,vivado_version,stage,constraint_ns,internal_setup_slack_ns,estimated_internal_fmax_mhz"
puts $csv [format "%s,%s,%s,post_route,%.3f,%.3f,%.3f" \
    $top $part [version -short] $period_ns $slack_ns $estimated_mhz]
close $csv
