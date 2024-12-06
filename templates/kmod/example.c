#include <linux/module.h>

static int __init example_init(void)
{
	printk(KERN_INFO "Break stuff...\n");

	return -1; /* It never loads. */
}
module_init(example_init);

static void __exit example_exit(void)
{
}
module_exit(example_exit);

MODULE_DESCRIPTION("Example module");
MODULE_AUTHOR("Jakub Sitnicki");
MODULE_LICENSE("Dual BSD/GPL");
