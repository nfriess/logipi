#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <time.h>
#include <signal.h>
#include <sys/socket.h>
#include <netinet/in.h>

// Keep in mind that there is 46 bytes overhead from UDP, IP, eth

// 350 samples, at 16bit 2ch
#define PKT_SIZE 1400
// Need this 126 packets at 44.1khz
#define PKTS_PER_SECOND 126
// Or about a packet every 7.93 ms

static unsigned char buffer[PKT_SIZE+8];


int main(int argc, char ** argv){

	int sockfd, i, pktnum, seconds, ret, sequence;
	struct sockaddr_in destaddr;

	buffer[0] = 0;
	buffer[1] = 0;
	buffer[2] = 0;
	buffer[3] = 0;

	buffer[4] = 0;
	buffer[5] = 0;
	buffer[6] = 0;
	buffer[7] = 0;

	for (i = 8; i < PKT_SIZE+8; i += 4) {

		// Left
		buffer[i] = 0xB1;
		buffer[i+1] = 0xE0;

		// Right
		buffer[i+2] = 0xB1;
		buffer[i+3] = 0xE0;
	}


	sockfd = socket(AF_INET, SOCK_DGRAM, 0);

	destaddr.sin_family = AF_INET;
	destaddr.sin_port = htons(9000);
	destaddr.sin_addr.s_addr = htonl(0x0a02012d);

//	sendto(sockfd, buffer, PKT_SIZE, 0, (struct sockaddr *) &destaddr, sizeof(struct sockaddr_in));
//	return 0;

	sequence = 0;

	// Prime the buffer with 128K of data
	for (pktnum = 0; pktnum < (0x20000/PKT_SIZE); pktnum++) {

	if (pktnum == 0)
		buffer[3] = 0x2;
	else
		buffer[3] = 0;

	buffer[4] = (sequence >> 24) & 0xFF;
	buffer[5] = (sequence >> 16) & 0xFF;
	buffer[6] = (sequence >> 8) & 0xFF;
	buffer[7] = sequence & 0xFF;


		ret = sendto(sockfd, buffer, PKT_SIZE+8, 0, (struct sockaddr *) &destaddr, sizeof(struct sockaddr_in));
		if (ret < PKT_SIZE+8) {
			printf("sendto error %d %d", ret, errno);
			exit(1);
		}
		usleep(100);

		sequence += PKT_SIZE;
	}

	for (seconds = 0; seconds < 10; seconds++) {

		for (pktnum = 0; pktnum < PKTS_PER_SECOND; pktnum++) {

	buffer[4] = (sequence >> 24) & 0xFF;
	buffer[5] = (sequence >> 16) & 0xFF;
	buffer[6] = (sequence >> 8) & 0xFF;
	buffer[7] = sequence & 0xFF;

			ret = sendto(sockfd, buffer, PKT_SIZE+8, 0, (struct sockaddr *) &destaddr, sizeof(struct sockaddr_in));
			if (ret < PKT_SIZE+8) {
				printf("sendto error %d %d", ret, errno);
				exit(1);
			}
			// 7.9365ms = 7937 microeconds
			usleep(7937);

			sequence += PKT_SIZE;
		}
	}

	return 0;
}

