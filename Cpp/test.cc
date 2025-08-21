#include "test.h"

namespace JSC { namespace Wasm {

extern "C" uint32_t __attribute__((__used__)) call_test(uint32_t arg1, uint32_t arg2) {
    auto ret = (arg1 << 0) | (arg2 << 16) | (0x42 << 24);
    std::cout << "Call test with arguments: " << arg1 << ", " << arg2 << " = " << ret << std::endl;
    return ret;
}

} }

int main() {
    std::cout << "A" << std::endl;
    std::cout << std::hex << ipint_trampoline(5) << std::endl;
    std::cout << "B" << std::endl;
    return 0;
}
