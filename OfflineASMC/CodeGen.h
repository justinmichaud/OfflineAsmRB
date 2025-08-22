#include <string>
#include <memory>
#include <vector>
#include <utility>
#include <cassert>
#include <cstdlib>
#include <cstdlib>
#include <stack>

#include "../Cpp/LLIntOfflineAsmConfig.h"

class Generator {
public:
    virtual std::string generate() const = 0;
};

using Code = std::unique_ptr<Generator>;

class TextGenerator : public Generator {
public:
    TextGenerator(const std::string& text) : text(text) {}

    std::string generate() const override {
        return text;
    }

private:
    std::string text;
};

class Reg : public Generator {
public:
    Reg(const std::string& name) : name(name) {}
    Reg(const Reg& other) : name(other.name)
    {
    }

    std::string generate() const override {
        return name;
    }

private:
    std::string name;
};

class SequenceGenerator : public Generator {
public:
    SequenceGenerator(std::vector<Code> sequence) : sequence(sequence) {}
    SequenceGenerator(std::initializer_list<Code> sequence) : sequence(sequence) {}

    std::string generate() const override {
        std::string result;
        for (const auto& code : sequence) {
            result += code->generate();
        }
        return result;
    }

private:
    std::vector<Code> sequence;
};

template<typename... Args>
inline Code seq(Args&&... args) {
    return std::make_unique<SequenceGenerator>({ std::forward<Args>(args)... });
}

inline Code text(const std::string& expr) {
    return std::make_unique<TextGenerator>(expr);
}

inline Reg reg(const std::string& expr) {
    return std::make_unique<RegGenerator>(expr);
}

class CodeCollectionScope;
static std::stack<std::unique_ptr<CodeCollectionScope>> s_scopes;

class CodeCollectionScope {
public:
    CodeCollectionScope()
    {
        s_scopes.push(std::make_unique<CodeCollectionScope>());
    }
    ~CodeCollectionScope()
    {
        if (s_scopes.top().get() != this) {
            std::exit(1);
        }
        s_scopes.pop();
    }

    void addCode(Code code) {
        codes.push_back(code);
    }

    Code code() const {
        return seq(codes);
    }

private:
    std::vector<Code> codes;
};

#define INSTR(name, impl) \
inline Code name##_impl(std::vector<Code> operands) { \
        return impl; \
    } \
template<typename... Args> \
inline Code name(Args&&... args) { \
    return name##_impl(std::vector<Code>{std::forward<Args>(args)...}); \
} \


INSTR(addp, seq("add", seq(operands), "32"));
INSTR(push, seq("push", seq(operands), "32"));
INSTR(error, [](){std::exit(1); return seq();}());
INSTR(move, seq("move", seq(operands), "32"));
INSTR(pop, seq("pop", seq(operands), "32"));
INSTR(subp, seq("sub", seq(operands), "32"));
INSTR(storepairq, seq("storepairq", seq(operands), "32"));
INSTR(storeq, seq("storeq", seq(operands), "32"));
INSTR(loadpairq, seq("loadpairq", seq(operands), "32"));
INSTR(loadq, seq("loadq", seq(operands), "32"));
INSTR(_break, seq("brk", seq(operands), "32"));
INSTR(jmp, seq("jmp", seq(operands), "32"));
INSTR(ret, seq("ret", seq(operands), "32"));
INSTR(call, seq("call", seq(operands), "32"));
INSTR(bpeq, seq("bpeq", seq(operands), "32"));

#undef INSTR

Code address(Reg reg, int offset) {
    return seq(reg, offset);
}

class Label : public Generator {
public:
    Label(const std::string& name) : name(name) {}

    std::string generate() const override {
        return name;
    }
    
    Label& inFile() {
        m_inFile = true;
        return *this;
    }
    
    Label& global() {
        m_global = true;
        return *this;
    }
    
    Label& aligned(int alignTo) {
        m_alignTo = alignTo;
        return *this;
    }
    
    Label& extern_() {
        m_extern = true;
        return *this;
    }

private:
    std::string name;
    bool m_inFile = false;
    bool m_global = false;
    int m_alignTo = 0;
    bool m_extern = false;
};

std::unique_ptr<Label> label(const std::string& name) {
    return std::make_unique<Label>(name);
}

#define ARM64 1
#define ARM64E 0
#define ARMv7 0
#define X86_64 0
#define RISCV64 0
#define C_LOOP 0

auto invalidGPR = reg("invalid");

auto t0 = reg("x0");
auto t1 = reg("x1");
auto t2 = reg("x2");
auto t3 = reg("x3");
auto t4 = reg("x4");
auto t5 = reg("x5");
auto t6 = reg("x6");
auto t7 = reg("x7");
auto t8 = reg("x8");
auto t9 = reg("x9");
auto t10 = reg("x10");
auto t11 = reg("x11");
auto t12 = reg("x12");
auto cfr = reg("x29");
auto csr0 = reg("x19");
auto csr1 = reg("x20");
auto csr2 = reg("x21");
auto csr3 = reg("x22");
auto csr4 = reg("x23");
auto csr5 = reg("x24");
auto csr6 = reg("x25");
auto csr7 = reg("x26");
auto csr8 = reg("x27");
auto csr9 = reg("x28");
auto csr10 = invalidGPR;
auto sp = reg("sp");
auto lr = reg("lr");

auto& ws0 = t9;
auto& ws1 = t10;
auto& ws2 = t11;
auto& ws3 = t12;

auto& a0 = t0;
auto& a1 = t1;
auto& a2 = t2;
auto& a3 = t3;
auto& a4 = t4;
auto& a5 = t5;
auto& a6 = t6;
auto& a7 = t7;

auto& wa0 = t0;
auto& wa1 = t1;
auto& wa2 = t2;
auto& wa3 = t3;
auto& wa4 = t4;
auto& wa5 = t5;
auto& wa6 = t6;
auto& wa7 = t7;

auto& r0 = t0;
auto& r1 = t1;

using namespace JSC;
using namespace JSC::Wasm;
