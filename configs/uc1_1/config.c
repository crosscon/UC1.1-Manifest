#include <config.h>

/* VM #1: GUEST_VM */
static struct vm_config guest_vm = {
    .image = VM_IMAGE_LOADED(0x00020000, 0x00020000, 0x8000),
    .entry = 0x00020000, /* @SUBST_ENTRY_ADDR:GUEST_VM */
    .platform = {
        .cpu_num    = 1,
        .region_num = 2,
        .remio_devs = NULL,
        .mmu = NULL,
        .arch = { 0 },
        .regions = (struct vm_mem_region[]) {
            { .base = 0x20010000, .size = 0x20000 }, /* SRAM1 */
            { .base = 0x00020000, .size = 0x10000 },
        },
        .dev_num = 4,
        .remio_dev_num = 0,
        .devs = (struct vm_dev_region[]) {
            {
                .pa            = 0x40089000, /* USART3 */
                .id            = 0,
                .va            = 0x40089000,
                .size          = 0x1000,
                .interrupt_num = 1,
                .interrupts    = (irqid_t[]){ 17 + 16 },
            },
            {
                .pa   = 0x40000000, /* SYSCON + IOCON + PINT + SPINT */
                .id   = 0,
                .va   = 0x40000000,
                .size = 0x5000,
            },
            {
                .pa   = 0x40013000, /* ANALOG */
                .id   = 0,
                .va   = 0x40013000,
                .size = 0x1000,
            },
            {
                .pa   = 0x40020000, /* POWER MGM */
                .id   = 0,
                .va   = 0x40020000,
                .size = 0x1000,
            },
        },
        .ipc_num = 1,
        .ipcs = (struct ipc[]) {
            {
                .base          = 0x20017000,
                .size          = 0x1000,
                .shmem_id      = 0,
                .interrupt_num = 1,
                .interrupts    = (irqid_t[]){ 78 },
            }
        },
    },
};

/* VM #2: PUF_VM */
static struct vm_config puf_vm = {
    .image = VM_IMAGE_LOADED(0x00060000, 0x00060000, 0x8000),
    .entry = 0x00060000, /* @SUBST_ENTRY_ADDR:PUF_VM */
    .platform = {
        .cpu_num    = 1,
        .region_num = 2,
        .regions = (struct vm_mem_region[]) {
            { .base = 0x20030000, .size = 0x20000 }, /* SRAM1 */
            { .base = 0x00060000, .size = 0x10000 },
        },
        .dev_num = 4,
        .remio_dev_num = 0,
        .remio_devs = NULL,
        .mmu = NULL,
        .arch = { 0 },
        .devs = (struct vm_dev_region[]) {
            {
                .pa            = 0x40088000, /* USART2 */
                .id            = 0,
                .va            = 0x40088000,
                .size          = 0x1000,
                .interrupt_num = 1,
                .interrupts    = (irqid_t[]){ 16 + 16 },
            },
            {
                .pa   = 0x40000000, /* SYSCON + IOCON + PINT + SPINT */
                .id   = 0,
                .va   = 0x40000000,
                .size = 0x5000,
            },
            {
                .pa   = 0x40013000, /* ANALOG */
                .id   = 0,
                .va   = 0x40013000,
                .size = 0x1000,
            },
            {
                .pa   = 0x40020000, /* POWER MGM */
                .id   = 0,
                .va   = 0x40020000,
                .size = 0x1000,
            },
        },
        .ipc_num = 1,
        .ipcs = (struct ipc[]) {
            {
                .base          = 0x20017000,
                .size          = 0x1000,
                .shmem_id      = 0,
                .interrupt_num = 1,
                .interrupts    = (irqid_t[]){ 79 },
            }
        },
    },
};

/* Top‑level config */
struct config config = {
    CONFIG_HEADER

    /* shared‐memory pool for inter‐VM IPC */
    .shmemlist_size = 1,
    .shmemlist = (struct shmem[]) {
        [0] = { .base = 0x20017000, .size = 0x1000 },
    },

    /* two VMs, referenced by pointer */
    .vmlist_size = 2,
    .vmlist = (struct vm_config*[]) {
        &guest_vm,
        &puf_vm,
    },
};
