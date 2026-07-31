% compile_PolygonClip.m: Script to compile PolygonClip, a function for 
% polygon clipping that is written in C.  This script creates a MEX file and 
% should be run prior to executing model runs.

mex -setup
mex gpc.c gpc_mexfile.c -O -output PolygonClip