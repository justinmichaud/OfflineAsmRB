#include "LLIntOfflineAsmConfig.h"


int main(int, char**)
{
#include "../build/LLIntDesiredSettings.h"
    printf("%p\n", settingsExtractorTable);
    return 0;
}
