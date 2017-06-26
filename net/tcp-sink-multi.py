#!/usr/bin/env python3
#
# Count the flows received in one or more net namespaces.
#

import ctypes as ct
import os
import selectors
import signal
import socket
import sys

CLONE_NEWNET = 0x40000000

NETNS_RUN_DIR = '/var/run/netns'

LISTEN_HOST = ''
LISTEN_PORT = 6666

READ_BUF_SIZE = 4096

errno_loc = None
setns = None

sock_netns_map = {}
flow_register = {}
sel = selectors.DefaultSelector()

def log(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def errcheck(ret, func, args):
    if ret == -1:
        e = errno_loc()[0]
        raise OSError(e, os.strerror(e))
    return ret


def init_funcs():
    global errno_loc
    global setns

    libc = ct.CDLL("libc.so.6")

    errno_loc = libc.__errno_location
    errno_loc.restype = ct.POINTER(ct.c_int)

    setns = libc.setns
    setns.errcheck = errcheck


def enter_netns(netns_name):
    err = 0

    netns_path = '%s/%s' % (NETNS_RUN_DIR, netns_name)
    netns_fd = os.open(netns_path, os.O_RDONLY)
    setns(netns_fd, CLONE_NEWNET)


def open_listen_sock():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(('', 6666))
    s.listen(100)
    s.setblocking(False)
    return s


def accept(netns, sock, mask):
    conn, addr = sock.accept()
    log(netns, 'accepted connection from', addr)
    conn.setblocking(False)
    sock_netns_map[conn.fileno()] = netns
    sel.register(conn, selectors.EVENT_READ, read)
    log(sock_netns_map)


def read(netns, conn, mask):
    data = conn.recv(READ_BUF_SIZE)
    log(netns, 'received', len(data), 'bytes from', conn.getpeername())
    if len(data) == 0:
        sel.unregister(conn)
        return

    conn_id = (conn.getsockname(), conn.getpeername())
    if netns not in flow_register:
        flow_register[netns] = {}
    flow_register[netns][conn_id] = True


def print_flow_count():
    for netns in flow_register:
        print(netns, len(flow_register[netns]))
    sys.stdout.flush()


def sig_handler(signo, stack_frame):
    print_flow_count()
    sys.exit(0)

if __name__ == '__main__':
    init_funcs()

    if len(sys.argv) < 2:
        log('missing net namespace name(s)')
        sys.exit(1)

    for netns in sys.argv[1:]:
        enter_netns(netns)
        s = open_listen_sock()
        log(netns, 'listening at', s.getsockname())
        sock_netns_map[s.fileno()] = netns
        sel.register(s, selectors.EVENT_READ, accept)
        log(sock_netns_map)

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    try:
        while True:
            events = sel.select()
            for key, mask in events:
                callback = key.data
                fileobj = key.fileobj
                netns = sock_netns_map[fileobj.fileno()]
                callback(netns, fileobj, mask)
    except KeyboardInterrupt:
        print_flow_count()
