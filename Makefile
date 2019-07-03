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
#

# Bank file and information strings
BANKFILE = bank

# FV-1 assembler and flags
AS = asfv1
ASFLAGS = -n -b -c

# I2C eeprom programmer
DERVISHPROG = fv1-eeprom-host
DERVISHTTY = /dev/ttyACM3

# --
TARGET = $(addsuffix .bin,$(BANKFILE))
CHECKFILE = $(addsuffix .chk,$(BANKFILE))
SOURCES = $(wildcard [01234567]_*.asm)
PROGS = $(SOURCES:.asm=.prg)

.PHONY: bank
bank: $(TARGET)

$(TARGET): $(PROGS)

%.prg: %.asm
	$(AS) $(ASFLAGS) $< $@
	dd if=$@ bs=512 count=1 seek=$(firstword $(subst _, ,$<)) conv=notrunc of=$(TARGET)

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
	@echo "	bank [default]	assemble sources into binary bank file"
	@echo "	program		program bank for Elta Console via i2c"
	@echo "	verify		verify bank for Elta Console via i2c"
	@echo "	clean		remove all intermediate files"
	@echo

.PHONY: clean
clean:
	-rm -f $(TARGET) $(CHECKFILE) $(DERVISHBANK) $(PROGS) $(DVTEXTS)
