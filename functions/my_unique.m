function[out]=my_unique(in)
% my_unique.m: Faster version of MATLAB built-in function "unique". 
% Input arguments:
%   in: vector of input values
% Output arguments:
%   out: vector of unique values.
	if all(size(in))>1
        err='Error (my_unique.m): array input, vector expected';
        filename=[outputDir,'run_',trial,'_error_data.mat'];
        save(filename)
		error(err)
	end			  	  
    [in_sort,ind_sort]=sort(in(:));
    unique_vals=[true;diff(in_sort)>0];
    ind_sort_unique=ind_sort(unique_vals);
    ind_sort_unique=sort(ind_sort_unique);
    out=in(ind_sort_unique);
end