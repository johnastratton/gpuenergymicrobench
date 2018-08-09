#include "arithmeticTests.h"
#include <stdio.h>



//------------------ L1 CACHE KERNELS -----------
template <typename T>
__global__
void l1MemKernel1(int n, int iterateNum, const T *x, T *y) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  __shared__ volatile int index[256];
  index[threadIdx.x] = thread;

  T tot = 0;
  T var;

  for (int i = 0; i < iterateNum; i++) {
    const T *loc = &x[index[threadIdx.x]];
    var = __ldg(loc+n);
    var += var;
    tot += var;
  }
  y[thread] = tot;
  return;
}

template <typename T>
__global__
void l1MemKernel2(int n, int iterateNum, const T *x, T *y) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  __shared__ volatile int index[256];
  index[threadIdx.x] = thread;

  T tot = 0;
  T var;

  for (int i = 0; i < iterateNum; i++) {
    const T *loc = &x[index[threadIdx.x]];
    var = __ldg(loc+n);
    var += __ldg(loc);
    tot += var;
  }
  y[thread] = tot;
  return;
}

//------------------ L2 CACHE KERNEL -----------
template <typename T>
__global__
void l2MemReadKernel1(int n, int iterateNum, volatile T *x) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  T val = 0;
  for (int i = 0; i < iterateNum; i++) {
    val += x[thread];
    val += x[thread];
    val += val;
  }

  x[thread] = val;
  return;

}

template <typename T>
__global__
void l2MemReadKernel2(int n, int iterateNum, volatile T *x) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  T val = 0;
  for (int i = 0; i < iterateNum; i++) {
    val += x[thread];
    val += x[thread];
    val += x[thread];
  }

  x[thread] = val;
  return;
}



//------------------ GLOBAL CACHE KERNELS -----------
template <typename T>
__global__
void globalMemKernel1(int n, int iterateNum, volatile T *x) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  volatile T a = 0;

  for (int i = 0; i < iterateNum; i++) {
    for (int j = 0; j < n; j++) {
      a = x[j];
    }
  }
  x[thread] = a;
}

template <typename T>
__global__
void globalMemKernel2(int n, int iterateNum, volatile T *x) {
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  volatile T a = 0;

  for (int i = 0; i < iterateNum; i++) {
    for (int j = 0; j < n; j++) {
      a = x[j];
    }
  }
  x[thread] = a;
}


//------------------ SHARED MEMORY KERNEL -----------
template <typename T>
__global__
void sharedMemReadKernel1(int n, int iterateNum, volatile T *x) {
  //extern __shared__ volatile T s[]; //volatile to prevent optimization
  __shared__ volatile T s[1024];
  int thread = blockIdx.x*blockDim.x + threadIdx.x;

  s[threadIdx.x] = x[thread];

  volatile T val = 0;
  for (int i = 0; i < iterateNum; i++) {
    val += s[threadIdx.x];
    val += s[threadIdx.x];
    val += s[threadIdx.x];
    val += val;
  }

  x[thread] = val;

  return; 
}

template <typename T>
__global__
void sharedMemReadKernel2(int n, int iterateNum, volatile T *x) {
  //extern __shared__ volatile T s[];
  __shared__ volatile T s[1024];
  int thread = blockIdx.x*blockDim.x + threadIdx.x;
  
  s[threadIdx.x] = x[thread];

  volatile T val = 0;
  for (int i = 0; i < iterateNum; i++) {
    val += s[threadIdx.x];
    val += s[threadIdx.x];
    val += s[threadIdx.x];
    val += s[threadIdx.x];
  }

  x[thread] = val;

  return; 
}


//------------------ INITIALIZE ARRAY FOR KERNEL -----------
template <typename T>
__global__
void createData(int n, T *x) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  // T a = 1.0;
  if (i < n) {
    //x[i] = i;
    x[i] = 0.0f;
  }
}



template <typename T>
class MemoryTestBase {
public: 

  T *d_x;
  int n;
  int iterNum;
  int numBlocks;
  int blockSize;
  int numBlockScale;
  int opsPerIteration; //number of operations in one iteration. Not including loop calculations

  MemoryTestBase(int blockSize, int iterNum)
    : iterNum(iterNum), blockSize(blockSize), numBlockScale(360)
  { opsPerIteration = 0;}
  MemoryTestBase(int blockSize, int iterNum, int numBlockScale)
    : iterNum(iterNum), blockSize(blockSize), numBlockScale(numBlockScale)
  { opsPerIteration = 0;}

  ~MemoryTestBase() {
    CUDA_ERROR( cudaFree(d_x) );
  }

  void kernelSetup(cudaDeviceProp deviceProp) {
    numBlocks = deviceProp.multiProcessorCount * numBlockScale;
    n = numBlocks * blockSize;
    printf("n: %d\n", n);
    CUDA_ERROR( cudaMalloc(&d_x, 2*n*sizeof(T)) ); 
    createData<T><<<numBlocks, blockSize>>>(2*n, d_x);
  }

  //get the number of threads launched in the kernel. Must be 
  //called after kernelSetup() or the neccisary fields may not be initialized
  int getNumThreads() {
    return numBlocks * blockSize;
  }

  //return the number of operations that are executed in the kernel's loop
  //for the specified number of operations.
  //Ex: 6 operations per iteration * 1000000 iterations = 6000000 operations
  int getOpsPerThread() {
    return opsPerIteration * iterNum;
  }

  void runKernel();

  void CUDA_ERROR(cudaError_t e) {
    if (e != cudaSuccess) {
      printf("cuda error in test class: \"%s\"\n", cudaGetErrorString(e));
    }
  } 

};

//----------------------------------------------------------------
//---------------------- MEMORY TEST IMPLEMENTATIONS -------------
//----------------------------------------------------------------


//---------------------- L1 CACHE TESTING CLASSES -------------
template <typename T>
class L1MemTest1 : public MemoryTestBase<T> {
public:

  T *d_y;

  L1MemTest1(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 1;}
  L1MemTest1(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 1;}

  //should call base destructor after executing this destructor
  ~L1MemTest1() { 
    this->CUDA_ERROR(cudaFree(d_y));
  }

  void kernelSetup(cudaDeviceProp deviceProp) {
    MemoryTestBase<T>::kernelSetup(deviceProp);
    this->CUDA_ERROR( cudaMalloc(&d_y, this->n*sizeof(T)) ); 
    createData<T><<<this->numBlocks, this->blockSize>>>(this->n, d_y);
    printf("numblocks %d, blockSize %d, n %d, iterNum %d\n",this->numBlocks, this->blockSize, this->n, this->iterNum);
  }

  void runKernel() {
      l1MemKernel1<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x, d_y);
  }
};

template <typename T>
class L1MemTest2 : public MemoryTestBase<T> {
public:

  T *d_y;

  L1MemTest2(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 2;}
  L1MemTest2(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 2;}

  //should call base destructor after executing this destructor
  ~L1MemTest2() { 
    this->CUDA_ERROR(cudaFree(d_y));
  }

  void kernelSetup(cudaDeviceProp deviceProp) {
    MemoryTestBase<T>::kernelSetup(deviceProp);
    this->CUDA_ERROR( cudaMalloc(&d_y, this->n*sizeof(T)) ); 
    createData<T><<<this->numBlocks, this->blockSize>>>(this->n, d_y);
    printf("numblocks %d, blockSize %d, n %d, iterNum %d\n",this->numBlocks, this->blockSize, this->n, this->iterNum);
  }

  void runKernel() {
      l1MemKernel2<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x, d_y);
  }
};


//---------------------- L2 CACHE TESTING CLASSES -------------
template <typename T>
class L2MemReadTest1 : public MemoryTestBase<T> {
public:
  L2MemReadTest1(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 2;}
  L2MemReadTest1(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 2;}

  void runKernel() {
      l2MemReadKernel1<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
  }
};

template <typename T>
class L2MemReadTest2 : public MemoryTestBase<T> {
public:
  L2MemReadTest2(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 3;}
  L2MemReadTest2(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 3;}

  void runKernel() {
      l2MemReadKernel2<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
  }
};


//---------------------- GLOBAL MEMORY TESTING CLASSES -------------
template <typename T>
class GlobalMemTest1 : public MemoryTestBase<T> {
public:
  GlobalMemTest1(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 2;}
  GlobalMemTest1(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 2;}

  void runKernel() {
      globalMemKernel1<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
  }
};

template <typename T>
class GlobalMemTest2 : public MemoryTestBase<T> {
public:
  GlobalMemTest2(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 4;}
  GlobalMemTest2(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 4;}

  void runKernel() {
      globalMemKernel2<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
  }
};


//---------------------- SHARED MEMORY TESTING CLASSES -------------
template <typename T>
class SharedMemReadTest1 : public MemoryTestBase<T> {
public:

  unsigned int sharedMemRequest;

  SharedMemReadTest1(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 3;}
  SharedMemReadTest1(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 3;}

  //in addition to normal setup, figure out how much shared memory to request
  void kernelSetup(cudaDeviceProp deviceProp) {
    MemoryTestBase<T>::kernelSetup(deviceProp);
    sharedMemRequest = (unsigned int) (this->n * sizeof(T));
  }


  void runKernel() {
    sharedMemReadKernel1<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
  }
};

template <typename T>
class SharedMemReadTest2 : public MemoryTestBase<T> {
public:

  unsigned int sharedMemRequest;

  SharedMemReadTest2(int blockSize, int iterNum) 
      : MemoryTestBase<T>(blockSize, iterNum) 
  {this->opsPerIteration = 4;}
  SharedMemReadTest2(int blockSize, int iterNum, int numBlockScale) 
      : MemoryTestBase<T>(blockSize, iterNum, numBlockScale) 
  {this->opsPerIteration = 4;}

  //in addition to normal setup, figure out how much shared memory to request
  void kernelSetup(cudaDeviceProp deviceProp) {
    MemoryTestBase<T>::kernelSetup(deviceProp);
    sharedMemRequest = (unsigned int) (this->n * sizeof(T));
    //printf("  numBlocks %d, n %d \n", this->numBlocks, this->n);
    //printf("  sharedMemRequest %d\n", sharedMemRequest);
  }


  void runKernel() {
    sharedMemReadKernel2<T><<<this->numBlocks, this->blockSize>>>(this->n, this->iterNum, this->d_x);
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess)
      printf("  Error: %s\n", cudaGetErrorString(err));

  }
};
