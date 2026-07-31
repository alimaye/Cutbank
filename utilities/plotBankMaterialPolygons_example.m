% plotBankMaterialPolygons_example.m: Example script to plot 
% polygons used for bank-material tracking.

clear,clc,close all

load vector_data_example.mat 'Data' 'voidpoly' 'domain'

for i=1:numel(Data)
    if ~isempty(Data(i).bdrk_topo_polygon)
        for j=1:numel(Data(i).bdrk_topo_polygon)
            hold on, patch(Data(i).bdrk_topo_polygon(j).x,Data(i).bdrk_topo_polygon(j).y,'g') % plot all polygons, including holes, for simplicity
        end
    end
end

for i=1:numel(voidpoly)
    hold on, patch(voidpoly(i).x,voidpoly(i).y,[0.5 0.5 0.5])  % plot all polygons, including holes, for simplicity
end
axis equal

% Plot youngest polygon as yellow
for i=500
    if ~isempty(Data(i).bdrk_topo_polygon)
        for j=1:numel(Data(i).bdrk_topo_polygon)
            hold on, patch(Data(i).bdrk_topo_polygon(j).x,Data(i).bdrk_topo_polygon(j).y,'y')
        end
    end
end

% set axis to limit of bank material polygons
set(gca,'xlim',domain.xExtent)
set(gca,'ylim',[-1000 1000]) % quick version

xlabel('Distance (m)')
ylabel('Distance (m)')
title("Bank-material polygons (youngest in yellow)")



