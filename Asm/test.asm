# Copyright (C) 2023-2025 Apple Inc. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.

##########
# Macros #
##########

if ARM64 or ARM64E
    const PC = csr7
    const MC = csr6
    const WI = csr0
    const PL = t6
    const MB = csr3
    const BC = csr4

    const sc0 = ws0
    const sc1 = ws1
    const sc2 = ws2
    const sc3 = ws3
elsif X86_64
    const PC = csr2
    const MC = csr1
    const WI = csr0
    const PL = t5
    const MB = csr3
    const BC = csr4

    const sc0 = ws0
    const sc1 = ws1
    const sc2 = csr3
    const sc3 = csr4
elsif RISCV64
    const PC = csr7
    const MC = csr6
    const WI = csr0
    const PL = csr10
    const MB = csr3
    const BC = csr4

    const sc0 = ws0
    const sc1 = ws1
    const sc2 = csr9
    const sc3 = csr10
elsif ARMv7
    const PC = csr1
    const MC = t6
    const WI = csr0
    const PL = t7
    const MB = invalidGPR
    const BC = invalidGPR

    const sc0 = t4
    const sc1 = t5
    const sc2 = csr0
    const sc3 = t7
else
    const PC = invalidGPR
    const MC = invalidGPR
    const WI = invalidGPR
    const PL = invalidGPR
    const MB = invalidGPR
    const BC = invalidGPR

    const sc0 = invalidGPR
    const sc1 = invalidGPR
    const sc2 = invalidGPR
    const sc3 = invalidGPR
end

const PtrSize = constexpr (sizeof(void*))
const MachineRegisterSize = constexpr (sizeof(CPURegister))
const SlotSize = constexpr (sizeof(Register))
const SeenMultipleCalleeObjects = 1

const StackAlignment = constexpr (stackAlignmentBytes())
const StackAlignmentSlots = constexpr (stackAlignmentRegisters())
const StackAlignmentMask = StackAlignment - 1

const PtrSize = constexpr (sizeof(void*))
const SlotSize = constexpr (sizeof(Register))

# amount of memory a local takes up on the stack (16 bytes for a v128)
const V128ISize = 16
const LocalSize = V128ISize
const StackValueSize = V128ISize

const wasmInstance = csr0
if X86_64 or ARM64 or ARM64E or RISCV64
    const memoryBase = csr3
    const boundsCheckingSize = csr4
elsif ARMv7
    const memoryBase = t2
    const boundsCheckingSize = t3
else
    const memoryBase = invalidGPR
    const boundsCheckingSize = invalidGPR
end

const UnboxedWasmCalleeStackSlot = CallerFrame - constexpr Wasm::numberOfIPIntCalleeSaveRegisters * SlotSize - MachineRegisterSize


const IPIntCalleeSaveSpaceAsVirtualRegisters = constexpr Wasm::numberOfIPIntCalleeSaveRegisters + constexpr Wasm::numberOfIPIntInternalRegisters
const IPIntCalleeSaveSpaceStackAligned = (IPIntCalleeSaveSpaceAsVirtualRegisters * SlotSize + StackAlignment - 1) & ~StackAlignmentMask
const IPIntCalleeSaveSpaceStackAligned = 2*IPIntCalleeSaveSpaceStackAligned

macro preserveCallerPCAndCFR()
    if C_LOOP or ARMv7
        push lr
        push cfr
    elsif X86_64
        push cfr
    elsif ARM64 or ARM64E or RISCV64
        push cfr, lr
    else
        error
    end
    move sp, cfr
end

macro restoreCallerPCAndCFR()
    move cfr, sp
    if C_LOOP or ARMv7
        pop cfr
        pop lr
    elsif X86_64
        pop cfr
    elsif ARM64 or ARM64E or RISCV64
        pop lr, cfr
    end
end

macro saveIPIntRegisters()
    subp IPIntCalleeSaveSpaceStackAligned, sp
    if ARM64 or ARM64E
        storepairq MC, PC, -0x10[cfr]
        storeq wasmInstance, -0x18[cfr]
    elsif X86_64 or RISCV64
        storep PC, -0x8[cfr]
        storep MC, -0x10[cfr]
        storep wasmInstance, -0x18[cfr]
    end
end

macro restoreIPIntRegisters()
    if ARM64 or ARM64E
        loadpairq -0x10[cfr], MC, PC
        loadq -0x18[cfr], wasmInstance
    elsif X86_64 or RISCV64
        loadp -0x8[cfr], PC
        loadp -0x10[cfr], MC
        loadp -0x18[cfr], wasmInstance
    end
    addp IPIntCalleeSaveSpaceStackAligned, sp
end

macro narrow(narrowFn, wide16Fn, wide32Fn, k)
    k(narrowFn)
end

macro wide16(narrowFn, wide16Fn, wide32Fn, k)
    k(wide16Fn)
end

macro wide32(narrowFn, wide16Fn, wide32Fn, k)
    k(wide32Fn)
end

macro commonOp(label, prologue, fn)
_%label%:
    prologue()
    fn(narrow)
    if ASSERT_ENABLED
        break
        break
    end

_%label%_wide16:
    prologue()
    fn(wide16)
    if ASSERT_ENABLED
        break
        break
    end

_%label%_wide32:
    prologue()
    fn(wide32)
    if ASSERT_ENABLED
        break
        break
    end
end

macro op(l, fn)
    commonOp(l, macro () end, macro (size)
        size(fn, macro() break end, macro() break end, macro(gen) gen() end)
    end)
end

op(ipint_entry, macro()
if (ARM64 or ARM64E or X86_64 or ARMv7)
    preserveCallerPCAndCFR()
    saveIPIntRegisters()
    doTest()
    restoreIPIntRegisters()
    restoreCallerPCAndCFR()
    ret
else
    break
end
end)

macro doTest()
    addp 0x1337, wa0
    move 0x21, wa1
    call _call_test
    bpeq r0, (0x42211337 + 5), .success
    break
    break
    break
.success:
end

global _ipint_trampoline
_ipint_trampoline:
    jmp _ipint_entry
