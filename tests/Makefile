CC = gcc
CFLAGS = -Wall -Wextra -std=c11
LDFLAGS = -lwayland-client

WAYLAND_CLIENT_CFLAGS = $(shell pkg-config --cflags wayland-client 2>/dev/null || echo "-I/usr/local/include")
WAYLAND_CLIENT_LIBS = $(shell pkg-config --libs wayland-client 2>/dev/null || echo "-L/usr/local/lib -lwayland-client")

CFLAGS += $(WAYLAND_CLIENT_CFLAGS)
LDFLAGS += $(WAYLAND_CLIENT_LIBS)

TESTS = test_protocol_compliance test_wayland_client

all: $(TESTS)

test_protocol_compliance: test_protocol_compliance.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

test_wayland_client: test_wayland_client.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -f $(TESTS)

test: all
	@echo "Running protocol compliance tests..."
	@export WAYLAND_DISPLAY=wayland-0 && \
	 export XDG_RUNTIME_DIR=$${XDG_RUNTIME_DIR:-/tmp} && \
	 ./test_protocol_compliance

.PHONY: all clean test

