function out=datablank(Val,Res)
% DATABLANK - initialize a matrix 
%
% Syntax
%
%    out=datablank(VAL,RES)    RES can be '5min' (default) or '30min',
%    '15min', '2.5deg', '10min','1min'
%
%    out=datablank(MATRIX)     will return a MATRIX size matrix of ones
%    (this syntax is sort of stupid, but it makes the code slightly easier
%    to read.)
%
%  EXAMPLE
%
%    HoldingMatrix=datablank(-9);  will create a 5min sized matrix
%    of -9
if nargin<1
    Val=0;
end
if nargin<2
    Res='5min';
end

switch Res
    case '2.5deg'
        tmp=ones(144,72);
    case {'.25deg','15min'}
        tmp=ones(1440,720);
    case {'1deg','60min'}
        tmp=ones(360,180);
   case '30min'
        tmp=ones(720,360);
    case '10min'
        tmp=ones(2160,1080);
    case '5min'
        tmp=ones(4320,2160);
    case {'3min','.05deg'}
        tmp=ones(7200,3600);
        case '30s'
        tmp=ones(43200,21600);
    case '1min'
        warning('warning:  this is going to be really huge');
        tmp=ones(21600,10800);
    otherwise
        error('Don''t know this resolution')
end

if numel(Val)>1
    out=Val*0;
else
    out=tmp*Val;
end