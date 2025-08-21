#include "test.h"

#include "LLIntOfflineAsmConfig.h"
#include "InlineASM.h"

//============================================================================
// Define the opcode dispatch mechanism when using an ASM loop:
//

// We need an OFFLINE_ASM_BEGIN_SPACER because we'll be declaring every OFFLINE_ASM_GLOBAL_LABEL
// as an alt entry. However, Clang will error out if the first global label is also an alt entry.
// To work around this, we'll make OFFLINE_ASM_BEGIN emit an unused global label (which will now
// be the first) that is not an alt entry, and insert a spacer instruction between it and the
// actual first global label emitted by the offlineasm. Clang also requires that these 2 labels
// not point to the same spot in memory; hence, the need for the spacer.
//
// For the spacer instruction, we'll choose a breakpoint instruction. However, we can
// also just emit an unused piece of data. A breakpoint instruction is preferable.

#if CPU(ARM_THUMB2)
#define OFFLINE_ASM_BEGIN_SPACER "bkpt #0\n"
#elif CPU(ARM64)
#define OFFLINE_ASM_BEGIN_SPACER "brk #" STRINGIZE_VALUE_OF(WTF_FATAL_CRASH_CODE) "\n"
#elif CPU(X86_64)
#define OFFLINE_ASM_BEGIN_SPACER "int3\n"
#else
#define OFFLINE_ASM_BEGIN_SPACER ".int 0xbadbeef0\n"
#endif

// These are for building an interpreter from generated assembly code:
// the jsc_llint_begin and jsc_llint_end labels help lldb_webkit.py find the
// start and end of the llint instruction range quickly.

#define OFFLINE_ASM_BEGIN   asm ( \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(jsc_llint_begin, OFFLINE_ASM_NO_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_ALIGN4B, HIDE_SYMBOL) \
    OFFLINE_ASM_BEGIN_SPACER

#define OFFLINE_ASM_END \
    OFFLINE_ASM_BEGIN_SPACER \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(jsc_llint_end, OFFLINE_ASM_NO_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_ALIGN4B, HIDE_SYMBOL) \
);

#if ENABLE(LLINT_EMBEDDED_OPCODE_ID)
#define EMBED_OPCODE_ID_IF_NEEDED(__opcode) ".int " __opcode##_value_string "\n"
#else
#define EMBED_OPCODE_ID_IF_NEEDED(__opcode)
#endif

#define OFFLINE_ASM_OPCODE_LABEL(__opcode) \
    EMBED_OPCODE_ID_IF_NEEDED(__opcode) \
    OFFLINE_ASM_OPCODE_DEBUG_LABEL(llint_##__opcode) \
    OFFLINE_ASM_LOCAL_LABEL(llint_##__opcode)

#define OFFLINE_ASM_GLUE_LABEL(__opcode) \
    OFFLINE_ASM_OPCODE_DEBUG_LABEL(__opcode) \
    OFFLINE_ASM_LOCAL_LABEL(__opcode)

#define OFFLINE_ASM_NO_ALT_ENTRY_DIRECTIVE(label)

#if COMPILER(CLANG) && OS(DARWIN) && ENABLE(OFFLINE_ASM_ALT_ENTRY)
#define OFFLINE_ASM_ALT_ENTRY_DIRECTIVE(label) \
    ".alt_entry " SYMBOL_STRING(label) "\n"
#else
#define OFFLINE_ASM_ALT_ENTRY_DIRECTIVE(label)
#endif

#if OS(DARWIN)
#define OFFLINE_ASM_TEXT_SECTION ".section __TEXT,__jsc_int,regular,pure_instructions\n"
#else
#define OFFLINE_ASM_TEXT_SECTION ".text\n"
#endif

#if CPU(ARM_THUMB2)
#define OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, ALT_ENTRY, ALIGNMENT, VISIBILITY) \
    OFFLINE_ASM_TEXT_SECTION                     \
    ALIGNMENT                                    \
    ALT_ENTRY(label)                             \
    ".globl " SYMBOL_STRING(label) "\n"          \
    VISIBILITY(label) "\n"                       \
    ".thumb\n"                                   \
    ".thumb_func " THUMB_FUNC_PARAM(label) "\n"  \
    SYMBOL_STRING(label) ":\n"
#elif CPU(RISCV64)
#define OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, ALT_ENTRY, ALIGNMENT, VISIBILITY) \
    OFFLINE_ASM_TEXT_SECTION                    \
    ALIGNMENT                                   \
    ALT_ENTRY(label)                            \
    ".globl " SYMBOL_STRING(label) "\n"         \
    ".attribute arch, \"rv64gc\"" "\n"          \
    VISIBILITY(label) "\n"                      \
    SYMBOL_STRING(label) ":\n"
#else
#define OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, ALT_ENTRY, ALIGNMENT, VISIBILITY) \
    OFFLINE_ASM_TEXT_SECTION                    \
    ALIGNMENT                                   \
    ALT_ENTRY(label)                            \
    ".globl " SYMBOL_STRING(label) "\n"         \
    VISIBILITY(label) "\n"                      \
    SYMBOL_STRING(label) ":\n"
#endif

#define OFFLINE_ASM_ALIGN4B ".balign 4\n"
#define OFFLINE_ASM_NOALIGN ""

#if CPU(ARM64) || CPU(ARM64E)
#define OFFLINE_ASM_ALIGN_TRAP(align) OFFLINE_ASM_BEGIN_SPACER "\n .balignl " #align ", 0xd4388e20\n" // pad with brk instructions
#elif CPU(X86_64)
#define OFFLINE_ASM_ALIGN_TRAP(align) OFFLINE_ASM_BEGIN_SPACER "\n .balign " #align ", 0xcc\n" // pad with int 3 instructions
#elif CPU(ARM)
#define OFFLINE_ASM_ALIGN_TRAP(align) OFFLINE_ASM_BEGIN_SPACER "\n .balignw " #align ", 0xde00\n" // pad with udf instructions
#elif CPU(RISCV64)
#define OFFLINE_ASM_ALIGN_TRAP(align) OFFLINE_ASM_BEGIN_SPACER "\n .balignw " #align ", 0x9002\n" // pad with c.ebreak instructions
#endif

#define OFFLINE_ASM_EXPORT_SYMBOL(symbol)

#define OFFLINE_ASM_GLOBAL_LABEL(label) \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, OFFLINE_ASM_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_ALIGN4B, HIDE_SYMBOL)
#define OFFLINE_ASM_UNALIGNED_GLOBAL_LABEL(label) \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, OFFLINE_ASM_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_NOALIGN, HIDE_SYMBOL)
#define OFFLINE_ASM_ALIGNED_GLOBAL_LABEL(label, align) \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, OFFLINE_ASM_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_ALIGN_TRAP(align), HIDE_SYMBOL)
#define OFFLINE_ASM_GLOBAL_EXPORT_LABEL(label) \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, OFFLINE_ASM_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_ALIGN4B, OFFLINE_ASM_EXPORT_SYMBOL)
#define OFFLINE_ASM_UNALIGNED_GLOBAL_EXPORT_LABEL(label) \
    OFFLINE_ASM_GLOBAL_LABEL_IMPL(label, OFFLINE_ASM_ALT_ENTRY_DIRECTIVE, OFFLINE_ASM_NOALIGN, OFFLINE_ASM_EXPORT_SYMBOL)

#if COMPILER(CLANG) && ENABLE(OFFLINE_ASM_ALT_ENTRY)
#define OFFLINE_ASM_ALT_GLOBAL_LABEL(label) OFFLINE_ASM_GLOBAL_LABEL(label)
#else
#define OFFLINE_ASM_ALT_GLOBAL_LABEL(label)
#endif

#define OFFLINE_ASM_LOCAL_LABEL(label) \
    LOCAL_LABEL_STRING(label) ":\n" \
    OFFLINE_ASM_ALT_GLOBAL_LABEL(label)

#if OS(LINUX)
#define OFFLINE_ASM_OPCODE_DEBUG_LABEL(label)  #label ":\n"
#else
#define OFFLINE_ASM_OPCODE_DEBUG_LABEL(label)
#endif


// This works around a bug in GDB where, if the compilation unit
// doesn't have any address range information, its line table won't
// even be consulted. Emit {before,after}_llint_asm so that the code
// emitted in the top level inline asm statement is within functions
// visible to the compiler. This way, GDB can resolve a PC in the
// llint asm code to this compilation unit and the successfully look
// up the line number information.
DEBUGGER_ANNOTATION_MARKER(before_llint_asm)


// We do not set them on Darwin since Mach-O does not support nested cfi_startproc & global symbols.
// https://github.com/llvm/llvm-project/issues/72802
// Similarly, GCC complains about implicit endproc instructions.
//
// This may seem strange; We duplicate these table entries because
// different lldb versions seem to sometimes have off-by-one errors otherwise.
// See GdbJIT.cpp for a detailed explanation of how these DWARF directives work.
#if !OS(DARWIN) && COMPILER(CLANG)
#if CPU(ARM64)
asm (
    ".cfi_startproc\n"
    ".cfi_def_cfa fp, 16\n"
    ".cfi_offset lr, -8\n"
    ".cfi_offset fp, -16\n"
    OFFLINE_ASM_BEGIN_SPACER
    ".cfi_def_cfa fp, 0\n"
    ".cfi_offset lr, 0\n"
    ".cfi_offset fp, 0\n"
    OFFLINE_ASM_BEGIN_SPACER
    ".cfi_def_cfa fp, 16\n"
    ".cfi_offset lr, -8\n"
    ".cfi_offset fp, -16\n"
    OFFLINE_ASM_BEGIN_SPACER
);
#elif CPU(ARM_THUMB2)
asm (
    ".cfi_startproc\n"
    OFFLINE_ASM_BEGIN_SPACER
    ".cfi_def_cfa r7, 8\n"
    ".cfi_offset lr, -4\n"
    ".cfi_offset fp, -8\n"
    OFFLINE_ASM_BEGIN_SPACER
    ".cfi_def_cfa r7, 8\n"
    ".cfi_offset lr, -4\n"
    ".cfi_offset fp, -8\n"
    OFFLINE_ASM_BEGIN_SPACER
);
#endif
#endif

// This is a file generated by offlineasm, which contains all of the assembly code
// for the interpreter, as compiled from LowLevelInterpreter.asm.
#include "../build/LLIntAssembly.h"

// See GdbJIT.cpp for a detailed explanation.
#if !OS(DARWIN) && COMPILER(CLANG)
#if CPU(ARM64) || CPU(ARM_THUMB2)
asm (
    ".cfi_endproc\n"
);
#endif
#endif

DEBUGGER_ANNOTATION_MARKER(after_llint_asm)
