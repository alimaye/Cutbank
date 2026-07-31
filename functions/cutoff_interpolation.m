function[centerline,cutoff_interp_stats]=cutoff_interpolation(centerline,w,init_spacing,domain,cutoff_interp_stats,modelIt,trial,outputDir)    
% cutoff_interpolation.m: Locally adjusts the channel centerline to maintain
% node spacing within a defined range, and checks for neck cutoffs. The
% operations are performed iteratively until the channel planform meets
% these geometric criteria.
% Input arguments:
%   centerline: Structure array with channel centerline coordinates
%   w: channel width
%   init_spacing: initial spacing of nodes in channel centerline
%   domain: structure array that describes geometry of the model domain
%   cutoff_interp_stats: structure array that stores data for cutoffs and interpolation of the channel centerline
%   modelIt: model iteration. A distinct name for this variable is used in
%   this function because there is another iteration counter.
%   trial: name of model run
%   outputDir: directory for file output

% Output arguments:
%   centerline: updated coordinates for channel centerline
%   cutoff_interp_stats: Updated structure array that stores data for cutoffs and interpolation of the channel centerline

centerline_in=centerline;% save in case needed for debugging 
full_planform=false;
checked_and_no_cutoffs = false;

cutoffSearchIt=0; % Note: this is an iteration counter local to this function, and is different from 'modelIt' used to track iterations associated with time steps in the main code (and just named 'it') in the main code
% start with a cutoff check so get proper stats on areas removed (i.e.,
% right indices). 
cutoff_check;

cutoffSearchIt=1;
cutoffSearch_maxIt=1000; % put a ceiling to avoid infinite loop in case of function failure
% now enter coupled interpolation and cutoff check. only does cutoff check
% if interpolation was done in same iteration.
    while cutoffSearchIt<=cutoffSearch_maxIt
    % Perform interpolation check. Notably, this won't affect y-position of
    % first, last nodes (needed condition for periodic b.c.)    
        rel_node_space_vs_init=sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2))/init_spacing;
        %rel_node_space_vs_init(end)=0; % last node can have different spacing.
        if any(or(rel_node_space_vs_init<=0.5,rel_node_space_vs_init>=2))
            interp_this_it=true;
            cutoff_interp_stats.centerline_interp_log(modelIt)=true;
            % temporarily copy upstream and downstream
            if any(sum(abs(diff([centerline.X,centerline.Y],1)),2)<1e-8)
                err = 'Error (cutoff_interpolation.m): Duplicate centerline point detected';
                filename=[outputDir,'run_',trial,'_error_data.mat'];
                save(filename)
                error(err)                
            end
            % add two nodes to upstream and downstream so can shift
            % original endpoints appropriately
            nodes_add = 2;
            centerline = replicate_centerline_periodic(centerline,nodes_add);
            node = 4; % that's the second of the original nodes, because two padding nodes were added; don't want to mess with the first original node. Note: the padding nodes are only there so can fit curves for new/shifted nodes.
            % - condition 1: puts a node after the current node. do not consider last node.
            % - condition 2a: deletes node+1. so should not delete last node.
            % - condition 2b: moves node+1. so should not move last node.
            while node<=numel(centerline.X)-3 % numel(centerline.X)-2 is the last real node (the last 2 are padding). with node before last real node, allow inserting a node before the last real node, but not moving or deleting the last real node.
              dist_to_next_node = sqrt((centerline.X(node+1)-centerline.X(node))^2+(centerline.Y(node+1)-centerline.Y(node))^2);
              if dist_to_next_node>=(2*init_spacing)
                  % spline interpolate for halfway between current node and
                  % next node, using the 2 nodes upstream and 2 nodes downstream 
                  % of the node to be inserted
                    node_start = node-1;
                    node_start(node_start<1)=1;
                    node_end=node+2;
                    node_end(node_end>numel(centerline.X))=numel(centerline.X);
                    X_subset=centerline.X(node_start:node_end);
                    Y_subset=centerline.Y(node_start:node_end);
                    Z_subset=centerline.Z(node_start:node_end);
                    d_subset = [0;cumsum(sqrt(sum(diff([X_subset,Y_subset],1,1).^2,2)))]; 
                    % interpolate for new node placement
                    xyz_new_node=interp1(d_subset,[X_subset,Y_subset,Z_subset],(d_subset(2)+d_subset(3))/2,'spline');  % could just as easily use spline here. In general spline is probably more accommodating to higher sinuosity, so using linear (a blunter tool to remove cutoffs).

                    % but make sure that z is average of value of
                    % upstream, downstream nodes (otherwise spline can
                    % make it poke out)
                    xyz_new_node(3)=(Z_subset(2)+Z_subset(3))/2;
                       
                    % insert new node
                    centerline.X=[centerline.X(1:node);xyz_new_node(1);centerline.X(node+1:end)];
                    centerline.Y=[centerline.Y(1:node);xyz_new_node(2);centerline.Y(node+1:end)];
                    centerline.Z=[centerline.Z(1:node);xyz_new_node(3);centerline.Z(node+1:end)];
                    node=node+2; % no need check for the distance from the newly added node, so move on 2 nodes
              elseif dist_to_next_node<init_spacing/2 && (node<numel(centerline.X)-3) % && condition is so don't modify the last real node (the following statements modify node+1)
                  if sqrt((centerline.X(node+2)-centerline.X(node+1))^2+(centerline.Y(node+2)-centerline.Y(node+1))^2)<init_spacing/2
                      % then the distance to the next node is too
                      % small, as is the distance to the node after
                      % that; so delete the middle node (node+1)
                     centerline.X=[centerline.X(1:node);centerline.X(node+2:end)];
                     centerline.Y=[centerline.Y(1:node);centerline.Y(node+2:end)];
                     centerline.Z=[centerline.Z(1:node);centerline.Z(node+2:end)];
                     node=node+1; % move on to next node
                  else
                     % then move this point to halfway btw. the
                     % immediate upsteam and downstream nodes
                     node_start = node-1;
                     node_start(node_start<1)=1;
                     node_end=node+2; % count two past the node that will be moved
                     node_end(node_end>numel(centerline.X))=numel(centerline.X);
                     X_subset=centerline.X(node_start:node_end);
                     Y_subset=centerline.Y(node_start:node_end);
                     Z_subset=centerline.Z(node_start:node_end);
                     d_subset = [0;cumsum(sqrt(sum(diff([X_subset,Y_subset],1,1).^2,2)))]; 
                     % interpolate for new node placement
                     xyz_shifted_node=interp1(d_subset,[X_subset,Y_subset,Z_subset],(d_subset(2)+d_subset(4))/2,'spline');  % move to halfway between the nodes upstream and downstream
                     % but make sure that z is average of value of
                     % upstream, downstream nodes (otherwise spline can
                     % make it poke out)
                     xyz_shifted_node(3)=(Z_subset(2)+Z_subset(3))/2;
                         
                     % insert shifted node
                     centerline.X=[centerline.X(1:node-1);xyz_shifted_node(1);centerline.X(node+1:end)];
                     centerline.Y=[centerline.Y(1:node-1);xyz_shifted_node(2);centerline.Y(node+1:end)];
                     centerline.Z=[centerline.Z(1:node-1);xyz_shifted_node(3);centerline.Z(node+1:end)];
                     node=node+1; % no need check for the distance from the newly shifted node, so move on 
                  end
              else
                  node=node+1; % move on to next node
              end
            end
            % Remove extra nodes
              ind_start=3; 
              ind_end=numel(centerline.X)-2; % ind_start and ind_end are fixed because nodes 1:3 and end-2:end aren't changed.
              centerline.X=centerline.X(ind_start:ind_end);
              centerline.Y=centerline.Y(ind_start:ind_end);
              centerline.Z=centerline.Z(ind_start:ind_end);
        else
            interp_this_it=false;
        end

        if abs(centerline.X(end)-centerline.X(1)-domain.xExtent)>0.1
            err='Error (cutoff_interpolation.m): Centerline X-coodinate range exceeded';
            filename=[outputDir,'run_',trial,'_error_data.mat'];
            save(filename)
            error(err) 
        end
                
        if interp_this_it
            cutoff_check;
            if checked_and_no_cutoffs
                break
            else
                cutoffSearchIt=cutoffSearchIt+1;
            end
        else
            break
        end
    end
    
    if cutoffSearchIt>cutoffSearch_maxIt
        err='Error (cutoff_interpolation.m): Maximum iterations of cutoff finder reached';
        filename=[outputDir,'run_',trial,'_error_data.mat'];
        save(filename)
        error(err) 
    end

    %%% Nested functions
    function cutoff_check        
        checked_and_no_cutoffs = false;
        % make upstream and downstream copies
        centerline_before_cutoff_check = centerline;
        
        if full_planform
            nodes_add=numel(centerline.X)-1;
            orig_nodes_start_ind = numel(centerline.X);
            orig_nodes_end_ind = 2*numel(centerline.X)-1;
        else
            nodes_add = round(numel(centerline_before_cutoff_check.X)/4);
            orig_nodes_start_ind = nodes_add;
            orig_nodes_end_ind = orig_nodes_start_ind+numel(centerline_before_cutoff_check.X)-1;
        end
        centerline = replicate_centerline_periodic(centerline,nodes_add);
        rel_dist_all_nodes = [0;cumsum(sqrt(sum(diff([centerline.X,centerline.Y],1,1).^2,2)))]; 
        % subtract the cumulative distance to orig_nodes_start_ind
        rel_dist_all_nodes =  rel_dist_all_nodes -  rel_dist_all_nodes(orig_nodes_start_ind);
        rel_dist_all_nodes = rel_dist_all_nodes/rel_dist_all_nodes(orig_nodes_end_ind); % normalize so that original nodes range is [0,1]
        
        [leftBankTemp,rightBankTemp,~] = channel_margins(centerline,w); % find channel margins
        % indices are upstream, downstream indices of self-intersection
        [xo1,yo1,u1,d1]=my_intersections(leftBankTemp.X,leftBankTemp.Y);
        [xo2,yo2,u2,d2]=my_intersections(rightBankTemp.X,rightBankTemp.Y);
        
        if ~isempty(u1) || ~isempty(u2)
            u=[u1;u2]; d=[d1;d2]; x_int=[xo1;xo2]; y_int=[yo1;yo2];
            
            % Check for and remove and NaN values
            if any(isnan(u))
                indRemove = find(isnan(u));
                u(indRemove)=[];
                d(indRemove)=[];
                x_int(indRemove)=[];
                y_int(indRemove)=[];
            end
            
            centerline_nodes_remove=zeros(100,1);
            count_temp=1;
            count=0;
            loop_length=zeros(numel(u),1);
            loop_coords=cell(numel(u),1);
            for m=1:numel(u)
                nodes_remove = ceil(u(m)):floor(d(m));
                if and(u(m)>=orig_nodes_start_ind,u(m)<=orig_nodes_end_ind) && ~cutoff_interp_stats.cutoff_log(modelIt) % i.e., log the cutoff if no cutoffs have been logged for this overall model iteration and cutoffs are within model domain
                    count=count+1;
                    x_coords = [x_int(m);centerline.X(nodes_remove);x_int(m)]; % get full cutoff loop
                    y_coords = [y_int(m);centerline.Y(nodes_remove);y_int(m)];
                    loop_length(count)=sum(sqrt(sum(diff([x_coords,y_coords],1,1).^2,2)));
                    loop_coords{count}=[x_coords,y_coords];
                end
                nn_remove = numel(nodes_remove);
                centerline_nodes_remove(count_temp:(count_temp+nn_remove-1))=nodes_remove;
                count_temp=count_temp+nn_remove;
            end
            centerline_nodes_remove(count_temp:end)=[];
            centerline_nodes_remove=sort(centerline_nodes_remove);
            % nodes within a cutoff have consecutive indices, so number of
            % cutoffs equals diff(centerline_nodes_remove)>1
            if ~cutoff_interp_stats.cutoff_log(modelIt) % i.e., log the cutoff if no cutoffs have been logged for this model iteration
                % for the purposes of cutoff counting, limit the nodes in
                % consideration to those from the original planform.
                % However, a single cutoff may involve both ending and starting
                % nodes. So track nodes_remove for which have upstream
                % nodes within the original node range.
                cutoff_interp_stats.cutoff_log(modelIt)=true;
                cutoff_interp_stats.n_cutoffs(modelIt) = count;
                cutoff_interp_stats.cutoff_length{modelIt} = loop_length(1:count);
                cutoff_interp_stats.loop_coords{modelIt} = loop_coords(1:count);
                % want to save which nodes were taken out, either at first
                % cutoff check (before interp. check), or if none were
                % detected then, then at first cutoff check after interp.
                % check. But interpolation can add/remove nodes, and we
                % want the nodes removed list to have a one-to-one
                % correspondence with the # centerline nodes from the last
                % timestep. Therefore, for nodes removed record the fractional distance along
                % the centerline rather than the absolute node number.
                
                remove_dist_start = interp1q((1:numel(centerline.X))',rel_dist_all_nodes,u);
                remove_dist_start=remove_dist_start(:);
                remove_dist_end = interp1q((1:numel(centerline.X))',rel_dist_all_nodes,d);
                remove_dist_end = remove_dist_end(:);
                cutoff_interp_stats.nodes_removed_ranges{modelIt}=[remove_dist_start,remove_dist_end]; % starting, ending ranges for cutoffs, *node indices relative to original centerline*, which has been copied periodically.
            end
            
            % temporarily mark nodes to remove as NaN
            centerline.X(centerline_nodes_remove)=NaN; 
            centerline.Y(centerline_nodes_remove)=NaN; 
            centerline.Z(centerline_nodes_remove)=NaN;
            
            % Clip centerline back to original length. Re-defines the first
            % index if it was removed in a cutoff.
            
            if ismember(orig_nodes_start_ind,centerline_nodes_remove)
            % if first node has been removed in a cutoff, take the first node after x=0 as new first node, and its repetition domain.xExtent later as end.
                ind_start=find(centerline.X>domain.xExtent(1),1,'first');    
            else
                ind_start=orig_nodes_start_ind;
            end
            ind_end = find(and(abs(centerline.X-centerline.X(ind_start)-domain.xRange)<1e-3,abs(centerline.Y-centerline.Y(ind_start))<1e-3));
            
            if isempty(ind_end)
                if ~full_planform
                    full_planform=true;
                    % re-set centerline to the input form
                    centerline = centerline_before_cutoff_check;
                else
                    if isempty(ind_end)
                        err='Error (cutoff_interpolation.m/cutoff_check): No ending node index assigned for centerline';
                        filename=[outputDir,'run_',trial,'_error_data.mat'];
                        save(filename)
                        error(err) 
                    end
                end
            else
                centerline.X=centerline.X(ind_start:ind_end); 
                centerline.Y=centerline.Y(ind_start:ind_end);
                centerline.Z=centerline.Z(ind_start:ind_end);
                % remove the nodes that were in cutoff loops. (Do this two-step
                % removal so that ind_start always refers to index in
                % centerline prior to cutoff loop removal).
                centerline.X(isnan(centerline.X))=[];
                centerline.Y(isnan(centerline.Y))=[]; 
                centerline.Z(isnan(centerline.Z))=[];    
            end
        else
            centerline = centerline_before_cutoff_check;
            checked_and_no_cutoffs = true;
        end
        
        if abs(centerline.X(end)-centerline.X(1)-domain.xExtent)>0.1
            err='Error (cutoff_interpolation.m/cutoff_check): Centerline X-coodinate range exceeded';
            filename=[outputDir,'run_',trial,'_error_data.mat'];
            save(filename)
            error(err) 
        end
    end % end nested cutoff_check function
end % end function