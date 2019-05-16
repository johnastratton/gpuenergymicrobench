# gpuenergymicrobench
Flexible research program to understand GPU energy usage 
runallTestScript.py is the current top-level script
Pretty much all .cu files get used, although individual functions within them may be deprecated.
All tests run through the tester framework in testFramework.cu
To run everything, need to first rename testscripts/analysisConfigTemplate.py to analysisConfig.py 
  and configTemplate.cpp to config.cpp, and configuring them for the particular system you are on.

