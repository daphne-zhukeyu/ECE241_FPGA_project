# wave_demo.do -- ModelSim script for the demo_player testbench
# In ModelSim: File > Change Directory... -> the project's sim folder,
# then in the Transcript type:   do wave_demo.do

onerror {resume}
vlib work
vlog ../rtl/demo_player.v tb_demo_player.v
vsim -t 1ps -voptargs=+acc work.tb_demo_player

add wave -divider "Inputs"
add wave -label clk    /tb_demo_player/clk
add wave -label reset  /tb_demo_player/reset
add wave -label enable /tb_demo_player/enable
add wave -label song_sel /tb_demo_player/song_sel

add wave -divider "Demo state"
add wave -label step  -radix unsigned /tb_demo_player/dut/step
add wave -label idx   -radix unsigned /tb_demo_player/dut/idx
add wave -label len   -radix unsigned /tb_demo_player/dut/len
add wave -label gap   /tb_demo_player/dut/gap
add wave -label timer -radix unsigned /tb_demo_player/dut/timer

add wave -divider "Keys"
add wave -label key_down -radix binary /tb_demo_player/key_down
add wave /tb_demo_player/Do
add wave /tb_demo_player/Re
add wave /tb_demo_player/Mi
add wave /tb_demo_player/Fa
add wave /tb_demo_player/Sol
add wave /tb_demo_player/La

run -all
wave zoom full
