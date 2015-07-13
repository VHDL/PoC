/*
 * The MAC address of the PC is determined automatically.
 * The MAC address of the FPGA board is derived from that by replacing 
 * the first byte with 0x02.
 */
 
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <linux/if_arp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sched.h>
#include <pthread.h>
#include <jni.h>
#include "libTraceEth.h"

#ifndef ETH_FRAME_LEN
// commonly defined through linux/if_arp.h
#  define ETH_DATA_LEN 1500
#  define ETH_FRAME_LEN 1514
#endif

#define ALLOC_CNT 100000

// Implementierungsinspiration von
//
// Rauber, Rünger
// Parallele und verteilte Programmierung

pthread_t thread_r, thread_s;

typedef struct work {
  int length;
  struct work *next;
  unsigned char buffer[ETH_DATA_LEN];
} work_t;

int volatile receiveCnt, storeCnt;

char const *ifname = "eth0";

pthread_cond_t filled_avl_cond;
pthread_cond_t filled_empty_cond;
pthread_cond_t alloc_avl_cond;
pthread_cond_t rsp_msg_cond;

volatile int current_filled;
work_t *volatile filled_head = NULL;
work_t *volatile filled_tail = NULL;
pthread_mutex_t filled_lock;

volatile int current_alloc;
work_t *volatile alloc_head = NULL;
work_t *volatile alloc_tail = NULL;
pthread_mutex_t alloc_lock;

work_t *volatile rsp_msg = NULL;
pthread_mutex_t rsp_msg_lock;

int volatile filepointer;
int fileopened = 0;

/* socketdescriptor */
struct sockaddr_ll sa;
struct sockaddr_ll ra;
socklen_t ralen = 0;
int send_socket;
int recv_socket;

unsigned char* send_buffer;

/*
 * Open the current trace-file.
 */
void openFile(char const *filename){

  /* initialize file */
  if((filepointer = open(filename, O_WRONLY | O_EXCL , S_IRWXU | S_IRWXG | S_IRWXO)) == -1){
    fprintf(stderr, "Error: Could not create file %s!\n",filename);
    exit(EXIT_FAILURE);
  }
  fileopened = 1;
}

/*
 * Close the current trace-file.
 */
void closeFile(){

  /* close file */
  if (fileopened == 1){
    if(close(filepointer) == -1)
      fprintf(stderr, "Error: Could not close the file!\n");
    fileopened = 0;
  }

}

/*
 * Append a buffer to the free-list.
 */
void appendBufferToFreeList(work_t *wl){
  wl->next = NULL;

  /* append buffer to free-list */
  pthread_mutex_lock(&alloc_lock);
  if (current_alloc == 0) {
    alloc_head = wl;
    alloc_tail = wl;
    pthread_cond_signal(&alloc_avl_cond);
  } else {
    alloc_tail->next = wl;
    alloc_tail = wl;
  }
  current_alloc++;
  pthread_mutex_unlock(&alloc_lock);
}

/*
 * Allocate receive buffers.
 * These buffers are freed upon program exit, because free() (from the JVM?)
 * seems not to be thread safe.
 */
void allocateBuffers(){
  unsigned int cnt=ALLOC_CNT;
  while(cnt-->0) {
    work_t *wl;

    /* create a buffer */
    wl = (work_t *)malloc(sizeof(work_t));
    wl->length = 0;
    wl->next = NULL;

    /* append buffer to alloc-list */
    appendBufferToFreeList(wl);
  }
}


/*
 * Initialize the ethernet-connection.
 */
void initializeEthernetConnection(){

  /* do we have the rights to do that? */
  if (getuid() && geteuid()) {
    fprintf(stderr, "Error: No su rights!\n");
    exit(1);
  }

  /* initialize ethernet-connection */

  /////////////////
  /* Transmitter */
  /////////////////

  fprintf(stderr, "Initializing Transmitter.\n");

  send_socket = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
  
  if (send_socket == -1) {
    fprintf(stderr, "Error: Could not open socket for transmitter!");
    exit(1);
  }
  fprintf(stderr, "Successfully opened socket with ID '%d' for transmitting\n", send_socket);
	
  /* Find the the source MAC address */
  struct ifreq ifr;
  bzero(&ifr, sizeof(struct ifreq));
  strncpy(ifr.ifr_name, ifname, sizeof(ifname));
  if (ioctl(send_socket, SIOCGIFHWADDR, &ifr) == -1) {
    fprintf(stderr, "Error: Could not read local MAC address!\n");
    exit(EXIT_FAILURE);
  }
  fprintf(stderr, "Used interface: %s, MAC: ", ifname);
  {
    int i;
    for (i=0; i<6; i++) {
      fprintf(stderr, "%02X", (unsigned char)ifr.ifr_hwaddr.sa_data[i]);
      if (i < 5) fprintf(stderr, ":");
    }
    fprintf(stderr, "\n");
  }

  int ifindex;
  if ((ifindex = if_nametoindex(ifname)) == 0) {
    fprintf(stderr, "Error: Could not read address of interface '%s'!\n", ifname);
     exit(EXIT_FAILURE);
  }
  fprintf(stderr, "Interface index: %d\n", ifindex);

  /*prepare send buffer*/
  send_buffer = (unsigned char*)malloc(ETH_FRAME_LEN);

  memcpy(send_buffer, ifr.ifr_hwaddr.sa_data, 6);
  send_buffer[0] = 0x02; // Derived board MAC, also used for 'ra' below
  memcpy(send_buffer+6, ifr.ifr_hwaddr.sa_data, 6); // PC MAC
  send_buffer[12] = 0x51; 
  send_buffer[13] = 0x80;

  send_buffer[14] = 0xFF; // ticket

  memset(&sa, 0, sizeof (sa));
  sa.sll_family    = AF_PACKET;
  sa.sll_ifindex   = ifindex;
  sa.sll_protocol  = htons(ETH_P_ALL);
	
  fprintf(stderr, "Transmitter ready...\n");

  //////////////
  /* Receiver */
  //////////////

  fprintf(stderr, "Initializing Receiver.\n");

  /*open socket*/
  recv_socket = socket(AF_PACKET, SOCK_DGRAM, htons(ETH_P_ALL));
  if (recv_socket == -1) {
    fprintf(stderr, "Error: Could not open socket for receiver!");
    exit(EXIT_FAILURE);
  }
  fprintf(stderr, "Successfully opened socket with ID '%d' for receiving\n", recv_socket);

        
  memset(&ra, 0, sizeof(ra));
  ra.sll_family    = AF_PACKET;
  ra.sll_ifindex   = ifindex;
  ra.sll_protocol  = htons(0x5180);
  memcpy(ra.sll_addr, send_buffer, 6);

  if (bind(recv_socket, (struct sockaddr *)&ra, sizeof(ra)) == -1) {
    fprintf(stderr, "Error: Could not bind socket for receiver!\n");
    exit(EXIT_FAILURE);
  }

  /* ready */
  fprintf(stderr, "Receiver ready...\n");
}

/*
 * Receive an ethernet-packet.
 */
void *t_recv(void *v){

  int ticket = 0;
  int cnt;

  int recvticket;
  int messageType;

  /* Wait for incoming packet... */

  work_t *wl;

  while (1) {

    /* get a new buffer */
    pthread_mutex_lock(&alloc_lock);
    while(current_alloc == 0){
      pthread_cond_wait(&alloc_avl_cond, &alloc_lock);
    }

    wl = alloc_head;
    current_alloc--;
    if (current_alloc == 0){
      alloc_head = NULL;
      alloc_tail = NULL;
    } else {
      alloc_head = wl->next;
    }

    pthread_mutex_unlock(&alloc_lock);
    wl->next = NULL;

    cnt = recvfrom(recv_socket, wl->buffer, ETH_DATA_LEN, 0, (struct sockaddr *)&ra, &ralen);
    receiveCnt++;

    if (-1 == cnt) {
      fprintf(stderr, "Error: Could not receive data!\n");
      exit(EXIT_FAILURE);
    }

    recvticket = wl->buffer[0] & 0x7F;
    messageType = wl->buffer[0] & 0x80;

    if (recvticket != ticket){
      fprintf(stderr, "Error: Packet %d. Ticket %d expected. Ticket %d received.\n", receiveCnt, ticket, recvticket);
      exit(EXIT_FAILURE);
    }

    wl->length = cnt;
    ticket = (ticket + 1)%128;
    if((messageType)>0){

      /* received a system response */
      //fprintf(stderr, "Receiver received a system response!\n");
      pthread_mutex_lock(&rsp_msg_lock);
      rsp_msg = wl; 
      pthread_cond_signal(&rsp_msg_cond);
      pthread_mutex_unlock(&rsp_msg_lock);

    } else {

      /* received a trace-message */
      //fprintf(stderr, "Receiver received a trace-message!\n");
      pthread_mutex_lock(&filled_lock);
      if(current_filled == 0){
        filled_head = wl;
        filled_tail = wl;
        pthread_cond_signal(&filled_avl_cond);
      } else {
        filled_tail->next = wl;
        filled_tail = wl;
      }
      current_filled++;
      pthread_mutex_unlock(&filled_lock);

    }
  }
}

/*
 * Write buffer to hard-disk.
 */
void *t_store(void *v){

  work_t *wl;

  while(1){

    /* get buffer from filled-list */
    pthread_mutex_lock(&filled_lock);
    if (current_filled == 0){
      pthread_cond_signal(&filled_empty_cond);
    }
    while(current_filled == 0){
      pthread_cond_wait(&filled_avl_cond, &filled_lock);
    }
    wl = filled_head;
    current_filled--;
    if(current_filled == 0){
      filled_head = NULL;
    }else{
      filled_head = wl->next;
    }
    pthread_mutex_unlock(&filled_lock);

    /* write buffer to memory */
    if(write(filepointer, (wl->buffer)+1, (wl->length)-1) == -1) {
      fprintf(stderr, "Error: Could not write file!\n");
      exit(1);
    }
    storeCnt++;

    /* append buffer to free-list */
    appendBufferToFreeList(wl);

  }
}

/*
 * Initialize threads and variables.
 */
JNIEXPORT void JNICALL Java_ite_traceEth_TraceEth_initialize (JNIEnv *env, jclass c){

  initializeEthernetConnection();

  // initialize receiver-threads and allocate packets

  receiveCnt = 0;
  storeCnt = 0;

  current_filled = 0;
  current_alloc = 0;

  /* process-priority */
  struct sched_param param;
  sched_getparam(getpid(), &param);
  param.sched_priority = 99;
  sched_setscheduler(getpid(), SCHED_FIFO, &param);
  sched_getparam(getpid(), &param);
  fprintf(stderr, "Set priority to: %d\n", param.sched_priority);

  /* initialize threads and set thread-priority */
  pthread_attr_t attr_r;
  pthread_attr_t attr_s;
  struct sched_param param_r;
  struct sched_param param_s;

  alloc_head = NULL;
  alloc_tail = NULL;
  filled_head = NULL;
  filled_tail = NULL;

  pthread_mutex_init(&filled_lock, NULL);
  pthread_mutex_init(&alloc_lock, NULL);
  pthread_mutex_init(&rsp_msg_lock, NULL);
  pthread_cond_init(&filled_avl_cond, NULL);
  pthread_cond_init(&filled_empty_cond, NULL);
  pthread_cond_init(&alloc_avl_cond, NULL);
  pthread_cond_init(&rsp_msg_cond, NULL);

  if(sysconf(_SC_THREAD_PRIORITY_SCHEDULING) == -1){
    fprintf(stderr, "Error: No priority-scheduling is possible!\n");
    exit(1);
  }
  pthread_attr_init(&attr_r);
  pthread_attr_init(&attr_s);
  pthread_attr_getschedparam(&attr_r, &param_r);
  pthread_attr_getschedparam(&attr_s, &param_s);

  pthread_attr_setschedpolicy(&attr_r, SCHED_FIFO);
  pthread_attr_setschedpolicy(&attr_s, SCHED_FIFO);

  param_r.sched_priority = sched_get_priority_max(SCHED_FIFO);
  param_s.sched_priority = sched_get_priority_min(SCHED_FIFO);

  pthread_attr_setschedparam(&attr_r, &param_r);
  pthread_attr_setschedparam(&attr_s, &param_s);

  int policy_r;
  int policy_s;

  pthread_attr_getschedpolicy(&attr_r, &policy_r);
  pthread_attr_getschedpolicy(&attr_s, &policy_s);
  pthread_attr_getschedparam(&attr_r, &param_r);
  pthread_attr_getschedparam(&attr_s, &param_s);
  fprintf(stderr, "Receive-Thread:  Policy %d, Priority %d \n", policy_r, param_r.sched_priority);
  fprintf(stderr, "Store-Thread:    Policy %d, Priority %d \n", policy_s, param_s.sched_priority);

  /* create threads */
  pthread_create(&thread_r, &attr_r, t_recv, NULL);
  pthread_create(&thread_s, &attr_s, t_store, NULL);

  pthread_attr_destroy(&attr_r);
  pthread_attr_destroy(&attr_s);

  /* Allocate receive buffers */
  allocateBuffers();   
}

/*
 * Initialize trace-receiver.
 */
JNIEXPORT void JNICALL Java_ite_traceEth_TraceEth_initializeTraceReceiver (JNIEnv *env, jclass s, jstring filename, jbyteArray arr){

  /* filename for tracefile */
  char const *filenameC = (*env)->GetStringUTFChars(env, filename, NULL);

  openFile(filenameC);

  /* write config to file */
  
  jsize arrayLength = (*env)->GetArrayLength(env, arr);

  unsigned char* config_buffer = (unsigned char*)malloc(arrayLength);

  (*env)->GetByteArrayRegion(env, arr, 0, arrayLength, config_buffer);

  if(write(filepointer, config_buffer, arrayLength) == -1) {
    fprintf(stderr, "Error: Could not write file!\n");
    exit(1);
  }
  free(config_buffer);
}

JNIEXPORT void JNICALL Java_ite_traceEth_TraceEth_finish (JNIEnv *env, jclass c){
  fprintf(stderr, "Finishing.\n");


  fprintf(stderr, "Received  %d packets\n", receiveCnt);
  fprintf(stderr, "Stored    %d buffers\n", storeCnt);

  closeFile();

}

JNIEXPORT void JNICALL Java_ite_traceEth_TraceEth_flush (JNIEnv *env, jclass c){
  fprintf(stderr, "Flushing.\n");
  
  /* wait for fill-list to get empty */
  pthread_mutex_lock(&filled_lock);
  while(current_filled != 0){
    pthread_cond_wait(&filled_empty_cond, &filled_lock);
  }
  pthread_mutex_unlock(&filled_lock);

  closeFile();
}

/*
 * Receive command from java-system and wait for receiving answer.
 */
JNIEXPORT jbyteArray JNICALL Java_ite_traceEth_TraceEth_sendAndReceive (JNIEnv *env, jclass c, jbyteArray arr){

  fprintf(stderr, "Prepare message.\n");
  
  jsize arrayLength = (*env)->GetArrayLength(env, arr);
  // check length, exlusive ticket
  if(arrayLength>(ETH_DATA_LEN-1)) {
    fprintf(stderr,"WARNING: Message to large (%d bytes). Truncated.\n",(int)arrayLength);
    arrayLength = ETH_DATA_LEN-1;
  }
  (*env)->GetByteArrayRegion(env, arr, 0, arrayLength, send_buffer+15);

  // update ticket
  send_buffer[14] = (send_buffer[14]+1)%256;

  fprintf(stderr, "Send message with length %d.\n", arrayLength);		
  if (-1 == sendto(send_socket, send_buffer, ETH_FRAME_LEN, 0, (struct sockaddr *)&sa, sizeof(sa))) {
    fprintf(stderr, "Error: Could not send message!\n");
  }

  fprintf(stderr, "Wait for answer.\n");		
  work_t *wl;
  pthread_mutex_lock(&rsp_msg_lock);
  while(rsp_msg == NULL){
    pthread_cond_wait(&rsp_msg_cond, &rsp_msg_lock);
  }
  wl = rsp_msg;
  rsp_msg = NULL;
  pthread_mutex_unlock(&rsp_msg_lock);

  jbyteArray result = (*env)->NewByteArray(env,wl->length-1);
  (*env)->SetByteArrayRegion(env, result, 0, (wl->length)-1, (jbyte *)((wl->buffer)+1));

  /* append buffer to free-list */
  appendBufferToFreeList(wl);

  fprintf(stderr, "Return.\n");

  return result;

}
