# DSP Library CMakeLists.txt
# Pure C++20 — no Qt dependency

cmake_minimum_required(VERSION 3.24)

add_library(dsp STATIC
    src/FilterSpec.cpp
    src/BilinearTransform.cpp
    src/Butterworth.cpp
    src/Chebyshev.cpp
    src/Elliptic.cpp
    src/Bessel.cpp
    src/Fir.cpp
    src/FilterCoefficients.cpp
    src/FilterDesigner.cpp
    src/FilterAnalysis.cpp
    src/SignalProcessor.cpp
    src/CodeExporter.cpp
    src/WavReader.cpp
    src/CsvReader.cpp
)

target_include_directories(dsp
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_compile_features(dsp PUBLIC cxx_std_20)

if(MSVC)
    target_compile_options(dsp PRIVATE /W4 /WX)
    target_compile_definitions(dsp PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
    target_compile_options(dsp PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(BUILD_TESTING)
    add_executable(dsp_tests tests/FilterMathTests.cpp)
    target_link_libraries(dsp_tests PRIVATE dsp)
    add_test(NAME dsp_math COMMAND dsp_tests)
endif()

