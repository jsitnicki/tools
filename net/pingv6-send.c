/*
 * Author: Jakub Sitnicki <jkbs@redhat.com>
 * License: GPL
 *
 * Test program for sending ICMPv6 Echo Request messages
 *
 * Read data from standard input (up to 4096 bytes) and send it as a payload of
 * ICMPv6 Echo Request message to a host:port specified on the command line.
 *
 * Uses PINGv6 sockets. Remember to them for your user:
 * echo <uid> <gid> > /proc/sys/net/ipv4/ping_group_range
 */

#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/* Header length of ICMPv6 Echo Request message */
#define ICMPV6_ECHO_HLEN 8
/* Maximum payload length of ICMPv6 Echo request message that we accept */
#define ICMPV6_ECHO_PLEN 4096

#define die_if(msg, cond)			\
	do {					\
		if (cond)			\
			die(msg, #cond);	\
	} while (0)

static void die(const char *msg, const char *expr)
{
	char *s = NULL;

	if (asprintf(&s, "%s: %s", msg, expr) != -1) {
		perror(s);
		free(s);
	}
	exit(EXIT_FAILURE);
}

static void usage(const char *prog_name)
{
	fprintf(stderr, "Usage: %s [-c] <host> <port>\n", prog_name);
	fprintf(stderr, "\n");
	fprintf(stderr, "Options:\n");
	fprintf(stderr, "  -c    connect() the socket\n");

	exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
	unsigned char buf[ICMPV6_ECHO_HLEN + ICMPV6_ECHO_PLEN] = { };
	const char *host, *port;
	struct addrinfo *dst;
	bool opt_connect;
	int s, opt;
	size_t len;
	ssize_t r;

	opt_connect = false;
	while ((opt = getopt(argc, argv, "c")) != -1) {
		switch (opt) {
		case 'c':
			opt_connect = true;
			break;
		default:
			usage(argv[0]);
			break;
		}
	}
	if (argc - optind != 2)
		usage(argv[0]);
	host = argv[optind++];
	port = argv[optind++];

	/* get address we will be sending to */
	r = getaddrinfo(host, port, NULL, &dst);
	die_if("getaddrinfo", r != 0);

	/* create socket */
	s = socket(AF_INET6, SOCK_DGRAM, IPPROTO_ICMPV6);
	die_if("socket", s < 0);

	/* optionally connect the socket */
	if (opt_connect) {
		r = connect(s, dst->ai_addr, dst->ai_addrlen);
		die_if("connect", r < 0);
	}

	/* fill in ICMPv6 Echo Request header */
	buf[0] = 0x80;		/* type */
	buf[1] = 0x00;		/* code */
	buf[2] = buf[3] = 0x00;	/* checksum (filled in by the kernel) */
	buf[4] = buf[5] = 0x00; /* identifier (filled in by the kernel) */
	buf[6] = buf[7] = 0x00; /* sequence number */

	/* read ICMPv6 Echo Request payload from standard input */
	len = fread(buf + ICMPV6_ECHO_HLEN, 1, ICMPV6_ECHO_PLEN, stdin);
	die_if("fread", ferror(stdin));

	/* send the message */
	len += ICMPV6_ECHO_HLEN;
	if (opt_connect)
		r = send(s, buf, len, 0);
	else
		r = sendto(s, buf, len, 0, dst->ai_addr, dst->ai_addrlen);
	die_if("send", r < 0);

	/* clean up */
	freeaddrinfo(dst);
	close(s);

	return 0;
}
