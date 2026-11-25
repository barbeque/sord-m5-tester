ZASM_FLAGS := --labels
local_path = $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

TEST_SYSTEM = "m5"

all: memview.bin

memview.bin: memview.asm psg.asm vdp_macros.asm vdp.asm
	zasm ${ZASM_FLAGS} memview.asm memview.bin

run: memview.bin
	cd ${MAME_PATH} && ./mame ${TEST_SYSTEM} -cart1 ${local_path}memview.bin

debug: memview.bin
	cd ${MAME_PATH} && ./mame ${TEST_SYSTEM} -debug -cart1 ${local_path}memview.bin

openshots:
	open ${MAME_PATH}/snap/m5

pad: memview.sc
	python3 ./prepare.py -s 256 memview.bin

burn: pad memview.padded.bin
	minipro -p MX27C256@DIP28 -w memview.padded.bin

clean:
	rm -rf memview.bin
	rm -rf memview.lst
	rm -rf memview.padded.bin
