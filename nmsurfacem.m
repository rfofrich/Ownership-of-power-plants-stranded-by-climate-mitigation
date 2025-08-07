
function nmsurfacem(lat,lon,data)

% nmsurfacem(lat,lon,data)
%
% A function that calls surfacem and plots grid cells that are centered on
% the assigned lat / lon points. A call to surfacem without this helper
% function will plot grid cells down and to the right of the assigned
% points.

degstep = abs(lat(2)-lat(1));

%degstep = 0;

lonplot = lon - degstep;
latplot = lat + degstep;

if size(data,1) == length(latplot)
    surfacem(double(latplot),double(lonplot),double(data))
else
    surfacem(double(latplot),double(lonplot),double(data)')
end
