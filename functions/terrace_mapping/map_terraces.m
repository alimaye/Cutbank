function map_terraces(inputFile,exportParameters,terraceMappingParameters)
% map_terraces.m: main function for mapping river terraces and calculating 
% associated morphometrics.
% Input arguments:
%   inputFiles: name of file with data for elevation and channel geometry.
%   exportParameters: structure array with parameters for file export.
%   terraceMappingParamaters: structure array with parameters for terrace
%   mapping.
% Output arguments:
%   None

    if inputFile.from_file
        load(inputFile.inputFilename,'dem','cell_width','centerline')
    else 
        dem = inputFile.dem;
        centerline = inputFile.centerline;
        cell_width = inputFile.cell_width;
        clear inputFile
    end
    
    % 1. Associate each DEM pixel with a channel elevation based on either
    % a steepest descent algorithm, or using the nearest channel.
    if exportParameters.terrace_mapping.find_assoc_channel_elev
        associate_DEM_with_channel; %calls nested function, adds field dem.assoc_channel_elev
        ind=dem.assoc_channel_elev==-9999; % put NaN for unassigned dem.assoc_channel_elev pixels
        dem.assoc_channel_elev(ind)=NaN;
    end

    if exportParameters.terrace_mapping.make_hillshade
        % generate hillshade using nested function
        H=make_hillshade;
    end
    % assign a channel elevation and floodplain elevation for each pixel
    if exportParameters.terrace_mapping.use_input_parameters
        max_elev=terraceMappingParameters.max_elev;
        fp_level=terraceMappingParameters.fp_level;
        minimum_area=terraceMappingParameters.minimum_area;
        window_size=terraceMappingParameters.window_size;
        std_z_thresh = terraceMappingParameters.std_z_thresh;
    end
    
    if exportParameters.terrace_mapping.manually_tune_thresholds
        %  Map floodplain. each pixel has an associated channel elevation. here, graphically estimate the height of a floodplain at a constant
        % height above the channel. the estimated floodplain is used as a mask. Count as terrace pixels only those within the pixel map whose
        % elevations exceed the top_of_floodplain eleavation
        thresh_tool_pan_zoom_fp(dem.z-dem.assoc_channel_elev);  % top of floodplain elevation;
        % have user choose a floodplain mask
        fp_level = input('Enter floodplain level: '); % this way, maintain pan/zoom tools in gui (weren't programmed into original)
        % Figure plots floodplain mask for different inundation levels
        thresh_tool_pan_zoom_elev(dem.z); % can edit thresh tool to show <thresh, or can use the other fcn to make a range
        max_elev = input('Enter maximum elevation: ');
        minimum_area=input('Enter minimum area needed to be a terrace (m^2): ');
        std_z_thresh = input('Enter threshold for std(elev) in fixed width (m): ');
    end
    minimum_pixels = ceil(minimum_area/(cell_width^2));

    L=[];
    % call nested function to apply masks.
    if exportParameters.terrace_mapping.calculate_masks
       L = identify_terrace_pixels; 
    else % load existing label matrix
       terrace_metrics_file=[exportParameters.terrace_mapping.dir,exportParameters.terrace_mapping.file_base_name,'_terrace_masks.mat'];
       load(terrace_metrics_file,'L','L_rgb');
    end
    
    % Calculate terrace morphometrics.
    if exportParameters.terrace_mapping.calculate_terrace_metrics
        [metrics,pairing_stats] = calculate_terrace_metrics;
        
        if ~isequal(size(dem.z),size(L))
            err='Error (map_terraces.m): Label matrix and DEM size to not match'; 
            filename=[outputDir,'run_',trial,'_error_data.mat'];
            save(filename)
            error(err)
        end

        terrace_metrics_file=[exportParameters.terrace_mapping.dir,exportParameters.terrace_mapping.file_basename,'_terrace_metrics.mat'];
        terrace_shapefile_name = [exportParameters.terrace_mapping.dir,exportParameters.terrace_mapping.file_basename,'_terraces.shp'];
        save(terrace_metrics_file,'metrics','pairing_stats','L')
        
        % Export terrace shapefile.
        if ~isempty(metrics) % Only writes a shapefile if terraces were found.
            write_terrace_shapefile(terrace_metrics_file,dem,terrace_shapefile_name);
        end
        
        if exportParameters.terrace_mapping.plot_terrace_metrics
            plot_metrics;
        end
        disp('Finished mapping terraces')
    end

    % NESTED FUNCTIONS: associate_DEM_with_channel (contains nested function
    % plot steepest descent), hillshade,
    % identify_terrace_pixels, calculate_terrace_metrics,
    % plot_metrics.
    function associate_DEM_with_channel
        %associate_DEM_with_channel.m: attempts to assign each pixel in the
        % landscape to a point on the channel using a steepest descent algorithm.
        
        % As a preliminary step, fill sinks in the DEM
        if terraceMappingParameters.dem_fill_sinks
            dem.z = fillsinks(dem.z,1); % fill sinks up to 1 meter deep; calls function from TopoToolbox
        end


        % Associate each pixel in the DEM with a channel elevation using
        % either (1) the nearest channel location or (2) the nearest
        % channel location, following a steepest descent path.
        switch terraceMappingParameters.channelAssociationMethod
            case 'nearestChannel'
                [~,~,fracDistAlongCenterline] = distance2curve([centerline.X,centerline.Y],[dem.x(:),dem.y(:)]);
                dem.assoc_channel_elev = interp1((1:length(centerline.Z))/numel(centerline.Z),centerline.Z,fracDistAlongCenterline,'linear'); 
                dem.assoc_channel_elev(isnan(dem.z))=NaN; % NaN cells in DEM are out of analysis domain.
                dem.assoc_channel_elev = reshape(dem.assoc_channel_elev,size(dem.z,1),size(dem.z,2));
            case 'nearestDownslopeChannel'
                % Initialize an array that associates a channel elevation with each
                % pixel in the DEM. The initial value is set to -9999, whereas NaN
                % DEM pixels will not have an associate channel elevation of NaN.
                dem.assoc_channel_elev=-9999*(ones(size(dem.z)));
                dem.assoc_channel_elev(isnan(dem.z))=NaN; % NaN cells in DEM are out of analysis domain.

                % Calculate flow direction for each DEM pixel ('flow_dir') and associated equations
                % ('flow_mat') used by subsequent calculations.
                [flow_dir,~]=dem_flow(dem.z);
                flow_mat=flow_matrix(dem.z,flow_dir);

                % Strictly speaking, flow paths from DEM pixels may not
                % lead all the way to the channel. Therefore, find pixels 
                % within a 3-pixel buffer of the channel and directly
                % assign them an associated channel elevation that
                % corresponds to the elevation of the nearest point on the
                % channel. 
                [~,distToChannel,fracDistAlongCenterline] = distance2curve([centerline.X,centerline.Y],[dem.x(:),dem.y(:)]);
                ind = distToChannel<(3*cell_width);
                dem.assoc_channel_elev(ind) = interp1((1:length(centerline.Z))/numel(centerline.Z),centerline.Z,fracDistAlongCenterline(ind),'linear'); 
                        
                % Loop through the near-channel pixels with assigned local
                % channel elevations, split into groups binned by the
                % elevation of the local channel. For each bin, find the 
                % find the upslope pixels that drain to a pixel in that
                % bin. Assign the upslope pixels the associated channel
                % elevation that corresponds to he mean elevation of the
                % bin. 
                assoc_channel_elev_orig=dem.assoc_channel_elev;
                z_res = 0.1; % Use a bin width of 10 cm for associated elevations along the channel
                bins = linspace(max(centerline.Z),min(centerline.Z)-z_res,round(range(centerline.Z)/z_res));
                for q=1:numel(bins)-1
                    [px_r,px_c]=find(and(assoc_channel_elev_orig<=bins(q),assoc_channel_elev_orig>bins(q+1)));
                    if ~isempty(px_r)
                        channelElevAssigned = or(dem.assoc_channel_elev>-9999,isnan(dem.assoc_channel_elev)); % logical mask
                        D=dependence_map(dem.z,flow_mat,px_r,px_c); % The dependence map shows which uphill pixels drain through a particular pixel.
                        dem.assoc_channel_elev(and(D>0,~channelElevAssigned))=(bins(q)+bins(q+1))/2; % mean elevation of bin. could also be of bin pixels        
                    end
                end                
        end
        
        if ispc
            slash='\';
        else
            slash='/';
        end
        nearest_channel_elev_file = [exportParameters.terrace_mapping.dir,slash,exportParameters.terrace_mapping.file_basename,'_nearest_channel_elevation.mat'];
        save(nearest_channel_elev_file,'dem')
    end %end of nested plot steepest descent results function        

    function [H]=make_hillshade
        [cols,rows] = meshgrid(1:size(dem,2),1:size(dem,1));
        H = hillshade(cell_width*cols,cell_width*rows,dem);  % calls function from TopoToolbox
    end   % end of nested hillshade function

    function [L] = identify_terrace_pixels 
        % identifies terrace pixels larger than a specified size.
        % identify  high slope- and/or curvature areas
        % set window size in pixels. has to be an odd number of pixels.
        window_size_pixels = window_size/cell_width;
        if mod(floor(window_size_pixels),2)==0
            window_size_pixels=ceil(window_size_pixels);
        else
            window_size_pixels=floor(window_size_pixels);
        end
        if mod(floor(window_size_pixels),2)==0 % would occur if original window size was an even integer multiple of cell width
           window_size_pixels=window_size_pixels+1;
        end
        std_z = stdfilt(dem.z,ones(repmat(window_size_pixels,1,2))); % Calculate local standard deviation of elevation in DEM using a square window
        elev_gt_fp = (dem.z-dem.assoc_channel_elev)>fp_level; 
        % Make a buffer around centerline and use that as a mask as
        % well.
        buffer_dist = terraceMappingParameters.buffer_dist;
        % Make a buffer using pixel distance to centerline.
        [~,dist_to_ctrline,~] = distance2curve([centerline.X(:),centerline.Y(:)],[dem.x(:),dem.y(:)],'linear');            
        % find pixels within buffer
        dist_to_ctrline=reshape(dist_to_ctrline,size(dem.z,1),size(dem.z,2));
        unfiltered_terrace_mask = std_z<std_z_thresh & elev_gt_fp & dem.z<max_elev & dist_to_ctrline<buffer_dist;   % criteria: low roughtness, elevation above fp level, and drains to chosen river stem
        filtered_terrace_mask=imfill(unfiltered_terrace_mask,'holes');
        % Remove areas with fewer than a threshold number of pixels.
        filtered_terrace_mask = bwareaopen(filtered_terrace_mask,minimum_pixels,4); % 4 is connectivity
        if terraceMappingParameters.clear_border
            % removes objects that intersect domain boundary
            filtered_terrace_mask = imclearborder(filtered_terrace_mask);            
        end
        CC = bwconncomp(filtered_terrace_mask,4); % find connected components in binary terrace mask.  4 is connectivity.
        L=labelmatrix(CC);
        L_rgb = label2rgb(L,'jet',[0 0 0],'shuffle');              
    end

    function [metrics,pairing_stats] = calculate_terrace_metrics
        % Uses input file, pixel map metrics is a structure array
        % containing information about each terrace. area, mean
        % elevation, mean surface age, slope, azimuth convert channel
        % coordinates to pixel coordinates.
        ULx = min(dem.x(:)); ULy = max(dem.y(:));
        centerline.X = abs(centerline.X-ULx)/cell_width; centerline.Y = abs(centerline.Y-ULy)/cell_width;
        % remove any duplicate values
        chan_xy=[centerline.X(:),centerline.Y(:)]; delete=[];
        for dd=1:size(chan_xy,1)-1
            if isequal(chan_xy(dd,:),chan_xy(dd+1,:))
                delete=[delete,dd];
            end
        end
        chan_xy(delete,:)=[]; centerline.X=chan_xy(:,1); centerline.Y=chan_xy(:,2);    

        % Define a valley centerline using a moving average. Smoothing
        % window is discretionary.
        % Interpolate for even spacing
        chan_dist=[0;cumsum(sqrt(sum(diff([centerline.X(:),centerline.Y(:)],1,1).^2,2)))];
        chan_dist_interp=linspace(0,max(chan_dist),numel(centerline.X));
        xxyy=spline(chan_dist,chan_xy',chan_dist_interp);
        span=50;
        valley_centerline_x=smooth(xxyy(1,:),span,'moving'); 
        valley_centerline_y=smooth(xxyy(2,:),span,'moving');
        valley_centerline=[valley_centerline_x(:),valley_centerline_y(:)];

        n_terraces=max(L(:));
        if n_terraces==0
            metrics=[];
            pairing_stats=[];
        else                
            metrics(n_terraces).area=NaN; % effectively pre-allocates structure array
            L_all=L;
            for terrace_number=1:n_terraces
                % assemble terrace data
                [row,col]=find(L_all==terrace_number);  % could also use these pixel coordinates to find corresp values of xtopo, ytopo
                z=zeros(size(col));
                for j=1:length(col)
                    z(j)=dem.z(row(j),col(j));
                end
                terrace_data = [col,row,z];

                metrics(terrace_number).boundary_coords_row_column = cell2mat(bwboundaries(L_all==terrace_number,4,'noholes'));
                metrics(terrace_number).dem_indices = find(L_all==terrace_number);
                metrics(terrace_number).area= size(terrace_data,1)*(cell_width^2); % because number of rows = number of pixels
                metrics(terrace_number).mean_elev = mean(terrace_data(:,3));

                get_slope = terraceMappingParameters.get_slope;
                if get_slope
                    [sl,az,~]=regressplane(cell_width*terrace_data(:,1),cell_width*terrace_data(:,2),terrace_data(:,3));  % HERE, NEED ACCURATE RELATIVE X AND Y COORDINATES. I think it's ok like this.
                    % az IS the dip direction, with 0 pointing along the x axis
                    metrics(terrace_number).slope = sl;
                    metrics(terrace_number).dip_dir = az;
                end
                dem_terrace_binary=(L_all==terrace_number);
                CC = bwconncomp(dem_terrace_binary,4); % find connected components in binary terrace mask, for use by regionprops
                L_temp=labelmatrix(CC);
                if max(L(:))>1 % removes any fragments
                    num=zeros(max(L_temp(:)),1);
                    for j=1:max(L_temp(:))
                        num(j) = numel(find(L_temp==j));
                    end
                    max_num=find(num==max(num(:)),1,'first');
                    L_temp(ne(L_temp,max_num))=0;
                    L_temp=L_temp>0;
                    CC=bwconncomp(L_temp);
                end
                STATS = regionprops(CC,'MajorAxisLength','MinorAxisLength','Eccentricity','Orientation');
                metrics(terrace_number).ell_major_ax_length = STATS.MajorAxisLength*cell_width;
                metrics(terrace_number).ell_minor_ax_length = STATS.MinorAxisLength*cell_width;
                metrics(terrace_number).ell_orientation = STATS.Orientation;
                metrics(terrace_number).ell_eccentricity = STATS.Eccentricity; % 0=perfect circle, 1=parabola.  
                % The eccentricity is the ratio of the distance between the foci of the ellipse and its major axis length
                metrics(terrace_number).box = [min(terrace_data(:,1)) max(terrace_data(:,2)) max(terrace_data(:,1))-min(terrace_data(:,1)) max(terrace_data(:,2))-min(terrace_data(:,2))];
                metrics(terrace_number).centr = [mean(terrace_data(:,1)),mean(terrace_data(:,2))];
                ind=find(L_all==terrace_number);  % could also use these pixel coordinates to find corresp values of xtopo, ytopo
                metrics(terrace_number).centr_xy=[mean(dem.x(ind(:))),mean(dem.y(ind(:)))];
                % Find mean terrace elevation above channel find the rows
                % of pixel map that have pixels in common with the label
                % matrix.
                ind=find(L_all==terrace_number);  % could also use these pixel coordinates to find corresp values of xtopo, ytopo
                % extract mean terrace elevation above channel
                elev_above_channel = dem.z(ind)-dem.assoc_channel_elev(ind);
                elev_above_channel = elev_above_channel(~isnan(elev_above_channel));
                metrics(terrace_number).mean_elev_above_channel  = mean(elev_above_channel);

                % Dip direction - can use to determine if terraces slope
                % downvalley/upvalley (angle would be close to 0 for
                % downvalley) or perpendicular to valley (angle closer to
                % +-90) find closest part of valley centerline and
                % determine its azimuth (0 along X axis)
                centr=metrics(terrace_number).centr;
                dist_centr_to_centerline_nodes = sqrt(sum((repmat(centr,size(valley_centerline,1),1)- valley_centerline).^2,2));
                closest_nodes=find(dist_centr_to_centerline_nodes(:)==min(dist_centr_to_centerline_nodes(:)));
                if length(closest_nodes)==1
                    closest_node = closest_nodes;
                    dist_centr_to_centerline_nodes(closest_node)=Inf;
                    second_closest_node = find(dist_centr_to_centerline_nodes==min(dist_centr_to_centerline_nodes(:)));
                else
                    closest_node = closest_nodes(1);
                    second_closest_node = closest_nodes(2);
                end
                nodes_sort = sort([closest_node;second_closest_node],'ascend');
                closest_node = nodes_sort(1); second_closest_node = nodes_sort(2);

                valley_centerline_vector = [valley_centerline(second_closest_node,1)-valley_centerline(closest_node,1),valley_centerline(second_closest_node,2)-valley_centerline(closest_node,2)];
                metrics(terrace_number).valley_az = (180/pi)*atan2(valley_centerline_vector(2),valley_centerline_vector(1));
                if get_slope
                    metrics(terrace_number).angle_terr_valley_az =  metrics(terrace_number).dip_dir - metrics(terrace_number).valley_az;
                end
                metrics(terrace_number).valley_centerline_closest_node = closest_node;
                metrics(terrace_number).valley_centerline_second_closest_node = second_closest_node;

                channel_centerline = [(xxyy(1,:))',(xxyy(2,:))'];
                dist_centr_to_centerline_nodes = sqrt(sum((repmat(centr,size(channel_centerline,1),1)- channel_centerline).^2,2));
                closest_nodes=find(dist_centr_to_centerline_nodes(:)==min(dist_centr_to_centerline_nodes(:)));
                if length(closest_nodes)==1
                    closest_node = closest_nodes;
                    dist_centr_to_centerline_nodes(closest_node)=Inf;
                    second_closest_node = find(dist_centr_to_centerline_nodes==min(dist_centr_to_centerline_nodes(:)));
                else
                    closest_node = closest_nodes(1);
                    second_closest_node = closest_nodes(2);
                end
                nodes_sort = sort([closest_node;second_closest_node],'ascend');
                closest_node = nodes_sort(1); second_closest_node = nodes_sort(2);
                %%%%%%% replace with code from plot_topography_v4????
                channel_centerline_vector = [channel_centerline(second_closest_node,1)-channel_centerline(closest_node,1),channel_centerline(second_closest_node,2)-channel_centerline(closest_node,2)];
                metrics(terrace_number).channel_az = (180/pi)*atan2(channel_centerline_vector(2),channel_centerline_vector(1));
                if get_slope
                    metrics(terrace_number).angle_terr_channel_az =  metrics(terrace_number).dip_dir - metrics(terrace_number).channel_az;
                end        
            end 

            if ~terraceMappingParameters.pairing_check
                pairing_stats=[];
            else
                % pairing check: criteria are similar elevation, opposite side of
                % channel, and proximity.
                d=20000/cell_width; % distance to look across channel, 20 km; in pixels.
                count=0; paired_terraces=[];
                for ff=1:length(metrics)-1
                    mean_elev1 = metrics(ff).mean_elev;
                    centr1 = metrics(ff).centr;
                    box1 = metrics(ff).box; % data for making bounding box of terrace we're checking
                    box1_UL = box1(1:2);
                    box1_xwidth = box1(3);
                    box1_ywidth = box1(4);
                    box1_UR = box1_UL+[box1_xwidth,0];
                    box1_LL = box1_UL+[0,-box1_ywidth];
                    box1_LR = box1_UL+[box1_xwidth,-box1_ywidth];
                    box1_centr = box1_UL+[box1_xwidth/2,-box1_ywidth/2];
                    % find the closest valley centerline point to the terrace centroid
                    closest_node = metrics(ff).valley_centerline_closest_node; second_closest_node = metrics(ff).valley_centerline_second_closest_node;
                    x3=centr1(1); y3=centr1(2); % x,y of pixels in the channel section
                    x1=valley_centerline(closest_node,1); y1=valley_centerline(closest_node,2);
                    x2=valley_centerline(second_closest_node,1); y2=valley_centerline(second_closest_node,2);
                    u = ((x3-x1).*(x2-x1)+(y3-y1).*(y2-y1))./(sum(([x2,y2]-[x1,y1]).^2,2)); % u is distance along vector connecting [x1,y1] and [x2,y2]
                    x = x1 + u*(x2-x1);
                    y = y1 + u*(y2-y1); 
                    valley_ctr_pt = [x,y]; 
                    % calculate the translation of the box corner coordinates to their
                    % across-valley locations
                    shift_axis = [box1_centr;valley_ctr_pt];
                    shift_vect = shift_axis(2,:)-shift_axis(1,:);
                    angle = atan2(shift_vect(2),shift_vect(1)); 
                    box1_UL_shift = box1_UL+[d*cos(angle),d*sin(angle)];
                    box1_UR_shift = box1_UR+[d*cos(angle),d*sin(angle)];
                    box1_LR_shift = box1_LR+[d*cos(angle),d*sin(angle)];
                    box1_LL_shift = box1_LL+[d*cos(angle),d*sin(angle)];

                    box1_all_points = [box1_LL;box1_UL;box1_UR;box1_LR;box1_LL_shift;box1_UL_shift;box1_UR_shift;box1_LR_shift];
                    k=convhull(box1_all_points(:,1),box1_all_points(:,2)); % ordered indices of convex hull around box and shifted box
                    box1_all_points = box1_all_points(k,:);
                    %polybool needs clockwise/counterclockwise oriented vectors
                    [box1_x,box1_y]=poly2cw(box1_all_points(:,1),box1_all_points(:,2));
                    for j=ff+1:length(metrics)   
                       mean_elev2 = metrics(j).mean_elev;
                       box2 = metrics(j).box;
                       centr2 = metrics(j).centr;
                       % check if on different sides of channel
                        [xo,~]=intersections([centr1(1), centr2(1)],[centr1(2) centr2(2)],centerline.X,centerline.Y,'robust');
                        if mod(length(xo),2)==1 % then the two points are on opposite sides of the channel. 
                            different_sides = true;
                        else
                            different_sides = false;
                        end
                        if different_sides % then continue (if these were equal, then terraces would be on same side)
                           within_elev_range = abs(mean_elev1-mean_elev2)<terraceMappingParameters.pairing_elev_thresh;
                           if within_elev_range
                               box2_UL = box2(1:2);
                               box2_xwidth = box2(3);
                               box2_ywidth = box2(4);
                               box2_UR = box2_UL+[box2_xwidth,0];
                               box2_LL = box2_UL+[0,-box2_ywidth];
                               box2_LR = box2_UL+[box2_xwidth,-box2_ywidth]; 
                               box2_poly = [box2_LL;box2_UL;box2_UR;box2_LR];
                               box2_x = box2_poly(:,1); box2_y = box2_poly(:,2);
                               [box2_x,box2_y]=poly2cw(box2_x,box2_y);
                               [xint,~]=polybool('intersection',box1_x,box1_y,box2_x,box2_y);
                                   terraceMappingParameters.plot_pair_check
                                   figure;
                                   imagesc(H);
                                   colormap gray, hold on, patch(box1_x,box1_y,'b');
                                   hold on, patch(box2_x,box2_y,'g');
                                   hold on, plot(valley_ctr_pt(1),valley_ctr_pt(2),'b.','markersize',20)
                                   hold on, plot(valley_centerline(:,1),valley_centerline(:,2),'k-')
                                   hold on, plot(centerline.X,centerline.Y,'r-','linewidth',2)
                                   hold on, plot(centr1(1),centr1(2),'y.','markersize',10)
                                   hold on, plot(centr2(1),centr2(2),'y.','markersize',10)
                                   if ~isempty(xint)
                                       title('paired')
                                   end
                           end
                           count=count+1;
                           paired_terraces(count,1:2)=[ff,j];
                           within_spatial_range(count,1) = ~isempty(xint); % then terraces across from one another
                        end
                    end
                end
                for gg=1:numel(metrics)
                    if isempty(paired_terraces)
                        metrics(gg).pair_id_same_elev = [];
                        metrics(gg).pair_id_same_elev_and_adjacent = [];
                    else
                        % find rows of paired terraces that contain i
                        [rows,~]=find(paired_terraces==gg);
                        elev_pairs = unique(paired_terraces(rows,:));
                        elev_pairs(elev_pairs==gg)=[]; % i.e., don't count it paired with itself. These are the other terraces that are at the same elevation level.
                        within_spatial_range = find(within_spatial_range);
                        paired_terraces=paired_terraces(within_spatial_range,:);
                        [rows,~]=find(paired_terraces==gg);
                        elev_spatial_pairs = unique(paired_terraces(rows,:));
                        elev_spatial_pairs(elev_spatial_pairs==gg)=[]; % i.e., don't count it paired with itself. These are the other terraces that are at the same elevation level.
                        metrics(gg).pair_id_same_elev = elev_pairs;
                        metrics(gg).pair_id_same_elev_and_adjacent = elev_spatial_pairs;
                    end
                end
                pairing_stats.percentage_by_number.same_elev = (numel(find(~cellfun(@isempty,{metrics(:).pair_id_same_elev}))))/numel(metrics);
                pairing_stats.percentage_by_area.same_elev = sum((~cellfun(@isempty,{metrics(:).pair_id_same_elev})).*cell2mat({metrics(:).area}))/sum(cell2mat({metrics(:).area}));
                pairing_stats.percentage_by_number.same_elev_and_adjacent = (numel(find(~cellfun(@isempty,{metrics(:).pair_id_same_elev_and_adjacent}))))/numel(metrics);
                pairing_stats.percentage_by_area.same_elev_and_adjacent = sum((~cellfun(@isempty,{metrics(:).pair_id_same_elev_and_adjacent})).*cell2mat({metrics(:).area}))/sum(cell2mat({metrics(:).area}));
            end
        end
    end % end nested function terrace_metrics

    function plot_metrics % nested function
        area=nan(numel(metrics),1);
        mean_elev=nan(numel(metrics),1);
        dip_dir=nan(numel(metrics),1);
        angle_terr_valley_az=nan(numel(metrics),1);
        slope=nan(numel(metrics),1);
        major_ax_length=nan(numel(metrics),1);
        minor_ax_length=nan(numel(metrics),1);
        eccentricity=nan(numel(metrics),1);
        map_orientation=nan(numel(metrics),1);

        for hh=1:length(metrics)
            area(hh)=metrics(hh).area;
            mean_elev(hh)=metrics(hh).mean_elev;
            slope(hh)=metrics(hh).slope;
            dip_dir(hh)=metrics(hh).dip_dir;
            angle_terr_valley_az(hh) = metrics(hh).angle_terr_valley_az;
            major_ax_length(hh)=metrics(hh).ell_major_ax_length;
            minor_ax_length(hh)=metrics(hh).ell_minor_ax_length;
            eccentricity(hh)=metrics(hh).ell_eccentricity;
            map_orientation(hh)=metrics(hh).ell_orientation;
        end

        figure;
        subplot(3,2,1)
        hist(area)
        xlabel('Area (m^2)')
        ylabel('#')
        subplot(3,2,2)
        hist(mean_elev)
        xlabel('Mean elevation (m)')
        ylabel('#')
        subplot(3,2,3)
        hist(major_ax_length)
        xlabel('Length (m)')
        ylabel('#')
        subplot(3,2,4)
        hist(minor_ax_length)
        xlabel('Width (m)')
        ylabel('#')
        subplot(3,2,5)
        hist(eccentricity)
        xlabel('Eccentricity')
        ylabel('#')

        figure;
        subplot(1,3,1)
        rose(dip_dir*(pi/180)) % ROSE only takes angles in radians. 
        title('Dip direction (0=E; 90=N)')

        subplot(1,3,2)
        hist(slope)
        xlabel('Dip (deg.)')
        ylabel('#')
        subplot(1,3,3)
        rose(angle_terr_valley_az*(pi/180)) % ROSE only takes angles in radians. 
        title('Angle btw. terr. dip dir. and valley az.')

        figure;
        subplot(1,2,1)
        rose(dip_dir(slope>1)*(pi/180)) % ROSE only takes angles in radians. 
        title('Dip direction (filtered for dip>1 deg)')
        subplot(1,2,2)
        hist(slope(slope>1))
        xlabel('Dip (filtered for dip>1 deg)')
        ylabel('#')

        figure;
        rose(map_orientation*pi/180);
        title('Map orientation of ellipse')
    end % end nested function plot_metrics        
end