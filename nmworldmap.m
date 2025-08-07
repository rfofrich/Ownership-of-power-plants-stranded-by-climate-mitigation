function nmworldmap(MD,latlim,lonlim,unitstr,cbinfo,clim,splabel,triangleflagvector, triflags)

% latlim = [-60 65];
% lonlim = [-150 180];

% create axes
HT=figure; set(HT,'Position',[440 378 350*1.5 267*1.5]); axis off; hold on;
mh = worldmap(latlim, lonlim);

% % load country data
% WORLDCOUNTRIES_LEVEL0_HIRES = [iddstring ...
%     'AdminBoundary2010/WorldLevel0Coasts_RevAr0_HiRes.mat'];
% countries=load(WORLDCOUNTRIES_LEVEL0_HIRES);

% if essentially global, go with robinson projection, otherwise use default
% projection
if lonlim(1)<-140 && lonlim(2)>150
    setm(mh,'mapprojection','mercator');
end

% adjust position
pos = get(mh,'position');
newpos = [pos(1)-.21 pos(2)-.18 pos(3).*1.5 pos(4).*1.5];
set(mh,'position',newpos)

% setm(mh,'grid','off')
setm(mh,'meridianlabel','off')
setm(mh,'parallellabel','off')

% draw gray background under global land areas
% cd = load('coast');
% ph = fillm(cd.lat,cd.long,[.97 .97 .97]);
% set(ph,'LineStyle','none');

cd = load('coastlines');
ph = fillm(cd.coastlat,cd.coastlon,[1 1 1]);
set(ph,'LineStyle', '-'); 
%set(ph,'LineStyle', 'none'); %10/11/19


if isstruct(MD) % then scattermap
    
    % first plot coastal boundary
    plotm(cd.coastlat,cd.coastlon,'-k');
    
    % scatter map
    if MD.dsize ==0
        % use adaptive dot size - smaller in N America and bigger elsewhere
        ii = MD.lats>0 & MD.lons<-30;
        scatterm(MD.lats(ii),MD.lons(ii),10,MD.data(ii),'.');
        scatterm(MD.lats(~ii),MD.lons(~ii),35,MD.data(~ii),'.');
    else
        scatterm(MD.lats,MD.lons,MD.dsize,MD.data,'.');
    end
    
else % raster data
    
    % check orientation
    tmp = size(MD);
    if tmp(2)>tmp(1)
        MD = MD';
    end
    
    % plot raster data
    [long,lat] = InferLongLat(MD);
    nmsurfacem(lat,long,MD);
    
    %     % plot countries in light gray
    %     hq=plotm(countries.lat,countries.long);
    %     set(hq,'linewidth',.25); set(hq,'Color',[.5 .5 .5])
    
    % overlay coastal boundary
    plotm(cd.coastlat,cd.coastlon,'-k');
    
end

switch cbinfo 
    case 'bluegrayred'
        load cb_bluegrayred; cmap = cb_bluegrayred; 
    case 'grayblue'
        load cb_bluegrayred; cmap = flipud(cb_bluegrayred(1:32,:));
    case 'grayred'
        load cb_bluegrayred; cmap = cb_bluegrayred(33:64,:);
    case 'redgray'
        load cb_bluegrayred; cmap = flipud(cb_bluegrayred(33:64,:));
    case 'redgrayblue'
        load cb_bluegrayred; cmap = flipud(cb_bluegrayred);
    case 'redgrayblue3/4'
        load cb_bluegrayred; cmap = flipud(cb_bluegrayred(1:48,:));
    case 'redgrayblue2080' 
        load cb_bluegrayred; cmap = flipud(cb_bluegrayred(1:40,:));
    case 'bluegrayred0220' 
        load cb_bluegrayred; cmap = cb_bluegrayred([15,20,25,33:64],:);
    case 'tangreenblue'
        load cb_tangreenblue; cmap = cb_tangreenblue;
    case 'orangegraybrightgreen'
        load cb_orangegraybrightgreen; cmap = cb_orangegraybrightgreen;
    case 'graygreen'
        load cb_graygreen; cmap = cb_graygreen;
    case 'graybrightgreen'
        load cb_graybrightgreen; cmap = cb_graybrightgreen;
    case 'brownredtangreenblue'
        load brownredtangreenblue; cmap = brownredtangreenblue;
    case 'brownredgraygreenblue'
        load brownredgraygreenblue; cmap = brownredgraygreenblue;
    case 'mycmap'
        load mycmap; cmap = mycmap;
    case 'neghalftotwo'
        load MyColormap3; cmap = mymap3;
    case 'pvalmap'
        load MyColormap2; cmap = mymap2;
    case 'rev_pvalmap'
        load rev_pvalmap; cmap = rev_pvalmap;
    case 'parula'
        % load cb_parula; cmap = flipud(cb_parula);
        colormap(parula); cmap = colormap;
    case 'winter'
        % load cb_parula; cmap = flipud(cb_parula);
        colormap(winter); cmap = colormap;

end
%Lindseys colormap
% colormap(cmap);

%red blue diverging colormap
colors = cell2mat(struct2cell(load('BrGnmap.mat')));
colormap(colors)

if nargin > 5
    set(gca,'clim',clim);
end

% colorbar
if ~strncmp(unitstr,'none',4) % skip if 'none' is specified as unitstr
    cbh1=colorbar('horiz');
    initpos = get(cbh1,'Position');
    set(cbh1,'Position',[initpos(1)+initpos(3)*0.15 ...
        initpos(2)+initpos(4) initpos(3)*0.7 initpos(4)*0.5], 'fontweight','bold');
    newpos = get(cbh1,'Position');
    set(cbh1,'Position',[newpos(1) newpos(2)-.05 newpos(3) newpos(4)])
    h1=xlabel(cbh1,unitstr);
%     font(h1,17); font(gca,17); 
end

if nargin>6
    haxnew = axes; set(haxnew,'Visible','off');
     h=axis;h=text(-.08,0.82,splabel);
%    h=axis;h=text(.4,.9,splabel);
%    font(h,16); 
   set(h,'fontweight','bold');
end

% % add panoply triangles if requested
if nargin > 7
    if sum(triflags)>0
        endcolor=cmap(end-1,:);
        startcolor=cmap(2,:);
        
        %create a new axis, but make it invisible
        haxnew=axes('visible','off','position',[0 0 1 1],...
            'fontunits','normalized');

        
%                 cbpos = get(cbh1,'Position');
%                 end_x=cbpos(1) + cbpos(3) + (cbpos(4)/2);
%                 end_y=cbpos(2);
        
%         end_x=0.885;
%        end_y=0.1;

%          end_x=0.915;
%          end_y=0.22;
         
         end_x=0.91;
         end_y=0.222;
        
        start_x=1.002-end_x;
        start_y=end_y;
        
%         tri_x=[0 0 .0175 0];
%         tri_y=[0 .025 .0125 0];
         
         tri_x=[0 0 .0175 0];
         tri_y=[0 .03 .0125 0];
   
        tri_x=[0 0 .012 0];
        tri_y=[0 .026 .012 0];


        
  %       h=[-1 -1];   % initialize to -1
   h=[1 1];
         
        if triangleflagvector(2) == 1
            h(2)= patch(end_x+tri_x,end_y+tri_y,endcolor)
        end
        if triangleflagvector(1) == 1
            h(1)= patch(start_x-tri_x,start_y+tri_y,startcolor)
        end
        
        ZeroXlim(0,1)
        ZeroYlim(0,1)
        
        patchhandles=[h(1) h(2) haxnew];

    end
end





