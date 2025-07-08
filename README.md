# Butaru

Butaru is personal study into operation systems, code organisation and build systems.

### Project Goals

- Create simplistic kernel inspired by XV6
- Support multiple architectures (with QEMU as main target)
- Build system inspired by LK

### Build Instructions

1. Create build-aarch64 directory in butaru root

2. Run make:
  `make qemu` - to compile and run Butaru in Qemu
  `make clean` - cleanup temp files
