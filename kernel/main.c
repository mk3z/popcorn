#include "print.h"

void main() {
  println("Kernel booted succesfully.");
  long int p;
  __asm__("mov %%esp, %0" : "=r"(p));
  print("Stack pointer: ");
  println(ltoah(p));
}
