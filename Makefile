NIM       ?= nim
NIMFLAGS  := -d:release --opt:size
BIN       := nsqltool
SRC       := $(BIN).nim

# Default: native build
.PHONY: all build clean install strip

all: build

build:
	$(NIM) c $(NIMFLAGS) $(SRC)

# Smaller binary via strip
strip: build
	strip $(BIN)

install: build
	install -Dm755 $(BIN) /usr/local/bin/$(BIN)

# Static Linux binary (requires musl: apt install musl-tools)
linux-static:
	$(NIM) c $(NIMFLAGS) --passL:-static $(SRC)

# Cross-compile for Linux ARM64 (requires: apt install gcc-aarch64-linux-gnu)
linux-arm64:
	$(NIM) c $(NIMFLAGS) \
	  --cpu:arm64 --os:linux \
	  --passC:"--target=aarch64-linux-gnu" \
	  --passL:"--target=aarch64-linux-gnu" \
	  --gcc.exe:aarch64-linux-gnu-gcc \
	  --gcc.linkerexe:aarch64-linux-gnu-gcc \
	  -o:$(BIN)-arm64 $(SRC)

# macOS targets must be compiled on macOS or via osxcross
# On macOS: make macos-arm64  or  make macos-x86
macos-arm64:
	$(NIM) c $(NIMFLAGS) --cpu:arm64 --os:macosx -o:$(BIN)-macos-arm64 $(SRC)

macos-x86:
	$(NIM) c $(NIMFLAGS) --cpu:amd64 --os:macosx -o:$(BIN)-macos-x86 $(SRC)

clean:
	rm -f $(BIN) $(BIN)-arm64 $(BIN)-macos-arm64 $(BIN)-macos-x86
	rm -rf nimcache
