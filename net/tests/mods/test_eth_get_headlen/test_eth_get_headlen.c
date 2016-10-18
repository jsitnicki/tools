/*
 * Test input can be crafted with Scapy:
 *
 * >>> p = Ether()/Dot1Q(vlan=43)/IP()/UDP()/DNS()
 * >>> chexdump(p)
 */

#include <linux/kernel.h>	/* for ARRAY_SIZE */
#include <linux/module.h>
#include <linux/etherdevice.h>	/* for eth_get_headlen */

/* Ether()/Dot1Q(vlan=43)/IP()/UDP()/DNS() */
u8 pkt_eth_vlan43_ipv4_udp_12b[] = {
	0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x81, 0x00, 0x00, 0x2b,
	0x08, 0x00, 0x45, 0x00, 0x00, 0x28, 0x00, 0x01, 0x00, 0x00, 0x40, 0x11, 0x7c, 0xc2, 0x7f, 0x00,
	0x00, 0x01, 0x7f, 0x00, 0x00, 0x01, 0x00, 0x35, 0x00, 0x35, 0x00, 0x14, 0x01, 0x5a, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static void test_dot1q(void)
{
	u32 hlen;

	hlen = eth_get_headlen(pkt_eth_vlan43_ipv4_udp_12b, ARRAY_SIZE(pkt_eth_vlan43_ipv4_udp_12b));
	BUG_ON(hlen != 14 + 4 + 20 + 8);
}

static int __init test_eth_get_headlen_init(void)
{
	test_dot1q();

	return 0;
}

module_init(test_eth_get_headlen_init);

static void __exit test_eth_get_headlen_exit(void)
{
}
module_exit(test_eth_get_headlen_exit);

MODULE_DESCRIPTION("Tests for eth_get_headlen()");
MODULE_AUTHOR("Jakub Sitnicki <jkbs@redhat.com>");
MODULE_LICENSE("GPL");
