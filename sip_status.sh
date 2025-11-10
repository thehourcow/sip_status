#!/bin/zsh
# sip_status.sh - Direct SIP configuration reader
# Reads raw SIP flags via csr_get_active_config() syscall

set -e

# SIP flag definitions
typeset -A CSR_FLAGS
CSR_FLAGS=(
    0x1   "CSR_ALLOW_UNTRUSTED_KEXTS"
    0x2   "CSR_ALLOW_UNRESTRICTED_FS"
    0x4   "CSR_ALLOW_TASK_FOR_PID"
    0x8   "CSR_ALLOW_KERNEL_DEBUGGER"
    0x10  "CSR_ALLOW_APPLE_INTERNAL"
    0x20  "CSR_ALLOW_UNRESTRICTED_DTRACE"
    0x40  "CSR_ALLOW_UNRESTRICTED_NVRAM"
    0x80  "CSR_ALLOW_DEVICE_CONFIGURATION"
    0x100 "CSR_ALLOW_ANY_RECOVERY_OS"
    0x200 "CSR_ALLOW_UNAPPROVED_KEXTS"
    0x400 "CSR_ALLOW_EXECUTABLE_POLICY_OVERRIDE"
    0x800 "CSR_ALLOW_UNAUTHENTICATED_ROOT"
)

get_sip_config() {
    local c_program="/tmp/read_sip_$$.c"
    local binary="/tmp/read_sip_$$"
    
    cat > "$c_program" << 'EOF'
#include <stdio.h>
#include <stdint.h>
extern int csr_get_active_config(uint32_t *config);
int main() {
    uint32_t config = 0;
    if (csr_get_active_config(&config) == 0) {
        printf("%u\n", config);
        return 0;
    }
    return 1;
}
EOF
    
    if cc -o "$binary" "$c_program" 2>/dev/null; then
        local config=$("$binary" 2>/dev/null)
        rm -f "$c_program" "$binary"
        echo "$config"
        return 0
    fi
    
    rm -f "$c_program" "$binary"
    return 1
}

is_flag_set() {
    local config=$1
    local flag=$2
    (( (config & flag) == flag ))
}

check_sip_fully_enabled() {
    local config=$1
    # Core flags: 0x2, 0x4, 0x20, 0x40
    ! is_flag_set $config 0x2 && \
    ! is_flag_set $config 0x4 && \
    ! is_flag_set $config 0x20 && \
    ! is_flag_set $config 0x40
}

check_sip_fully_disabled() {
    local config=$1
    is_flag_set $config 0x2 && \
    is_flag_set $config 0x4 && \
    is_flag_set $config 0x20 && \
    is_flag_set $config 0x40
}

display_sip_status() {
    local config=$1
    
    if check_sip_fully_enabled $config; then
        if is_flag_set $config 0x10; then
            echo "enabled (Apple Internal)"
        else
            echo "enabled"
        fi
    elif check_sip_fully_disabled $config; then
        if is_flag_set $config 0x10; then
            echo "disabled (Apple Internal)"
        else
            echo "disabled"
        fi
    else
        echo "custom"
    fi
}

display_authenticated_root_status() {
    local config=$1
    # 0x800 = CSR_ALLOW_UNAUTHENTICATED_ROOT
    # If CLEAR: authenticated root required (enabled)
    # If SET: unauthenticated root allowed (disabled)
    if is_flag_set $config 0x800; then
        echo "disabled"
    else
        echo "enabled"
    fi
}

show_flags() {
    local config=$1
    # Iterate over keys, convert hex to decimal for sorting
    for flag_value in ${(on)${(k)CSR_FLAGS}}; do
        local flag_name="${CSR_FLAGS[$flag_value]}"
        local flag_decimal=$((flag_value))
        if is_flag_set $config $flag_decimal; then
            printf "  [X] %-6s %s\n" "$flag_value" "$flag_name"
        else
            printf "  [ ] %-6s %s\n" "$flag_value" "$flag_name"
        fi
    done
}

main() {
    local config=$(get_sip_config)
    
    if [ -z "$config" ]; then
        echo "ERROR: Failed to read SIP configuration" >&2
        echo "Requires C compiler (clang/gcc)" >&2
        exit 1
    fi
    
    echo "SIP Configuration: 0x$(printf '%x' $config)"
    echo ""
    echo "System Integrity Protection: $(display_sip_status $config)"
    echo "Authenticated Root: $(display_authenticated_root_status $config)"
    echo ""
    echo "Flags:"
    show_flags $config
}

main "$@"