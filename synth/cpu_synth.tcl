# Vivado out-of-context synthesis script for riscv_cpu
# Run from the synth/ directory:
#   vivado -mode batch -source cpu_synth.tcl

set part_name  "xc7a35tcpg236-1"   ;# Artix-7 (Basys3-class part)
set rtl_dir    "../rtl"
set report_dir "./reports"
set gates_dir  "./gates"

file mkdir $report_dir
file mkdir $gates_dir

# Read RTL sources (package first, then submodules, then top)
read_verilog -sv $rtl_dir/cpu_pkg.sv
read_verilog -sv $rtl_dir/alu_adder.v
read_verilog -sv $rtl_dir/alu_logic.v
read_verilog -sv $rtl_dir/alu_shift.v
read_verilog -sv $rtl_dir/alu.v
read_verilog -sv $rtl_dir/regfile.v
read_verilog -sv $rtl_dir/instr_decode.v
read_verilog -sv $rtl_dir/control_unit.v
read_verilog -sv $rtl_dir/instr_fetch.v
read_verilog -sv $rtl_dir/instr_memory.v
read_verilog -sv $rtl_dir/data_memory.v
read_verilog -sv $rtl_dir/cpu_top.v

# Set the top module
set_property top cpu_top [current_fileset]

# Synthesize out-of-context (standalone block synthesis, no I/O buffers)
synth_design -top cpu_top -part $part_name -mode out_of_context

# Generate reports
report_utilization             -file $report_dir/area_breakdown.rpt
report_timing_summary          -file $report_dir/timing.rpt
report_timing -delay_type max -max_paths 10 -file $report_dir/timing_max_paths.rpt
report_power                   -file $report_dir/power_breakdown.rpt

puts "=== Synthesis complete ==="
puts "Reports written to $report_dir/"

# Write out the synthesized netlist and checkpoint for reference
write_verilog -force $gates_dir/cpu_top_synth.v
write_checkpoint -force $gates_dir/cpu_top_post_synth.dcp