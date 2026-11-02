#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <IOKit/IOKitLib.h>

#ifdef STANDALONE_HELPER

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_WRITE_BYTES 6
#define SMC_CMD_READ_KEYINFO 9

typedef struct {
    unsigned char major;
    unsigned char minor;
    unsigned char build;
    unsigned char reserved;
    unsigned short release;
} SMCVersion;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
    IOByteCount dataSize;
    uint32_t dataType;
    uint8_t dataAttributes;
} SMCKeyInfoData;

typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfoData keyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCParamStruct;

static uint32_t str_to_key(const char *str) {
    uint32_t k = 0;
    for (int i = 0; i < 4 && str[i]; i++) {
        k = (k << 8) | (uint8_t)str[i];
    }
    return k;
}

static kern_return_t smc_open(io_connect_t *conn) {
    mach_port_t mainPort;
    IOMainPort(MACH_PORT_NULL, &mainPort);
    io_service_t service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMCKeysEndpoint"));
    if (!service) {
        service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMC"));
    }
    if (!service) {
        return kIOReturnNotFound;
    }
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, conn);
    IOObjectRelease(service);
    return kr;
}

static kern_return_t smc_call(io_connect_t conn, SMCParamStruct *input, SMCParamStruct *output) {
    size_t outSize = sizeof(SMCParamStruct);
    return IOConnectCallStructMethod(conn, KERNEL_INDEX_SMC, input, sizeof(SMCParamStruct), output, &outSize);
}

static kern_return_t smc_get_key_info(io_connect_t conn, const char *key, SMCKeyInfoData *info) {
    SMCParamStruct in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = str_to_key(key);
    in.data8 = SMC_CMD_READ_KEYINFO;
    kern_return_t kr = smc_call(conn, &in, &out);
    if (kr == kIOReturnSuccess && out.result == 0) {
        *info = out.keyInfo;
        return kIOReturnSuccess;
    }
    return kr != kIOReturnSuccess ? kr : kIOReturnError;
}

static kern_return_t smc_read_bytes(io_connect_t conn, const char *key, uint8_t *bytes, size_t maxLen, size_t *outLen) {
    SMCKeyInfoData info;
    kern_return_t kr = smc_get_key_info(conn, key, &info);
    if (kr != kIOReturnSuccess) return kr;
    
    SMCParamStruct in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = str_to_key(key);
    in.keyInfo.dataSize = info.dataSize;
    in.data8 = SMC_CMD_READ_BYTES;
    
    kr = smc_call(conn, &in, &out);
    if (kr == kIOReturnSuccess && out.result == 0) {
        size_t len = (info.dataSize < maxLen) ? info.dataSize : maxLen;
        memcpy(bytes, out.bytes, len);
        if (outLen) *outLen = len;
        return kIOReturnSuccess;
    }
    return kr != kIOReturnSuccess ? kr : kIOReturnError;
}

static kern_return_t smc_write_bytes(io_connect_t conn, const char *key, const uint8_t *bytes, size_t len) {
    SMCKeyInfoData info;
    kern_return_t kr = smc_get_key_info(conn, key, &info);
    if (kr != kIOReturnSuccess) return kr;
    
    SMCParamStruct in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = str_to_key(key);
    in.keyInfo.dataSize = (info.dataSize > 0) ? info.dataSize : (IOByteCount)len;
    in.data8 = SMC_CMD_WRITE_BYTES;
    memcpy(in.bytes, bytes, (len <= 32) ? len : 32);
    
    kr = smc_call(conn, &in, &out);
    if (kr == kIOReturnSuccess && out.result == 0) {
        return kIOReturnSuccess;
    }
    return kr != kIOReturnSuccess ? kr : kIOReturnError;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: harmonotch-smc read <key> | write <key> <hex_value> | inhibit <0|1> [limit]\n");
        return 1;
    }

    io_connect_t conn;
    if (smc_open(&conn) != kIOReturnSuccess) {
        fprintf(stderr, "Failed to open SMC connection\n");
        return 2;
    }

    if (strcmp(argv[1], "read") == 0 && argc >= 3) {
        uint8_t buf[32] = {0};
        size_t len = 0;
        if (smc_read_bytes(conn, argv[2], buf, sizeof(buf), &len) == kIOReturnSuccess) {
            for (size_t i = 0; i < len; i++) {
                printf("%02x", buf[i]);
            }
            printf("\n");
            IOServiceClose(conn);
            return 0;
        } else {
            fprintf(stderr, "Read failed for key %s\n", argv[2]);
            IOServiceClose(conn);
            return 3;
        }
    } else if (strcmp(argv[1], "write") == 0 && argc >= 4) {
        uint8_t val = (uint8_t)strtoul(argv[3], NULL, 16);
        if (smc_write_bytes(conn, argv[2], &val, 1) == kIOReturnSuccess) {
            printf("OK\n");
            IOServiceClose(conn);
            return 0;
        } else {
            fprintf(stderr, "Write failed for key %s\n", argv[2]);
            IOServiceClose(conn);
            return 4;
        }
    } else if (strcmp(argv[1], "inhibit") == 0 && argc >= 3) {
        int inhibit = atoi(argv[2]);
        uint8_t ch0b_val = inhibit ? 0x02 : 0x00;
        kern_return_t kr = smc_write_bytes(conn, "CH0B", &ch0b_val, 1);
        if (kr != kIOReturnSuccess) {
            uint8_t bclm_val = inhibit ? 80 : 100;
            if (argc >= 4) {
                int customLimit = atoi(argv[3]);
                if (customLimit >= 50 && customLimit <= 100) {
                    bclm_val = (uint8_t)customLimit;
                }
            }
            kr = smc_write_bytes(conn, "BCLM", &bclm_val, 1);
        }

        IOServiceClose(conn);
        if (kr == kIOReturnSuccess) {
            printf("OK\n");
            return 0;
        } else {
            fprintf(stderr, "Failed to set charging inhibit mode\n");
            return 5;
        }
    }

    IOServiceClose(conn);
    return 1;
}

#endif
