# Expects these environmental variables to be set
# name             example
# BOARD            vcu108
# TOP_LEVEL        top_loopback
# VIVADO_VERSION   v2019.1

## Project setup

set board_to_part(vcu108) xcvu095-ffva2104-2-e

set board $env(BOARD)
set part $board_to_part($board)
set top_level $env(TOP_LEVEL)
set vivado_version $env(VIVADO_VERSION)

## Output directory setup

set output_dir build/$board
file mkdir $output_dir
set files [glob -nocomplain "$output_dir/*"]
if {[llength $files] != 0} {
    puts "Deleting contents of $output_dir."
    file delete -force {*}[glob -directory $output_dir *];
} else {
    puts "$output_dir is empty."
}

## FPGA setup

set_part $part

## Source file setup

# Read in all (if any) system verilog files created by users:
set sources_sv [ glob -nocomplain ./src/*.sv ]
if {[llength $sources_sv] > 0 } {
  read_verilog $sources_sv
}
# Read in all (if any) verilog files created by users:
set sources_v [ glob -nocomplain ./src/*.v ]
if {[llength $sources_v] > 0 } {
  read_verilog $sources_v
}

# Read in all (if any) system verilog files generated by Bluespec:
set bsc_sv [ glob -nocomplain ./build/verilog/*.sv ]
if {[llength $bsc_sv] > 0 } {
  read_verilog $bsc_sv
}
# Read in all (if any) verilog files generated by Bluespec:
set bsc_v [ glob -nocomplain ./build/verilog/*.v ]
if {[llength $bsc_v] > 0 } {
  read_verilog $bsc_v
}
# Read in all (if any) verilog files from Bluespec libraries:
set bsc_lib [ glob -nocomplain $env(BLUESPECDIR)/Verilog/*.v ]
if {[llength $bsc_lib] > 0 } {
  read_verilog $bsc_lib
}

# Read in constraint files:
read_xdc ./xdc/$board.xdc
# read in all (if any) hex memory files:
set sources_mem [ glob -nocomplain ./data/*.mem ]
if {[llength $sources_mem] > 0} {
  read_mem $sources_mem
}

## IP generation

set ip_dir ./ip/$vivado_version
set sources_ip [ glob -nocomplain -directory $ip_dir -tails * ]
puts $sources_ip
foreach ip_source $sources_ip {
  if {[file isdirectory $ip_dir/$ip_source]} {
	  read_ip $ip_dir/$ip_source/$ip_source.xci
  }
}
generate_target all [get_ips]
synth_ip [get_ips]

## Bitstream generation steps

# Run Synthesis

set stage 1_synth
synth_design -top $top_level -part $part -verbose -verilog_define BSV_NO_MAIN_V
opt_design
write_checkpoint -force $output_dir/${stage}.dcp
report_timing_summary -file $output_dir/${stage}_timing_summary.rpt
report_utilization -file $output_dir/${stage}_util.rpt -hierarchical -hierarchical_depth 4
report_timing -file $output_dir/${stage}_timing.rpt

# Run place

set stage 2_place
place_design

# Get timing violations and run optimizations if needed
if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
 puts "Found setup timing violations => running physical optimization"
 phys_opt_design
}

write_checkpoint -force $output_dir/${stage}.dcp
report_timing_summary -file $output_dir/${stage}_timing_summary.rpt
report_utilization -file $output_dir/${stage}_util.rpt
report_timing -file $output_dir/${stage}_timing.rpt
report_clock_utilization -file $output_dir/${stage}_clock_util.rpt

# Run route

set stage 3_route
route_design -directive Explore

write_checkpoint -force $output_dir/${stage}.dcp
report_route_status -file $output_dir/${stage}_status.rpt
report_timing_summary -file $output_dir/${stage}_timing_summary.rpt
report_timing -file $output_dir/${stage}_timing.rpt
report_power -file $output_dir/${stage}_power.rpt
report_drc -file $output_dir/${stage}_drc.rpt

# Write bitstream

write_bitstream -force $output_dir/final.bit


# Original source:
# https://fpga.mit.edu/6205/_static/F24/default_files/build.tcl