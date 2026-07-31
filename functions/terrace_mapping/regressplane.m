function [sl,az,error]=regressplane(x,y,z)
% regressplane.m: Fits a plane to elevation data using linear regression.
% This code was developed by Kevin Lewis and Oded Aharonson at Caltech.
% Input argments:
%   x: x-coordinates of input elevation data
%   y: y-coordinates of input elevation data
%   z: z-coordidnates of input elevation data
% Output arguments:
%   sl: slope of the fittied plane (degrees)
%   az: azimuth of the fitted plane (degrees)
%   error: error in the orientation of the normal vector to the plane
%   (degrees)

% regress solves y=bX. Here, 'y' is z and 'X' is made of the three columns
%of the x vector, the y vector, and a column of ones for the constant term.
% Calculates error of normal vector.
 
X=[x(:) y(:) ones(size(y))];
[B,BINT] = regress(z,X,.05); %alpha=.32 corresponds to a 68% confidence interval (1 sigma for normal distribution)
%[b2,stats2]=robustfit(X,z);

sl=180/pi*atan((B(1)^2+B(2)^2)/(sqrt(B(1)^2+B(2)^2)));
az=180/pi*atan2(-B(2),-B(1));

error(1)=acosd(dot([B(1),B(2),1],[BINT(1,1) BINT(2,1) 1])/(norm([B(1),B(2), ...
		    1])*norm([BINT(1,1) BINT(2,1) 1])));
error(2)=acosd(dot([B(1),B(2),1],[BINT(1,1) BINT(2,2) 1])/(norm([B(1),B(2), ...
		    1])*norm([BINT(1,1) BINT(2,2) 1])));
error(3)=acosd(dot([B(1),B(2),1],[BINT(1,2) BINT(2,1) 1])/(norm([B(1),B(2), ...
		    1])*norm([BINT(1,2) BINT(2,1) 1])));
error(4)=acosd(dot([B(1),B(2),1],[BINT(1,2) BINT(2,2) 1])/(norm([B(1),B(2), ...
		    1])*norm([BINT(1,2) BINT(2,2) 1])));

error=max(error);