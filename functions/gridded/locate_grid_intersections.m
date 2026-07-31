function [grid_ind,dist_each_interval]=locate_grid_intersections(X_cutbank,Y_cutbank,X_cutbank_max_move,Y_cutbank_max_move,gridLines,grid_size,dem_xvec,dem_yvec,lgi_mode,domain)
% locate_grid_intersections.m: For grid-based bank-material tracking,
% identifies where the search vector extended from the bank intersects
% with grid cell edges, and returns the grid cell indices intersected and
% the length along the search vector that corresponds to each cell.
% Input arguments:
%   X_cutbank: x-coordinates for cutbank (eroding bank) of river
%   Y_cutbank: y-coordinates for cutbank
%   X_cutbank_max_move: x-coordinates that correspond to the maximum
%   distance the bank could move (prior to querying bank materials)
%   Y_cutbank_max_move: y-coordinates that correspond to the maximum
%   distance the bank could move (prior to querying bank materials)
%   gridLines: structure array that stores the grid for tracking
%   bank-material properties as a set of vertical and horizontal lines
%   grid_size: size of grid in rows and columns
%   dem_xvec: vector of x-coordinates in digital elevation model (which has same
%   dimensions as grid)
%   dem_yvec: vector of y-coordinates in digital elevation model (which has same
%   dimensions as grid)
%   lgi_mode: mmode for locating grid intersections. Specifies whether a
%   shift should be applied in order to query areas across the periodic
%   boundary condition in the x-direction
%   domain: structure array that specifies geometry of model domain
% Output arguments:
%   grid_ind: linear indices of grid notes that the bank search vector
%   encounters
%   dist_each_interval: the distance along the bank search vector that
%   occurs in each cell indicated by grid_ind

    switch lgi_mode
        case 'shift1'
            offset = domain.xRange;
        case 'shift2'
            offset = -domain.xRange;
        case 'noshift'
            offset = 0;
    end

    [xo,yo,~,~]=intersections([X_cutbank;X_cutbank_max_move]+offset,[Y_cutbank;Y_cutbank_max_move],gridLines.all(:,1),gridLines.all(:,2));
    % add the bank and endpoint locations to get these cells too. 
    xo = [xo; X_cutbank; X_cutbank_max_move];
    yo = [yo; Y_cutbank; Y_cutbank_max_move];

    % sort intersections by distance to cutbank. 
    d = sqrt((xo-(X_cutbank+offset)).^2+(yo-Y_cutbank).^2);
    [~,isort]=sort(d);
    xo = xo(isort);
    yo = yo(isort);
    
    if  all(sqrt((xo-(X_cutbank+offset)).^2+(yo-Y_cutbank).^2)>1e-8) 
        if ~or((X_cutbank+offset)<min(gridLines.all(:,1)),(X_cutbank+offset)>max(gridLines.all(:,1)))  % Points need to be within grid
            xo = [X_cutbank+offset;xo];
            yo = [Y_cutbank;yo];
        end
    end
    
    if all(sqrt((xo-(X_cutbank_max_move+offset).^2+(yo-Y_cutbank_max_move).^2))>1e-8)
        % if exceeds grid extent, do nothing; if not, add a point
        if ~or((X_cutbank_max_move+offset)<min(gridLines.all(:,1)),(X_cutbank_max_move+offset)>max(gridLines.all(:,1)))
            xo = [xo;X_cutbank_max_move+offset];
            yo = [yo;Y_cutbank_max_move];
        end
    end
    
    % re-format into grid intersection point pairs for each cell
    if numel(xo)>1
        mean_xy = [sum([xo(1:end-1),xo(2:end)],2)/2,sum([yo(1:end-1),yo(2:end)],2)/2]; % gets average x,y position of pair. inline version of [mean(xo3_pairs,2),mean(yo3_pairs,2)]; 
    else
        mean_xy=[xo,yo];
    end
    
    % Calculate the distance for each interval
    d = sqrt((xo-(X_cutbank+offset)).^2+(yo-Y_cutbank).^2);
    if numel(d)>1
           dist_each_interval=d(2:end)-d(1:end-1);
    else
        dist_each_interval=d;
    end    
    
    % Round intersection coordinates to the nearest grid cell center
    nr=size(mean_xy,1);
    grid_cols=nan(nr,1);
    grid_rows=nan(nr,1);
    for n=1:nr
        [~,grid_cols(n)]=min(abs(mean_xy(n,1)-dem_xvec));
        [~,grid_rows(n)]=min(abs(mean_xy(n,2)-dem_yvec));
    end
   
    % Determine array index
    grid_ind=sub2ind(grid_size,grid_rows,grid_cols);
end