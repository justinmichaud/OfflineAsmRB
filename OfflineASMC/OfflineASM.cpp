#include "CodeGen.h"

Code body();

int main(int, char**)
{
    puts(body()->generate().c_str());
    return 0;
}
