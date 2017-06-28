#!/usr/bin/env python2
#
# Based on https://gist.github.com/akorobov/7903307.
#
# Author: Jakub Sitnicki <jkbs@redhat.com>
#
"""\
Simple HTTP server that serves the current directory contents.

Server also recognizes 2 special HTTP GET queries:

  http://<address>:<port>/?ip - report client's IP address
  http://<address>:<port>/?ns - report server's network namespace
  http://<address>:<port>/?bytes=<N> - return '@' repeated N times as
                                       document body

Examples:

  $ ./toy-httpd.py 2>/dev/null &
  Serving HTTP on :: port 8000 ...

  $ curl [::1]:8000/?ip
  Your IP address is ::1

  $ curl [::1]:8000/?ns
  You have reached namespace net:[4026531969]

  $ curl [::1]:8000/?bytes=42
  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@<no new line>

  $ echo 'Hello HTTP' > hello.txt
  $ curl [::1]:8000/hello.txt
  Hello HTTP

"""

import argparse
import socket
import sys
import os
import urlparse
import BaseHTTPServer
import SocketServer
from SimpleHTTPServer import SimpleHTTPRequestHandler


class RequestHandler(SimpleHTTPRequestHandler):
  def do_GET(self):
    if self.path == '/?ip':
      self.respond('Your IP address is %s\n' % self.client_address[0])
    elif self.path == '/?ns':
      self.respond('You have reached namespace %s\n' % os.readlink('/proc/self/ns/net'))
    elif self.path.startswith('/?bytes'):
      query = urlparse.urlparse(self.path).query
      howmany = urlparse.parse_qs(query, keep_blank_values=True)['bytes'][0]
      howmany = int(howmany) if howmany else 0
      self.respond('@' * howmany)
    else:
      return SimpleHTTPRequestHandler.do_GET(self)

  def respond(self, msg):
    self.send_response(200)
    self.send_header('Content-type', 'text/plain')
    self.end_headers()
    self.wfile.write(msg)


class HTTPServerV4(SocketServer.TCPServer):
  address_family = socket.AF_INET
  allow_reuse_address = 1

class HTTPServerV6(SocketServer.TCPServer):
  address_family = socket.AF_INET6
  allow_reuse_address = 1


def main():
  parser = argparse.ArgumentParser(description=__doc__,
                                   formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument('port', help='port number to listen on (by default 80)',
                      default=8080, type=int, nargs='?')
  parser.add_argument('-4', help="use IPv4",
                      action="store_false", dest='use_ipv6')
  parser.add_argument('-6', help="use IPv6 (default)",
                      action="store_true", dest='use_ipv6', default=True)

  args = parser.parse_args()
  if args.use_ipv6:
    ServerClass = HTTPServerV6
  else:
    ServerClass = HTTPServerV4

  # BaseHTTPServer.test() expects just one positional argument
  sys.argv[1:] = [ args.port ]
  BaseHTTPServer.test(RequestHandler, ServerClass)

if __name__ == '__main__':
  main()
