# csrutil SIP Verification - Complete Package

## Summary

I've reverse-engineered Apple's `csrutil` utility using Ghidra to understand how it verifies SIP (System Integrity Protection) compliance and authenticated root status. Based on this analysis, I've created bash scripts that replicate the internal logic.

## Key Findings from Reverse Engineering

### Core Protection Flags (6 total)

1. **Filesystem Protections** (0x2) - System file immutability
2. **Debugging Restrictions** (0x4) - task_for_pid() blocking
3. **DTrace Restrictions** (0x20) - DTrace on system processes
4. **NVRAM Protections** (0x40) - Protected NVRAM variables
5. **Boot Argument Filtering** - Dangerous boot args filtered
6. **CTRR Enforcement** - Kernel memory protection

## SIP Flag Bits

**Important:** Flag bits use INVERTED logic!
- Flag bit SET (1) = Protection DISABLED (allowed)
- Flag bit CLEAR (0) = Protection ENABLED (restricted)

| Bit | Hex | Flag Name | When SET (1) |
|-----|-----|-----------|--------------|
| 0 | 0x1 | ALLOW_UNTRUSTED_KEXTS | Unsigned kexts OK |
| 1 | 0x2 | ALLOW_UNRESTRICTED_FS | Filesystem writable |
| 2 | 0x4 | ALLOW_TASK_FOR_PID | Debugging allowed |
| 3 | 0x8 | ALLOW_KERNEL_DEBUGGER | Kernel debug OK |
| 4 | 0x10 | ALLOW_APPLE_INTERNAL | Apple features on |
| 5 | 0x20 | ALLOW_UNRESTRICTED_DTRACE | DTrace allowed |
| 6 | 0x40 | ALLOW_UNRESTRICTED_NVRAM | NVRAM writable |
| 7 | 0x80 | ALLOW_DEVICE_CONFIGURATION | Device config OK |
| 8 | 0x100 | ALLOW_ANY_RECOVERY_OS | Any recovery OK |
| 9 | 0x200 | ALLOW_UNAPPROVED_KEXTS | Unapproved kexts OK |
| 10 | 0x400 | ALLOW_EXECUTABLE_POLICY_OVERRIDE | Policy override OK |
| 11 | 0x800 | ALLOW_UNAUTHENTICATED_ROOT | Unsigned volume OK |

## Common SIP Values

| Value | Hex | Meaning |
|-------|-----|---------|
| 0 | 0x0 | **SIP fully enabled** (factory default) |
| 2167 | 0x877 | **SIP fully disabled** (common) |
| 16 | 0x10 | **Apple Internal only** |
| 3 | 0x3 | **Filesystem + kext signing off** |

## Firmware Security Levels (Apple Silicon/T2)

- **Full Security (2):** SIP forced "enabled"
- **Reduced Security (1):** SIP forced "enabled"
- **Permissive (0):** SIP can be disabled

## Practical Applications

1. **Security Auditing** - Automated SIP status checks
2. **Compliance Verification** - Ensure security policies met
3. **System Documentation** - Record exact security state
4. **Education** - Understand macOS security internals

## Security Notes

### What This Does ✅
- Read SIP configuration status
- Show detailed flag breakdown
- Automate security auditing
- Educational/research purposes

### What These Scripts DO NOT Do ❌
- Modify SIP configuration
- Bypass security protections
- Require elevated privileges (for reading)
- Enable SIP disablement

**SIP can ONLY be modified from Recovery Mode with physical keyboard access.**

## Technical Details

**System Calls:**
```c
int csr_get_active_config(uint32_t *config);  // Kernel syscall
int bootpolicy_get_sip_flags(const char *volume_path, uint64_t *flags);  // Private framework
```

## Conclusion

The reverse engineering reveals csrutil uses a sophisticated approach with kernel syscalls, boot policy framework, firmware security integration, and three-state logic. The bash scripts successfully replicate this logic for automated security monitoring.

---

**Reverse Engineering Tools:** Ghidra 10.x, bash, C
**Target:** /usr/bin/csrutil (ARM64)
**Purpose:** Educational/Research
