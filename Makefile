## DEFINES ##

# Architecture: 32 bits or 64 bits.
ARCH=32

# Assembly source file #
S=shellcode.s
SOURCE=$(S)
BIN:=$(basename $(notdir $(SOURCE)))
EXT:=$(suffix $(SOURCE))

# Assembly binary filename (for debugging purposes) #
ASSEMBLY=assembly

# Rule to debug the assembly binary #
DEBUG=debug

# Prefix and suffix of rules to debug the shellcode (smashed stack situation) #
SC=sc

# Entry point name: for instance, 'main' #
# (Change this to prevent a warning when compiling
# an assembly program without '_start'...)
E=_start

# Name of the given C file to test the shellcode with (no .c extension).
TESTER=tester

# Name of the automatically-generated C file and binary (no .c extension).
AUTO=auto

# Program to edit files with
EDITOR=@nano

# Compiler flags for a smashable-and-executable stack #
VULNFLAGS=-fno-stack-protector -z execstack

## COMMANDS ##
.PHONY: all help usage p print hexdump xxd help put clean a \
	$(ASSEMBLY) $(DEBUG) $(DEBUG)_$(SC) $(SC)_$(DEBUG) $(BIN).o

# Default rule is usage #
all: usage

help: usage # an alias #

usage:
	@echo "Usage:\n\tmake targets [parameters]"
	@echo " "
	@echo "targets:"
	@echo "  $(ASSEMBLY)\t- compiles the assembly code from $(SOURCE)"
	@echo "  $(DEBUG)\t\t- debugs the assembly binary"
	@echo "  print/xxd/p\t- dumps the contents of '$(BIN)' in hex"
	@echo \
"  set\t\t- calls '$(EDITOR) $(SOURCE)', to set the source assembly code"
	@echo \
"  put\t\t- calls '$(EDITOR) $(TESTER).c', to put in it hex-encoded shellcode"
	@echo \
"  test\t\t- compiles '$(TESTER).c' and run it, thus testing the shellcode"
	@echo "  $(AUTO)/a\t- does all of the above in one single step:"
	@echo "   > compiling '$(SOURCE)' into hex bytes,"
	@echo \
"   > loading those hex bytes into an auto-generated test program ('$(AUTO).c')"
	@echo "   > compiling and running that very program"
	@echo "  $(DEBUG)_$(SC)\t- debugs the shellcode when called from a smashed stack"
	@echo " "
	@echo "parameters:"
	@echo "  ARCH=XX  (default=$(ARCH))\t\t\tXX-bit binaries (32 / 64)"
	@echo "  S=filename  (default='$(SOURCE)')\tSource assembly filename"
	@echo \
"\nFor instance, 'make print S=foo.s' will print the shellcode from 'foo.s'"
	@echo "   and, 'make auto ARCH=64' will test x64 shellcode"

set: $(SOURCE)
	$(EDITOR) $<

put: $(TESTER).c
	$(EDITOR) $<

test: $(TESTER)
	./$<

$(TESTER): $(TESTER).c
	$(CC) -m$(ARCH) -g $(VULNFLAGS) -o $@ $<


# Compile the assembly as an object file (to extracting its hex data) #
$(BIN).o: $(SOURCE)
ifneq ($(EXT), .asm)
	$(CC) -m$(ARCH) -nostdlib -o $@ -c $<
else
ifeq ($(ARCH), 64)
	nasm -f elf64 -o $@ $<
else
	nasm -f elf -o $@ $<
endif
endif

## DEBUGGING THE ASSEMBLY ##
# Compile the assembly as an executable program #
$(ASSEMBLY): $(BIN).o
	$(CC) -m$(ARCH) -nostdlib -o $@ $< -e$(E)

# Debug it #
$(DEBUG): $(ASSEMBLY)
	gdb -ex "start" $<

# Debug the shellcode (smashed stack situation) #
$(SC)_$(DEBUG): $(AUTO).c
	$(CC) -g -m$(ARCH) $(VULNFLAGS) -o $(AUTO) $<
	gdb -ex "b *&shellcode" -ex "run" $(AUTO)

$(DEBUG)_$(SC): $(SC)_$(DEBUG) # an alias #

# Dirty one-liner hacks to get start address and length of assembly code, #
# to then be able to get the right hex bytes #
$(BIN).hex: $(BIN).o
	@objdump -d $< # optional
	@gdb -n -batch -ex "info file" $< | grep .text | cut -d "i" -f 1 > /tmp/_infofile_
	@echo "\nTotal: `gdb -n -batch -ex "p \`cat /tmp/_infofile_\`" | cut -d "-" -f 2 > /tmp/_len_ && cat /tmp/_len_` bytes."
	@gdb -n -batch -ex "x/`cat /tmp/_len_ && rm -f /tmp/_len_`bx `cat /tmp/_infofile_ | cut -d "-" -f 1 && rm -f /tmp/_infofile_`" $< | cut -d ":" -f 2 > $@


# Compile a vulnerable C program with the generated shellcode #
# that gets executed when the program auto-smashes its saved IP #
$(AUTO).c : $(BIN).hex
ifeq ($(ARCH), 64)
	@echo '#define WORD long /* 64 bits */\n' > $@
else
	@echo '#define WORD int /* 32 bits */\n' > $@
endif
	@python -c 'import sys; print "char shellcode[] =\n \"" + "".join([sys.argv[1][k], "\\", ""][2 * int(sys.argv[1][k] == " " or sys.argv[1][k] == "\t" or sys.argv[1][k] == "\n") + int(sys.argv[1][k] == "0" and sys.argv[1][(k+1) % len(sys.argv[1])] == "x")] for k in range(len(sys.argv[1]))) + "\";"' "`cat $<`" >> $@
	@echo '\nint main() {\n  WORD* ret;\n  ret = (WORD *) &ret + 2; /* Saved IP */\n  *ret = (WORD) shellcode;\n  return 0;\n}' >> $(AUTO).c

$(AUTO): $(AUTO).c
	$(CC) -g -m$(ARCH) $(VULNFLAGS) -o $@ $<
	@echo "\nC program compiled successfully.\nRunning it:"
	@./$(AUTO)
	@echo "\nThe source file of this program is '$(AUTO).c'\n"

a: $(AUTO) # an alias #

$(OBJDUMP): $(BIN).o

hexdump: $(OBJDUMP) $(BIN).hex
	@echo " "
	@python -c 'import sys; print "char shellcode[] =\n \"" + "".join([sys.argv[1][k], "\\", ""][2 * int(sys.argv[1][k] == " " or sys.argv[1][k] == "\t" or sys.argv[1][k] == "\n") + int(sys.argv[1][k] == "0" and sys.argv[1][(k+1) % len(sys.argv[1])] == "x")] for k in range(len(sys.argv[1]))) + "\";"' "`cat $(BIN).hex`"
	@echo " "

p: print # an alias #

print: hexdump # an alias #

xxd: hexdump # an alias #

clean:
	@rm -f $(ASSEMBLY) $(TESTER)
	@rm -f $(AUTO)*
	@rm -f /tmp/_len_
	@rm -f /tmp/_infofile_
	@rm -f *.o
	@rm -f *~
	@rm -f *.hex
	@ls
