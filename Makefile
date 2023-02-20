# Location of the CUDA Toolkit
CUDA_PATH ?= /usr/local/cuda

# architecture
HOST_ARCH   := $(shell uname -m)
TARGET_ARCH ?= $(HOST_ARCH)
TARGET_SIZE := $(shell getconf LONG_BIT)


# operating system
HOST_OS   := $(shell uname -s 2>/dev/null | tr "[:upper:]" "[:lower:]")
TARGET_OS ?= $(HOST_OS)

# host compiler
HOST_COMPILER ?= g++
NVCC          := $(CUDA_PATH)/bin/nvcc -ccbin $(HOST_COMPILER)

# internal flags
NVCCFLAGS   := -m${TARGET_SIZE}
CCFLAGS     :=
LDFLAGS     :=

# Debug build flags
ifeq ($(DEBUG),1)
      CCFLAGS += -g -O0
      BUILD_TYPE := debug
else
      BUILD_TYPE := release
endif

ALL_CCFLAGS :=
ALL_CCFLAGS += $(NVCCFLAGS)
ALL_CCFLAGS += $(EXTRA_NVCCFLAGS)
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(CCFLAGS))
ALL_CCFLAGS += $(addprefix -Xcompiler ,$(EXTRA_CCFLAGS))

SAMPLE_ENABLED := 1

ALL_LDFLAGS :=
ALL_LDFLAGS += $(ALL_CCFLAGS)
ALL_LDFLAGS += $(addprefix -Xlinker ,$(LDFLAGS))
ALL_LDFLAGS += $(addprefix -Xlinker ,$(EXTRA_LDFLAGS))

# Common includes and paths for CUDA
INCLUDES := -I$(CUDA_PATH)/include -I$(CUDA_PATH)/targets/x86_64-linux/include
LIBRARIES := -L$(CUDA_PATH)/lib64 -L$(CUDA_PATH)/targets/x86_64-linux/lib

################################################################################

ifeq (,$(filter $(MAKECMDGOALS),clean clobber))

# Gencode arguments
CUDA_VERSION := $(shell cat $(CUDA_PATH)/include/cuda.h |grep "define CUDA_VERSION" |awk '{print $$3}')
CUBLASLT:=true
SM := 86

$(info CUDA VERSION: $(CUDA_VERSION))
$(info TARGET ARCH: $(TARGET_ARCH))
$(info HOST_ARCH: $(HOST_ARCH))
$(info TARGET OS: $(TARGET_OS))
$(info SMS: $(SMS))

ifeq ($(GENCODE_FLAGS),)
# Generate SASS code for your SM architecture.
GENCODE_FLAGS += -gencode arch=compute_$(SM),code=sm_$(SM)
# Generate PTX code from your SM architecture to guarantee forward-compatibility
GENCODE_FLAGS += -gencode arch=compute_$(SM),code=compute_$(SM)
endif

INCLUDES += -IFreeImage/include
LIBRARIES += -LFreeImage/lib/$(TARGET_OS)/$(TARGET_ARCH) -LFreeImage/lib/$(TARGET_OS) -lcudart -lcublas -lcudnn -lfreeimage -lstdc++ -lm -lcublasLt

# Attempt to compile a minimal application linked against FreeImage. If a.out exists, FreeImage is properly set up.
$(shell echo "#include \"FreeImage.h\"" > test.c; echo "int main() { return 0; }" >> test.c ; $(NVCC) $(ALL_CCFLAGS) $(INCLUDES) $(LIBRARIES) -l freeimage test.c)
FREEIMAGE := $(shell find a.out 2>/dev/null)
$(shell rm a.out test.c 2>/dev/null)

ifeq ("$(FREEIMAGE)","")
$(info >>> WARNING - FreeImage is not set up correctly. Please ensure FreeImage is set up correctly. <<<)
SAMPLE_ENABLED := 0
endif


ifeq ($(SAMPLE_ENABLED),0)
EXEC ?= @echo "[@]"
endif

endif
################################################################################

# Target rules
all: build

build: sample

check.deps:
ifeq ($(SAMPLE_ENABLED),0)
	@echo "Sample will be waived due to the above missing dependencies"
else
	@echo "Sample is ready - all dependencies have been met"
endif

SRCS:= $(wildcard src/*.c)
SRCS+= $(wildcard src/*.cpp)

INCS:= $(wildcard src/*.h)
INCS+= $(wildcard src/*.hpp)

OBJS:= $(SRCS:.cpp=.o)

sample: $(OBJS)
	$(EXEC) $(NVCC) $(ALL_LDFLAGS) $(GENCODE_FLAGS) -o $@ $+ $(INCLUDES) $(LIBRARIES)

%.o: %.cpp $(INC)
	$(EXEC) $(HOST_COMPILER) $(INCLUDES) $(CCFLAGS) $(EXTRA_CCFLAGS) -o $@ -c $<

%.o: %.cu $(INC)
	$(EXEC) $(NVCC) $(INCLUDES) $(ALL_CCFLAGS) $(GENCODE_FLAGS) -o $@ -c $<

run: build
	$(EXEC) ./sample

clean:
	rm -rf *o
	rm -rf sample

clobber: clean
