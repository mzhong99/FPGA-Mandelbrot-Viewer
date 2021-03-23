#include <stdio.h>
#include <stdint.h>

#define WIDTH   400
#define HEIGHT  300

void addr_to_rowcol(uint32_t addr)
{
    uint32_t expected_row = addr / WIDTH;
    uint32_t expected_col = addr % WIDTH;

    uint32_t row = ((addr << 8) + (addr << 6) + (addr << 3)) >> 17;
    
    if (row != expected_row)
        printf("row mismatch: addr=%u, expected=%u, actual=%u\n",
                addr, expected_row, row);
}

void rowcol_to_addr(uint32_t row, uint32_t col)
{
    uint32_t expected_addr = (row * WIDTH) + col;
    uint32_t addr = (row << 8) + (row << 7) + (row << 4) + col;

    printf("%u\n", addr);

    if (addr != expected_addr)
        printf("addr mismatch: row=%u, col=%u, expect=%u, actual=%u\n",
                row, col, expected_addr, addr);
}

int main()
{
    for (uint32_t row = 0; row < HEIGHT; row++)
        for (uint32_t col = 0; col < WIDTH; col++)
            rowcol_to_addr(row, col);

    printf("done\n");
}
