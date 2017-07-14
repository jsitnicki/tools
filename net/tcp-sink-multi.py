#!/usr/bin/env python3
"""
Listen for TCP messages on a port range in one or more net namespaces
and count unique L4 flows ({src addr, dst addr, src port, dst port}).

USAGE: tcp-sink-multi.py [-p <port range>] <netns> [<netns> ...]

    -p <port range>   Port or consecutive ports to listen on
                      Example: -p 54321, -p 8080-8090

    <netns>           Network namespace to open listening socket in

"""

import ctypes as ct
import getopt
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


def open_listen_sock(port):
    s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    a = (LISTEN_HOST, port)
    s.bind(a)
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


def parse_port_range(range_arg):
    p1, p2 = (0, 0)
    ports = range_arg.split('-')

    if len(ports) == 1:
        p1, p2 = int(ports[0]), int(ports[0])
    elif len(ports) == 2:
        p1, p2 = int(ports[0]), int(ports[1])
    else:
        log('bad port range: ' + ports)
        sys.exit(1)

    if p1 > p2:
        log('bad port range: %d > %d' % (p1, p2))
        sys.exit(1)

    return p1, p2


def usage(msg):
    log('%s: %s' % (sys.argv[0], msg))
    log(__doc__)


def main():
    init_funcs()

    first_port = last_port = LISTEN_PORT

    try:
        opts, args = getopt.getopt(sys.argv[1:], 'p:')
    except getopt.GetoptError as err:
        usage(err)
        sys.exit(1)

    for o, a in opts:
        if o == '-p':
            first_port, last_port = parse_port_range(a)
        else:
            assert False, 'unhandled option'

    if len(args) == 0:
        usage('missing net namespace name(s)')
        sys.exit(1)

    for netns in args:
        enter_netns(netns)
        for port in range(first_port, last_port + 1):
            s = open_listen_sock(port)
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


if __name__ == '__main__':
    main()
