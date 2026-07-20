# Ubuntu may install only a versioned clang binary (for example clang-18).
BPF_CLANG ?= $(shell for c in clang clang-18 clang-17 clang-16 clang-15 clang-14; do command -v $$c 2>/dev/null && break; done)
HOST_ARCH := $(shell uname -m)

ifeq ($(HOST_ARCH),x86_64)
BPF_ARCH := x86
KERNEL_INCLUDE := /usr/include/x86_64-linux-gnu
else ifeq ($(HOST_ARCH),aarch64)
BPF_ARCH := arm64
KERNEL_INCLUDE := /usr/include/aarch64-linux-gnu
else ifeq ($(HOST_ARCH),arm64)
BPF_ARCH := arm64
KERNEL_INCLUDE := /usr/include/aarch64-linux-gnu
else
BPF_ARCH := $(HOST_ARCH)
KERNEL_INCLUDE := /usr/include/$(HOST_ARCH)-linux-gnu
endif

ifeq ($(strip $(BPF_CLANG)),)
$(error No clang compiler found. Install clang, for example: sudo apt-get install clang llvm)
endif

BPF_CFLAGS := -O2 -g -target bpf -D__TARGET_ARCH_$(BPF_ARCH) \
	-I$(KERNEL_INCLUDE) -I/usr/include

all: rst_guard.bpf.o

rst_guard.bpf.o: rst_guard.bpf.c
	$(BPF_CLANG) $(BPF_CFLAGS) -c $< -o $@

clean:
	rm -f rst_guard.bpf.o

.PHONY: all clean
