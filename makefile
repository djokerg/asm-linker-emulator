SRCS_AS = src/main_as.cpp src/helpers.cpp src/directive.cpp src/lang_elem.cpp src/instruction.cpp src/addressing.cpp misc/parser.cpp misc/lexer.cpp src/assembler.cpp
SRCS_LN = src/main_ln.cpp src/linker.cpp
SRCS_EM = src/main_em.cpp src/emulator.cpp
GPP = g++
HEADERS = $(wildcard inc/*.hpp)

all: assembler linker emulator

# Run an example program: make run EXAMPLE=level-a
EXAMPLE ?= hello
run: all
	scripts/run-example.sh ${EXAMPLE}

# Run every example headless and check the final register state
test: all
	scripts/run-tests.sh

.PHONY: all run test clean clean_all clean_tests

assembler: $(SRCS_AS) $(HEADERS)
	$(GPP) -g $(SRCS_AS) -o assembler

linker: $(SRCS_LN) $(HEADERS)
	$(GPP) -g $(SRCS_LN) -o linker

emulator: $(SRCS_EM) $(HEADERS)
	$(GPP) -g $(SRCS_EM) -o emulator

misc/lexer.cpp: misc/lexer.l misc/parser.cpp
	flex misc/lexer.l
	mv lexer.cpp ./misc/
	mv lexer.hpp ./misc/

misc/parser.cpp: misc/parser.y misc/lexer.l
	bison misc/parser.y 
	mv parser.cpp ./misc/
	mv parser.hpp ./misc/

clean_all: clean clean_tests
	rm -rf assembler linker emulator
clean:
	rm -rf *.o misc/lexer.cpp misc/lexer.hpp misc/parser.cpp misc/parser.hpp *.txt *.hex
clean_tests:
	rm -rf build 