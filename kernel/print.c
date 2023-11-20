#include "print.h"
#include <stdint.h>

// Marked as volatile so that the compiler doesn't optimize it out.
volatile uint16_t *video_memory = (uint16_t *)0xb8000;
int cursor = 0;

void *reverse(char *arr, int s, int e) {
  char tmp;
  while (s < e) {
    tmp = arr[s];
    arr[s] = arr[e];
    arr[e] = tmp;
    s++;
    e--;
  }
}

char *ltoa(long int n) {
  static char str[11] = {0};

  int i = 0;
  do {
    str[i++] = n % 10 + '0';
    n /= 10;
  } while (n > 0);
  str[i--] = 0;

  reverse(str, 0, i);

  return str;
}

char *ltoah(long int n) {
  static char *hex = "0123456789abcdef";
  static char str[11] = {0};
  str[0] = '0';
  str[1] = 'x';

  int i = 2;
  do {
    str[i++] = hex[n % 0x10];
    n /= 0x10;
  } while (n > 0);
  str[i--] = 0;

  reverse(str, 2, i);

  return str;
}

void write_char(char c) {
  const int color = 0x0f00;
  video_memory[cursor] = color | c;
  ++cursor;
}

void print(char *str) {
  uint16_t i = 0;
  while (str[i] != 0x0 && i < 80) {
    write_char(str[i]);
    i++;
  }
}

void println(char *str) {
  print(str);
  cursor += 80 - cursor % 80;
}

void clear() {
  for (int i = 0; i < 80 * 25; i++) {
    video_memory[i] = 0x0f00 | ' ';
  }
  cursor = 0;
}
