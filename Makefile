BPF_CLANG ?= clang
BPF_CFLAGS := -O2 -g -target bpf -D__TARGET_ARCH_x86 \
	-I/usr/include/$(shell uname -m)-linux-gnu -I/usr/include

all: rst_guard.bpf.o

rst_guard.bpf.o: rst_guard.bpf.c
	$(BPF_CLANG) $(BPF_CFLAGS) -c $< -o $@

clean:
	rm -f rst_guard.bpf.o

.PHONY: all clean
