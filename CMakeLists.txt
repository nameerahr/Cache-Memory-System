cmake_minimum_required(VERSION 3.16)
project(cache_memory_system CXX)

# Find Verilator
find_package(verilator HINTS ${VERILATOR_ROOT} $ENV{VERILATOR_ROOT})

# SystemC dependencies
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# Find SystemC using SystemC's CMake integration
find_package(SystemCLanguage PATHS ${SYSTEMC_HOME})

# Executable for the cache testbench
add_executable(Vtop_cache_tb tb/top_cache_tb.cpp)

# Set the C++ standard (match SystemC)
set_property(
	TARGET Vtop_cache_tb
	PROPERTY CXX_STANDARD ${SystemC_CXX_STANDARD}
)

# Verilate your Verilog source into C++
verilate(Vtop_cache_tb SYSTEMC COVERAGE TRACE
    INCLUDE_DIRECTORIES "."
    SOURCES
    design/top_cache.v
    design/tag_array.v
    design/data_array.v
    design/cache_controller.v
)


# Link with SystemC
verilator_link_systemc(Vtop_cache_tb)