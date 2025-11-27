// clang++ -O2 -g test.cc -o test -lbenchmark -std=c++20 -falign-functions=32
// % ~/Development/benchmark/tools/compare.py filters ./test BM_1 BM_3 --benchmark_repetitions=20
// Do not trust progressions/regressions smaller than 5%

#include <benchmark/benchmark.h>

__attribute__((noinline)) int32_t testBranch1(int32_t i, int32_t len) {
    benchmark::DoNotOptimize(i);
    benchmark::DoNotOptimize(len);
    int32_t result = 0;
    int32_t tmp, tmp2;
    __asm__ (
        "cmp      %w[len], %w[i]\n"
        "b.ls     2f\n"
        "mov      %w[res], #1\n"
        "b        3f\n"
        "2:\n"
        "mov      %w[res], #2\n"
        "3:\n"
    : [tmp] "=&r" (tmp)
    , [tmp2] "=&r" (tmp2)
    , [res] "=r" (result)
    : [i] "r" (i)
    , [len] "r" (len)
    :
    );
    return result;
}

void BM_1(benchmark::State& state) {
  for (auto _ : state) {
      for (int64_t i = 0; i < 100000000; i++) {
          testBranch1((i % 10), 7);
      }
  }
}
BENCHMARK(BM_1);

__attribute__((noinline)) int32_t testBranch2(int32_t i, int32_t len) {
    benchmark::DoNotOptimize(i);
    benchmark::DoNotOptimize(len);
    if (i == -1)
        return 2;
    if (i < len)
        return 1;
    __asm__ volatile ("nop");
    return 2;
}

void BM_2(benchmark::State& state) {
  for (auto _ : state) {
      for (int64_t i = 0; i < 100000000; i++) {
          testBranch2((i % 10), 7);
      }
  }
}
BENCHMARK(BM_2);

__attribute__((noinline)) int32_t testBranch3(int32_t i, int32_t len) {
    benchmark::DoNotOptimize(i);
    benchmark::DoNotOptimize(len);
    int32_t result = 0;
    int32_t tmp, tmp2;
    __asm__ (
        "cmn      %w[i], #1\n"
        "cset     %w[tmp], eq\n"
        "cmp      %w[len], %w[i]\n"
        "cset     %w[tmp2], le\n"
        "orr      %w[tmp], %w[tmp], %w[tmp2]\n"
        "cbnz     %w[tmp], 2f\n"
        "1:\n"
        "mov      %w[res], #1\n"
        "b        3f\n"
        "2:\n"
        "mov      %w[res], #2\n"
        "3:\n"
    : [tmp] "=&r" (tmp)
    , [tmp2] "=&r" (tmp2)
    , [res] "=r" (result)
    : [i] "r" (i)
    , [len] "r" (len)
    :
    );
    return result;
}

void BM_3(benchmark::State& state) {
  for (auto _ : state) {
      for (int64_t i = 0; i < 100000000; i++) {
          testBranch3((i % 10), 7);
      }
  }
}
BENCHMARK(BM_3);

__attribute__((noinline)) int32_t testBranch4(int32_t i, int32_t len) {
    benchmark::DoNotOptimize(i);
    benchmark::DoNotOptimize(len);
    if (i == -1)
        return 2;
    if (i < len)
        return 1;
    __asm__ volatile ("nop");
    return 2;
}

void BM_4(benchmark::State& state) {
  for (auto _ : state) {
      for (int64_t i = 0; i < 100000000; i++) {
          testBranch4((i % 10), 7);
      }
  }
}
BENCHMARK(BM_4);

void correctness(benchmark::State& state) {
    for (auto _ : state) {
        for (int i = 0; i < 10; i++) {
            if (testBranch1(i, 7) != (i < 7 ? 1 : 2))
                throw 0;
            if (testBranch2(i, 7) != (i < 7 ? 1 : 2))
                throw 0;
            if (testBranch3(i, 7) != (i < 7 ? 1 : 2))
                throw 0;
            if (testBranch4(i, 7) != (i < 7 ? 1 : 2))
                throw 0;
        }
        if (testBranch1(-1, 7) != 2)
            throw 0;
        if (testBranch2(-1, 7) != 2)
            throw 0;
        if (testBranch3(-1, 7) != 2)
            throw 0;
        if (testBranch4(-1, 7) != 2)
            throw 0;
    }
}
BENCHMARK(correctness);

BENCHMARK_MAIN();
