function [Rc] = circle_only(X,Y)
% circle_only.m: Calculates radius of curvature between sets of three points by fitting a circle.
% Modified from points2circle.m by Jos van der Geest (jos@jasen.nl), 
% available from the MATLAB File Exchange at http://www.mathworks.com/matlabcentral/fileexchange/19082-points2circle.
% Input arguments:
%   X: x-coordinates of a channel centerline
%   Y: y-coordinates of channel centerline
% Output arguments:
%   Rc: radius of curvature along channel centerline

	S=numel(X);
    Rc=zeros(S,1);   
    
    % create ghost points before first point and after last point for
    % calculating radius of curvature
    pt_0_xy = [X(1)-(X(end)-X(end-1)),Y(1)-(Y(end)-Y(end-1))];
    pt_Splus1_xy = [X(end)+(X(2)-X(1)),Y(end)+(Y(2)-Y(1))];
    
    A=[pt_0_xy;[X(1:end-1),Y(1:end-1)]];
    B=[X,Y];
    C=[[X(2:end),Y(2:end)];pt_Splus1_xy];
    
    for i=1:S
        % A,B,C are pairs of coordinates
        P = [A(i,:); B(i,:); C(i,:)];
        % matrix
        M = [1 1 1 1 ; ...
                (P(1,1).^2 + P(1,2).^2) P(1,1) P(1,2) 1; ...
                (P(2,1).^2 + P(2,2).^2) P(2,1) P(2,2) 1; ...
                (P(3,1).^2 + P(3,2).^2) P(3,1) P(3,2) 1];
        M11 = local_minordet(M,1,1) ;
            if M11==0
                xy=[];
                Rc(i)=NaN; 
            else
                xy(1) = 0.5 * (local_minordet(M,1,2) ./ M11) ;
                xy(2) = -0.5 * (local_minordet(M,1,3) ./ M11) ;
                Rc(i) = sqrt(xy(1).^2 + xy(2).^2 + (local_minordet(M,1,4) ./ M11));
            end
    end
	function md = local_minordet(M,i,j)
		% minor determinant
		M(i,:)=[] ;
		M(:,j)=[] ;
		md = det(M);
	end
end	