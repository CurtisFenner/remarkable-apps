arm-linux-gnueabihf-gcc -Wall -Wextra -o "built/$1" -I/usr/arm-linux-gnueabihf/include/ \
	framebuffer.c main.c \
	-ldl -lrt -lm \
	 && scp "built/$1" "root@192.168.1.105:/home/root/$1"
