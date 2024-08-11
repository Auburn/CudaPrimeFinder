#include <chrono>
#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cuda_runtime.h>
#include <iomanip>
#include <sstream>
#include <random>
#include <algorithm>

#define HASH_RANGE 23
#define HASH_RANGE_SQUARED (HASH_RANGE * HASH_RANGE)

using uint = unsigned int;

// CUDA kernel to compute the hashes
__global__ void computeHashes( int* d_primes, int primeCount, uint* d_topHashes, int* d_topPrime1 )
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if( i >= primeCount ) return;

    int xorResults[HASH_RANGE_SQUARED];
    int prime1 = d_primes[i];
    uint topHashQuality = 0;
    int topPrime = 0;
    
    int halfPrimeCount = primeCount / 2;
    for( int j = 1; j <= halfPrimeCount; ++j )
    {
        int prime2 = d_primes[(i + j) % primeCount];
        uint hashQuality = 0;
        int resultIndex = 0;
        int xorBase = 0;

        for( int k = 0; k < HASH_RANGE; ++k )
        {
            int xorAdd = 0;
            for( int l = 0; l < HASH_RANGE; ++l )
            {
                xorResults[resultIndex++] = xorBase ^ xorAdd;
                xorAdd += prime2;
            }
            xorBase += prime1;
        }

        for( int m = 0; m < HASH_RANGE_SQUARED - 1; ++m )
        {
            for( int n = m + 1; n < HASH_RANGE_SQUARED; ++n )
            {
                unsigned int xorR = xorResults[m] ^ xorResults[n];
                hashQuality += __popc( xorR );
                hashQuality += __popc( xorR << 24 );
            }
        }

        if( hashQuality > topHashQuality )
        {
            topHashQuality = hashQuality;
            topPrime = prime2;
        }
    }

    d_topHashes[i] = topHashQuality;
    d_topPrime1[i] = topPrime;
}

int main()
{
    int cudeDev = 0;
    cudaSetDevice(cudeDev);
    // Get and print some information about the selected device
    cudaDeviceProp deviceProp;
    cudaGetDeviceProperties(&deviceProp, cudeDev);
    std::cout << "Using CUDA Device : " << deviceProp.name << std::endl;

    std::vector<int> primes;
#if 0
    for( int fileIndex = 3; fileIndex <= 10; ++fileIndex )
    {
        std::ifstream file( "./primes" + std::to_string( fileIndex ) + ".txt" );
#else
    {
        std::ifstream file( "./top-percentile-primes.txt" );
#endif
        std::string line;
        while( std::getline( file, line ) )
        {
            size_t pos = 0;
            while( ( pos = line.find( '\t' ) ) != std::string::npos )
            {
                primes.push_back( std::stoi( line.substr( 0, pos ) ) );
                line.erase( 0, pos + 1 );
            }
            if( !line.empty() )
            {
                primes.push_back( std::stoi( line ) );
            }
        }
    }

    std::cout << "Loaded Primes: " << primes.size() << std::endl;

    // Randomly sort the primes vector
    std::random_device rd;
    std::mt19937 g(rd());
    std::shuffle(primes.begin(), primes.end(), g);

    std::cout << "Primes randomly sorted." << std::endl;

    int primeCount = primes.size();
    std::vector<uint> topHashes( primeCount, 0 );
    std::vector<int> topPrime1( primeCount, 0 );

    int* d_primes;
    uint* d_topHashes;
    int* d_topPrime1;
    cudaMalloc( (void**)&d_primes, primeCount * sizeof( int ) );
    cudaMalloc( (void**)&d_topHashes, primeCount * sizeof( uint ) );
    cudaMalloc( (void**)&d_topPrime1, primeCount * sizeof( int ) );

    cudaMemcpy( d_primes, primes.data(), primeCount * sizeof( int ), cudaMemcpyHostToDevice );
    cudaMemcpy( d_topHashes, topHashes.data(), primeCount * sizeof( uint ), cudaMemcpyHostToDevice );
    cudaMemcpy( d_topPrime1, topPrime1.data(), primeCount * sizeof( int ), cudaMemcpyHostToDevice );

    float time;
    cudaEvent_t start, stop;
    cudaEventCreate( &start );
    cudaEventCreate( &stop );
    cudaEventRecord( start, 0 );

    int blockSize;      // The launch configurator returned block size 
    int minGridSize;    // The minimum grid size needed to achieve the maximum occupancy for a full device launch 
    int gridSize;       // The actual grid size needed, based on input size 

    cudaOccupancyMaxPotentialBlockSize( &minGridSize, &blockSize, computeHashes, 0, 0 );

    // Round up according to array size 
    gridSize = ( primeCount + blockSize - 1 ) / blockSize;

    cudaEventRecord( stop, 0 );
    cudaEventSynchronize( stop );
    cudaEventElapsedTime( &time, start, stop );
    printf( "Occupancy calculator elapsed time:  %.3f s \n", time / 1000 );
    printf( "Blocksize %i\n", blockSize );

#if 1
    // Round up according to array size 
    int testCount = 4096;
    int testGridSize = ( testCount + blockSize - 1 ) / blockSize;

    cudaEventRecord( start, 0 );

    computeHashes << <testGridSize, blockSize >> > ( d_primes, primeCount, d_topHashes, d_topPrime1 );

    cudaEventRecord( stop, 0 );
    cudaEventSynchronize( stop );
    cudaEventElapsedTime( &time, start, stop );
    printf( "Test Kernel elapsed time:  %.3f s \n", time / 1000 );
    printf( "Estimated full time:  %.3f h \n", time / (1000 * 60 * 60) * ((float)primeCount / testCount) );
#endif

    cudaEventRecord( start, 0 );

    computeHashes << <gridSize, blockSize >> > ( d_primes, primeCount, d_topHashes, d_topPrime1 );

    cudaEventRecord( stop, 0 );
    cudaEventSynchronize( stop );
    cudaEventElapsedTime( &time, start, stop );
    printf( "Kernel elapsed time:  %.3f h \n", time / ( 1000 * 60 * 60 ) );

    cudaMemcpy( topHashes.data(), d_topHashes, primeCount * sizeof( uint ), cudaMemcpyDeviceToHost );
    cudaMemcpy( topPrime1.data(), d_topPrime1, primeCount * sizeof( int ), cudaMemcpyDeviceToHost );

    cudaFree( d_primes );
    cudaFree( d_topHashes );
    cudaFree( d_topPrime1 );

    std::cout << "All Complete!" << std::endl;

    auto now = std::chrono::system_clock::now();
    auto now_c = std::chrono::system_clock::to_time_t( now );
    std::stringstream ss;
    ss << std::put_time( std::localtime( &now_c ), "%Y%m%d_%H%M%S" );
    std::string timestamp = ss.str();
    std::string filename = "output_" + timestamp + ".csv";
    std::ofstream outFile( filename );

    outFile << "Diff Bits,Prime1,Prime2\n";
    for (int i = 0; i < primeCount; ++i) {
        outFile << topHashes[i] << "," << primes[i] << "," << topPrime1[i] << "\n";
    }
    outFile.close();

    // Pause execution and wait for user input
    std::cout << "Press Enter to continue...";
    std::cin.get();

    return 0;
}
