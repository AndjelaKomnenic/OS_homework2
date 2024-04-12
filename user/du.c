#ifndef NULL
#define NULL ((void*)0)
#endif
#include "types.h"
#include "stat.h"
#include "user.h"
#include "fcntl.h"
#include "fs.h"

#define MAX_PATH 512
#define BSIZE 512 

char*
fmtname(char *path)
{
	static char buf[DIRSIZ+1];
	char *p;

	// Find first character after last slash.
	for(p=path+strlen(path); p >= path && *p != '/'; p--)
		;
	p++;

	// Return blank-padded name.
	if(strlen(p) >= DIRSIZ)
		return p;
	memmove(buf, p, strlen(p));
	memset(buf+strlen(p), ' ', DIRSIZ-strlen(p));
	return buf;
}

int printDiskUsage(char *path, int *grandTotal) {
    char buf[MAX_PATH];
    int fd;
    struct dirent de;
    struct stat st;
    int total = 0;

    if (stat(path, &st) < 0) {
        printf("du: cannot stat %s\n", fmtname(path));
        return -1;
    }

    total = st.blocks;

    if (st.type == T_DIR) {
        printf("%s %d\n", fmtname(path), total);

        if ((fd = open(path, O_RDONLY)) < 0) {
            printf("du: cannot open directory %s\n", fmtname(path));
            return -1;
        }

        strcpy(buf, path);
        char *p = buf + strlen(buf);
        *p++ = '/';
        
        while(read(fd, &de, sizeof(de)) == sizeof(de)) {
            if (de.inum == 0 || strcmp(de.name, ".") == 0 || strcmp(de.name, "..") == 0)
                continue;
            memmove(p, de.name, strlen(de.name));
            p[strlen(de.name)] = 0;
            int res = printDiskUsage(buf, NULL); 
            if (res >= 0) {
                total += res; 
            }
        }
        close(fd);
        
    } else { 
        printf("%s %d\n", fmtname(path), total);
    }

    if (grandTotal) {
        *grandTotal += total;
    }

    return total; 
}

int main(int argc, char *argv[]) {
    
    int grandTotal = 0;
    if (argc < 2) {
        printDiskUsage(".", &grandTotal);
        printf("total          %d\n", grandTotal);
        exit();
    }

    for (int i = 1; i < argc; i++) {
        printDiskUsage(argv[i], &grandTotal);
    }

    if (argc >= 2) {
        printf("total          %d\n", grandTotal);
    }

    exit();
}

/* Lepsa verzija :)

int printDiskUsage(char *path, int *grandTotal) {
    char buf[MAX_PATH];
    int fd;
    struct dirent de;
    struct stat st;
    int total = 0;

    if (stat(path, &st) < 0) {
        printf("du: cannot stat %s\n", path);
        return -1;
    }

    total = st.blocks;

    if (st.type == T_DIR) {
        printf("%s %d\n", path, total);

        if ((fd = open(path, O_RDONLY)) < 0) {
            printf("du: cannot open directory %s\n", path);
            return -1;
        }

        strcpy(buf, path);
        char *p = buf + strlen(buf);
        *p++ = '/';
        
        while(read(fd, &de, sizeof(de)) == sizeof(de)) {
            if (de.inum == 0 || strcmp(de.name, ".") == 0 || strcmp(de.name, "..") == 0)
                continue;
            memmove(p, de.name, strlen(de.name));
            p[strlen(de.name)] = 0;
            int res = printDiskUsage(buf, NULL); 
            if (res >= 0) {
                total += res; 
            }
        }
        close(fd);
        
    } else { 
        printf("%s %d\n", path, total);
    }

    if (grandTotal) {
        *grandTotal += total;
    }

    return total; 
}


*/