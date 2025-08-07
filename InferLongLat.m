function [Long,Lat,Long2,Lat2]=InferLongLat(Data)
%INFERLONGLAT constructs long and lat vectors for map
%
%  Syntax
% [Long,Lat]=InferLongLat(Data)
%
% [Long,Lat,Long2,Lat2]=InferLongLat(Data)
%
% EXAMPLE
% [long,lat]=InferLongLat(testdata);

if nargin==0
   disp([' assuming 5minute grid '])
   Data=datablank;
    
%    help(mfilename);
%    return
end

[Nrow,Ncol,Level]=size(Data);

%the next two lines are a lazy way to get Long to take on the
%values of the centers of the bins
tmp=linspace(-1,1,2*Nrow+1);
Long=180*tmp(2:2:end).';

tmp=linspace(-1,1,2*Ncol+1);
Lat=-90*tmp(2:2:end).';


%warning(['Have constructed Lat and Long with assumption that data' ...
%	   ' spans the globe.  It would be better to put in code that' ...
%	   ' looks to see if the dimensions are "standard" (e.g. 5' ...
%	   ' minutes) and if so use "standard" Lat/Long definitions.']);

if nargout >2
    [Lat2,Long2]=meshgrid(Lat,Long);
end