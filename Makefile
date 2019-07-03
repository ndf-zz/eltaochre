# Makefile for Elta Console
#
# --
# 2019 Nathan Fraser <ndf@metarace.com.au>
#
# To the extent possible under law, the author(s) have dedicated
# all copyright and related and neighboring rights to this software
# to the public domain worldwide. This software is distributed
# without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication
# along with this software. If not, see:
#
#   http://creativecommons.org/publicdomain/zero/1.0/
# --
#
# Input files:
#	5_prog.asm		Console program #1
#	7_prog.asm		Console program #2
#	3_prog.asm		Console program #3
#
# Output files:
#	bank.bin		FV-1 program bank binary
#	bank.bnk		Dervish combined program & text bank
#

# Bank file and information strings
BANKFILE = bank
BANKNO = 0				# Dervish bank number 0 - 11 decimal
BANKNAME =  "OCHRE - Reversers       "	# 20 chars for dervish
BANKINFO1 = "Reverse delays for Elta "
BANKINFO2 = " (CC0) - Public Domain  "
BANKINFO3 = " <ndf@metarace.com.au>  "

# FV-1 assembler and flags
AS = asfv1
ASFLAGS = -n -b -c

# Helper scripts for extracting display texts
DRVTXT = drvtext

# Programmer for Dervish i2c eeprom programmer (also for Elta Console)
DERVISHPROG = fv1-eeprom-host
DERVISHTTY = /dev/ttyACM3

# --
TARGET = $(addsuffix .bin,$(BANKFILE))
CHECKFILE = $(addsuffix .chk,$(BANKFILE))
DERVISHBANK = $(TARGET:.bin=.bnk)
SOURCES = $(wildcard [01234567]_*.asm)
PROGS = $(SOURCES:.asm=.prg)
DVTEXTS = $(SOURCES:.asm=.dvt)

.PHONY: files
files:	$(TARGET) $(DERVISHBANK)

$(TARGET): $(PROGS)

$(DERVISHBANK): $(TARGET) $(DVTEXTS)
	dd if=$(TARGET) bs=512 count=8 conv=notrunc of=$(DERVISHBANK)
	printf '%-20.20b\n' $(BANKNAME) \
		| dd bs=21 count=1 seek=4096 oflag=seek_bytes conv=notrunc of=$(DERVISHBANK)
	
%.dvt: %.asm
	$(DRVTXT) $< $@
	dd if=$@ bs=84 count=1 seek=$(shell echo $$(( 4117 + $(firstword $(subst _, ,$<)) * 84 ))) oflag=seek_bytes conv=notrunc of=$(DERVISHBANK)

%.prg: %.asm
	$(AS) $(ASFLAGS) $< $@
	dd if=$@ bs=512 count=1 seek=$(firstword $(subst _, ,$<)) conv=notrunc of=$(TARGET)

.PHONY: dprog
dprog: $(DERVISHBANK)
	$(DERVISHPROG) -v -n 4789 -o $(shell echo $$(( 5120 * $(BANKNO) ))) -p 128 -t $(DERVISHTTY) -f $(DERVISHBANK) -c W

.PHONY: program
program: $(TARGET)
	$(DERVISHPROG) -n 4096 -o 0 -p 32 -t $(DERVISHTTY) -f $(TARGET) -c W

.PHONY: $(CHECKFILE)
$(CHECKFILE):
	$(DERVISHPROG) -n 4096 -o 0 -p 32 -t $(DERVISHTTY) -f $(CHECKFILE) -c R

.PHONY: verify
verify: $(TARGET) $(CHECKFILE)
	cmp -b $(CHECKFILE) $(TARGET)
	@echo Verify OK

.PHONY: help
help:
	@echo
	@echo Targets:
	@echo "	files [default]	assemble sources into bank and display files"
	@echo "	program		program bank for Elta Console via i2c"
	@echo "	verify		verify bank for Elta Console via i2c"
	@echo "	dprog		program bank on a (u)dervish via i2c"
	@echo "	clean		remove all intermediate files"
	@echo

.PHONY: clean
clean:
	-rm -f $(TARGET) $(CHECKFILE) $(DERVISHBANK) $(PROGS) $(DVTEXTS)
