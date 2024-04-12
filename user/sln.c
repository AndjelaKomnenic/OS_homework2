#include "types.h"
#include "stat.h"
#include "user.h"

int main(int argc, char *argv[]) {

    if(argc == 3)
        symlink(argv[1], argv[2]);
        
    exit();
}
