## DEFINES ##
# Assembly source file
SOURCE=shellcode.s
BIN:=$(basename $(SOURCE))
EXT:=$(suffix $(SOURCE))

# Entry point name: '_start' or 'main'
E=_start

# Architecture: x86 (32) or x64 (64).
ARCH=32

# Name of the given C file to test the shellcode with (no .c extension).
TESTER=tester

# Name of the automatically-generated C file and binary (no .c extension).
AUTO=auto

# Program to edit files with
EDITOR=nano

## COMMANDS ##
.PHONY: all test p print hexdump xxd help put clean a

all: help

help:
	@echo "Usage:\n\tmake targets [parameters]"
	@echo " "
	@echo "targets:"
	@echo "  $(BIN)\t- compiles the assembly code from $(SOURCE)"
	@echo "  print/xxd/p\t- dumps the contents of '$(BIN)' in hex"
	@echo "  set\t\t- calls '$(EDITOR) $(SOURCE)', to set the source assembly code"
	@echo "  put\t\t- calls '$(EDITOR) $(TESTER).c', to put in it hex-encoded shellcode"
	@echo "  test\t\t- compiles '$(TESTER).c' and run it, thus testing the shellcode"
	@echo "  $(AUTO)/a\t- does all of the above in one single step:"
	@echo "   > compiling '$(SOURCE)' into hex bytes,"
	@echo "   > loading those hex bytes into an auto-generated tester program ('$(AUTO).c')"
	@echo "   > compiling and running that very program"
	@echo " "
	@echo "parameters:"
	@echo "  ARCH=XX  (default=$(ARCH))\t\t\tXX-bit binaries (32 / 64)"
	@echo "  SOURCE=file  (default='$(SOURCE)')\tSource assembly filename"
	@echo "  E=XX     (default=$(E))\t\tEntry point (e.g. main)"
	@echo "\nFor instance, 'make print BIN=foo' will print the shellcode from 'foo.s'"
	@echo "   and, 'make auto ARCH=64 E=main' will test the x64 shellcode at main"


set: $(SOURCE)
	$(EDITOR) $<

put: $(TESTER).c
	$(EDITOR) $<

test: $(TESTER)
	./$<

$(TESTER): $(TESTER).c
	$(CC) -m$(ARCH) -fno-stack-protector -z execstack -o $@ $<

$(BIN).o: $(SOURCE)
ifneq ($(EXT), .asm)
	$(CC) -m$(ARCH) -nostdlib -o $@ -c $< -e$(E)
else
ifeq ($(ARCH), 64)
	nasm -f elf64 -o $@ $<
else
	nasm -f elf -o $@ $<
endif
endif

$(BIN).hex: $(BIN).o
	@objdump -d $< # Optional -
	@gdb -n -batch -ex "x/`gdb -n -batch -ex "p \`gdb -n -batch -ex "info file" $< | grep .text | cut -d "i" -f 1\`" | cut -d "-" -f 2`bx $(E)" $< | cut -d ":" -f 2 > $@

a: $(AUTO)
$(AUTO): $(BIN).hex
ifeq ($(ARCH), 64)
	@echo '#define WORD long /* 64 bits */\n' > $(AUTO).c
else
	@echo '#define WORD int /* 32 bits */\n' > $(AUTO).c
endif
	@python shc_cleaner.py "`cat $<`" >> $(AUTO).c
	@echo '\nint main() {\n  WORD* ret;\n  ret = (WORD *) &ret + 2; /* Saved IP */\n  *ret = (WORD) shellcode;\n  return 0;\n}' >> $(AUTO).c
	@rm -f $<
	@$(CC) -m$(ARCH) -z execstack -fno-stack-protector -o $(AUTO) $(AUTO).c
	@echo "\nC program compiled successfully.\nRunning it:"
	@./$(AUTO)
	@echo "\nThe source file of this program is '$(AUTO).c'\n"

p: print
print: hexdump
xxd: hexdump
hexdump: $(BIN).hex
	@echo " "
	@python shc_cleaner.py "`cat $<`"
	@echo " "
	@rm -f $<

clean:
	@rm -f $(BIN) $(TESTER)
	@rm -f $(AUTO)*
	@rm -f *.o
	@rm -f examples/*.o
	@rm -f *~
	@rm -f *.hex
	@ls
