#pragma once

#include <iostream>
#include <cstdlib>
#include <cstdint>

#define SYSV_ABI

#define ENABLE(f) 0
#define USE(f) 0
#define HAVE(WTF_FEATURE) (defined WTF_HAVE_##WTF_FEATURE  && WTF_COMPILER_##WTF_FEATURE)
#define COMPILER(WTF_FEATURE) (defined WTF_COMPILER_##WTF_FEATURE  && WTF_COMPILER_##WTF_FEATURE)
#define OS(WTF_FEATURE) (defined WTF_OS_##WTF_FEATURE && WTF_OS_##WTF_FEATURE)
#define CPU(WTF_FEATURE) (defined WTF_CPU_##WTF_FEATURE  && WTF_CPU_##WTF_FEATURE)

#define WTF_CPU_REGISTER64 1
#define WTF_CPU_ARM64 1
#define WTF_CPU_UNKNOWN 0
#define WTF_OS_LINUX 1
#define WTF_COMPILER_CLANG 1
#define WTF_HAVE_INTERNAL_VISIBILITY 1

#define ASSERT_ENABLED 1

#if !defined(DEBUGGER_ANNOTATION_MARKER) && COMPILER(GCC)
#define DEBUGGER_ANNOTATION_MARKER(name) \
    __attribute__((__no_reorder__)) void name(void) { __asm__(""); }
#endif

#if !defined(DEBUGGER_ANNOTATION_MARKER)
#define DEBUGGER_ANNOTATION_MARKER(name)
#endif

#define STRINGIZE(exp) #exp
#define STRINGIZE_VALUE_OF(exp) STRINGIZE(exp)

#if !defined(WTF_FATAL_CRASH_CODE)
#if ASAN_ENABLED
#define WTF_FATAL_CRASH_CODE 0x0
#else
#define WTF_FATAL_CRASH_CODE 0xc471
#endif
#endif

#if CPU(REGISTER64)
using CPURegister = int64_t;
using UCPURegister = uint64_t;
#else
using CPURegister = int32_t;
using UCPURegister = uint32_t;
#endif

namespace JSC {

namespace Wasm {
constexpr unsigned numberOfLLIntCalleeSaveRegisters = 2;
#if CPU(ARM)
constexpr unsigned numberOfIPIntCalleeSaveRegisters = 2;
#else
constexpr unsigned numberOfIPIntCalleeSaveRegisters = 3;
#endif
constexpr unsigned numberOfLLIntInternalRegisters = 2;
constexpr unsigned numberOfIPIntInternalRegisters = 2;
constexpr ptrdiff_t WasmToJSScratchSpaceSize = 0x8 * 1 + 0x8; // Needs to be aligned to 0x10.
constexpr ptrdiff_t WasmToJSCallableFunctionSlot = -0x8;
} // namespace Wasm

constexpr unsigned stackAlignmentBytes() { return 16; }

constexpr unsigned stackAlignmentRegisters()
{
    return stackAlignmentBytes() / sizeof(uint64_t);
}

class Register {
public:
    int64_t integer;
};
} // namespace JSC

extern "C" uint32_t SYSV_ABI ipint_trampoline(uint32_t);
