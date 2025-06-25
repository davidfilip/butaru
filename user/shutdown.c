#include "kernel/types.h"
#include "user/user.h"

int main(void) {
  shutdown();
  exit(1); // never reached
}
