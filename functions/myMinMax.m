function[out]=myMinMax(in)
% myMinMax.m: % Returns a 2-element vector with the minimum and maximum of the input vector. This is faster than separately calling the MATLAB built-in functions "min" and "max".
% Input arguments:
%   in: Vector of input values
% Output arguments:
%   out: 2x1 vector with minimum and maxim values of the input vector

    temp=sort(in);
    out=temp([1 end])';
end