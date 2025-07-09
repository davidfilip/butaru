#include "kernel/types.h"
#include "system/user.h"

int main(void) {
  shutdown();
  exit(1); // never reached
}
