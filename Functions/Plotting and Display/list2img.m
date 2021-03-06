function [In, imaxes] = list2img(mlist,varargin)
%--------------------------------------------------------------------------
% I = list2img(mlist)  take the cell array of molecule lists (mlist) and
%                    return a STORM image. If there are multiple elements
%                    in mlist this will be a multicolor STORM image.  
%                    Different colors channels will be in the different 
%                    elements of the cell array I.  If 'Zsteps' option is
%                    >1, the images will be 3D (see Outputs below).  
%
%  I = list2img(mlist,imaxes)
%  I = list2img(mlist,'ParameterName',value,...)
%  [I,imaxes] = list2img(mlist,'ParameterName',value,...)
%  I = list2img(mlist,imaxes,'ParameterName',value,...)
%--------------------------------------------------------------------------
%  Inputs   
%           mlist - 1xn cell where n is the number of channels in the
%                     data.  Each cell contains a molecule list structure
%                     with the categories .xc, .yc, .a etc specifying
%                     molecule positions.  class specifies molecule class. 
% 
%--------------------------------------------------------------------------
% Outputs
% I / cell array   -- a cell array of size the number of color channels.
%               Each element contains an image HxWxN, where N is the number
%               of distinct levels / colors in the z-dimension.  For 2D
%               images all elements of I are 2D.  
%
%--------------------------------------------------------------------------
% % Optional Inputs
%  'filter' / cell of logical vectors / all true
%                 cell of logical arrays the same same length as the
%                 corresponding molecule list in the mlist array.  Only the
%                 molecules indicated by the filter will be plotted. 
%  'dotsize'
%                 Factor to scale the rendered dots by;
%  'Zsteps' / scalar / 1
%                 Number of distinct colors if plotting color as z.  
%                 set equal to 1 for regular 2D images
%  'Zrange' / vector / [-500 500]
%                 if plotting color as z, what range should the color bar 
%                 extend over.
%  'nm per pixel' / scalar / 160
%                  used by scalebar;
%  'scalebar' / scalar / 500
%                 size of scalebar in nm. set to 0 to turn off;
% 'correct drift' / boolean / true
%                 use xc/yc or x/y elements of moleucle list;
%  'Fast' / boolean / true
%                 fastMode =  CheckParameter(parameterValue,'boolean','Fast');
%  'N' / integer / 6
%                 Number of distinct molecule widths to plot.  Make this
%                 smaller to accelerate image rendering
%  'verbose' / boolean / true
%                 print text notes to command line? 
%  'very verbose' / bolean / true
%                 print out image properties for troubleshooting
%  'zoom' / scalar / 10
%                 instead of passing a full imaxes structure, just pass
%                 zoom. 
%   'wc' / array / []
%                 optionally specify array of dot sizes; 
%-------------------------------------------------------------------------- 
% Related Functions
% see: STORMcell2img
% 
%--------------------------------------------------------------------------  
% Alistair Boettiger                                  Date Begun: 08/11/12
% Zhuang Lab                                        Last Modified: 12/30/13 
  


%% Hard coded inputs
%--------------------------------------------------------------------------
global ScratchPath %#ok<NUSED>


%--------------------------------------------------------------------------
%% Default inputs
%--------------------------------------------------------------------------
N = 6; 
dotsize = 4;
Zs = 1;
Zrange = [-500,500]; % range in nm 
npp = 160; 
scalebar = 500;
scalebarWidth = 1;
zm = 10; 
CorrectDrift = true;
showScalebar = true;
fastMode = false;
verbose = false;
veryverbose = false;
autocontrast = true; 
wc = [];  % optionally specify array of dot sizes; 

if isstruct(mlist)
    mlist = {mlist};
end
Cs = length(mlist);
chns = find(true - cellfun(@isempty,mlist))';
[ch,cw] = size(chns); 
if ch>cw; chns = chns'; end % must be row vector! 
infilter = cell(1,Cs);

for c=chns
    infilter{c} = true(length(mlist{c}.xc),1);
end

% If imaxes is not passed as a variable
if nargin == 1 || ischar(varargin{1})
    imaxes.zm = []; % default zoom; 
    imaxes.scale = 1;    
    molist = cell2mat(mlist);
    allx = cat(1,molist.xc);
    ally = cat(1,molist.yc);
    imaxes.xmin =  floor(min(allx));
    imaxes.xmax = ceil(max(allx));
    imaxes.ymin = floor(min(ally));
    imaxes.ymax = ceil(max(ally));
elseif ~ischar(varargin{1})
    imaxes = varargin{1};
end

if nargin > 1 
    if ischar(varargin{1})
        varinput = varargin;
    else
        varinput = varargin(2:end);
    end
else
    varinput = [];
end
    

% Add necessary fields to a minimal imaxes;
%  minimal imaxes is just imaxes.zm; 
if ~isfield(imaxes,'scale'); imaxes.scale = 1; end
if ~isfield(imaxes,'H') && ~isfield(imaxes,'xmin');
    molist = cell2mat(mlist);
    allx = cat(1,molist.xc);
    ally = cat(1,molist.yc);
    imaxes.xmin =  floor(min(allx));
    imaxes.xmax = ceil(max(allx));
    imaxes.ymin = floor(min(ally));
    imaxes.ymax = ceil(max(ally));
    imaxes.H =  (imaxes.ymax - imaxes.ymin)*imaxes.zm*imaxes.scale;
    imaxes.W =  (imaxes.xmax - imaxes.xmin)*imaxes.zm*imaxes.scale; 
elseif ~isfield(imaxes,'H') && isfield(imaxes,'xmin'); 
    imaxes.H =  (imaxes.ymax - imaxes.ymin)*imaxes.zm;
    imaxes.W =  (imaxes.xmax - imaxes.xmin)*imaxes.zm; 
else
    H = imaxes.H;
    W = imaxes.W;
end
    

if ~isfield(imaxes,'xmin'); imaxes.xmin = 0; end
if ~isfield(imaxes,'xmax'); imaxes.xmax = H; end
if ~isfield(imaxes,'ymin'); imaxes.ymin = 0; end
if ~isfield(imaxes,'ymax'); imaxes.ymax = W; end



%--------------------------------------------------------------------------



%--------------------------------------------------------------------------
% Parse variable input
%--------------------------------------------------------------------------

if ~isempty(varinput)
    if (mod(length(varinput), 2) ~= 0 ),
        error(['Extra Parameters passed to the function ''' mfilename ''' must be passed in pairs.']);
    end
    parameterCount = length(varinput)/2;
    for parameterIndex = 1:parameterCount,
        parameterName = varinput{parameterIndex*2 - 1};
        parameterValue = varinput{parameterIndex*2};
        switch parameterName
            case 'filter'
                infilter = parameterValue;
            case 'dotsize'
                dotsize = CheckParameter(parameterValue,'positive','dotsize');
            case 'Zsteps'
                Zs = CheckParameter(parameterValue,'positive','Zsteps');
            case 'Zrange'
                Zrange = CheckParameter(parameterValue,'array','Zrange');
            case 'nm per pixel'
                npp = CheckParameter(parameterValue,'positive','nm per pixel');
            case 'scalebar'
                scalebar = CheckParameter(parameterValue,'nonnegative','scalebar');
            case 'scalebarWidth'
                scalebarWidth = CheckParameter(parameterValue,'positive','scalebarWidth');
            case 'correct drift'
                CorrectDrift = CheckParameter(parameterValue,'nonnegative','correct drift');
            case 'Fast'
                fastMode =  CheckParameter(parameterValue,'boolean','Fast');
            case 'N'
                N  = CheckParameter(parameterValue,'positive','N');
            case 'verbose'
                verbose = CheckParameter(parameterValue,'boolean','verbose');
            case 'very verbose'
                veryverbose = CheckParameter(parameterValue,'boolean','very verbose'); 
            case 'zoom'
                zm = CheckParameter(parameterValue,'positive','zoom');
            case 'autocontrast'
                autocontrast = CheckParameter(parameterValue,'boolean','autocontrast');
            case 'wc'
                wc = CheckParameter(parameterValue,'array','wc');
            otherwise
                error(['The parameter ''' parameterName ''' is not recognized by the function ''' mfilename '''.']);
        end
    end
end

if isempty(imaxes.zm)
    imaxes.zm = zm;
    imaxes.H =  (imaxes.ymax - imaxes.ymin)*imaxes.zm*imaxes.scale;
    imaxes.W =  (imaxes.xmax - imaxes.xmin)*imaxes.zm*imaxes.scale; 
end

%% More input conversion stuff


% (mostly shorthand)
zm = imaxes.zm*imaxes.scale; % pixel size
W = round(imaxes.W*imaxes.scale); % floor(w*zm);
H = round(imaxes.H*imaxes.scale); %  floor(h*zm);   % W

if length(dotsize) < Cs
    dotsize = repmat(dotsize,Cs,1);
end

if veryverbose
    disp(imaxes);
end


%% Main Function
%--------------------------------------------------------------------------

ltic = tic;

% 
if scalebar < 1
    showScalebar = false; 
end

% initialize variables
x = cell(Cs,1); 
y = cell(Cs,1); 
z = cell(Cs,1); 
sigC = cell(Cs,1); 

for c=chns
    if CorrectDrift
        x{c} = mlist{c}.xc;
        y{c} = mlist{c}.yc;
        z{c} = mlist{c}.zc;
    else
        x{c} = mlist{c}.x;
        y{c} = mlist{c}.y;
        z{c} = mlist{c}.z;
    end
end

if Cs < 1
    return
end
  
  
% Min and Max Z
zmin = Zrange(1);
zmax = Zrange(2); 
Zsteps = linspace(zmin,zmax,Zs);
Zsteps = [-inf,Zsteps,inf];

In = cell(Cs,1);

for c=chns   
    
    if isempty(wc)
        wc = linspace(.01*dotsize(c), .05*dotsize(c),N+1)*zm; 
    else
        N = length(wc);
    end
    % Min and Max Sigma
    a = mlist{c}.a;
    sigC{c} = real(4./sqrt(a)); % 5
    sigs = sort(sigC{c});
    min_sig = sigs(max([round(.01*length(sigs)),1]));
    max_sig = sigs(round(.99*length(sigs)));
    gc = fliplr(800*linspace(.5,8,N+1)); % intensity of dots. also linear in root photon number
    wdth = linspace(min_sig, max_sig,N+1); 
    wdth(end) = inf; 
 
    
    % actually build image
    maxint = 0; 
     Iz = zeros(H,W,Zs);          
     for k=1:Zs
         I0 = zeros(H,W);          
         inZ =  z{c} >= Zsteps(k) & z{c} < Zsteps(k+2);
         for n=1:N
             inbox = x{c}>= imaxes.xmin & x{c} < imaxes.xmax & ...
                     y{c}>= imaxes.ymin & y{c} < imaxes.ymax;
            inW = sigC{c} >= wdth(n) & sigC{c} < wdth(n+1);
            plotdots = inbox & inW & inZ & infilter{c} ; % find all molecules which fall in this photon bin        
            xi = x{c}(plotdots)*zm-imaxes.xmin*zm;
            yi = y{c}(plotdots)*zm-imaxes.ymin*zm;
           
            It = hist3([yi,xi],'Edges',{0:H-1,0:W-1}); % drop all molecules into chosen x,y bin   {1.5:h*zm+.5, 1.5:w*zm+.5}
            gaussblur = fspecial('gaussian',250,wc(n)); % create gaussian filter of appropriate width
            if ~fastMode
                It = imfilter(gc(n)*It,gaussblur); % convert into gaussian of appropriate width
            end
          %  figure(3); clf; imagesc(It); title(num2str(n));
            I0 = I0 + It;
         end
         Iz(:,:,k) = I0; 
     end
      maxint = max(Iz(:)) + maxint; % compute normalization
      if autocontrast
        Iz = uint16(2^16*double(Iz)./double(maxint)); % normalize
      else
          Iz = uint8(Iz); % normalize  
      end
     In{c} = Iz; % record
   
    if showScalebar
        scb = round(1:scalebar/npp*zm);
        h1 = round(.9*H);
        In{c}(h1:h1+2*scalebarWidth,10+scb,:) = 2^16*ones(1+2*scalebarWidth,length(scb),Zs,'uint16'); % Add scale bar and labels
    end  
     
end

ltime = toc(ltic);
if verbose
disp(['list2img took ',num2str(ltime,4),' s']); 
end
% figure(1); clf; Ncolor(In{1}); colormap hot;


% 

% % Good display code for troubleshooting.  Redundant with command in movie2vectorSTORM core script   
% % normalize color channels and render
% % combine in multicolor image
%     h = 256; 
%     w = 256;   
%     nmpp = 160; % nm per pixel
%       I2 =zeros(h*zm,w*zm,3,'uint16');
%       I2(:,:,1) = mycontrast(In{1},.0005,0);
%       I2(:,:,2) = mycontrast(In{2},.0003,0);
%       if length(molist)==2
%           In{3} = zeros(h*zm,w*zm,1,'uint16');   
%           I2(:,:,3) =In{3}; % needs to be a 3 color image still
%       elseif length(molist)==3
%           I2(:,:,3) = mycontrast(In{3},.0003,0);
%       elseif length(molist)==4 % 4th color is magenta
%           I2(:,:,1) =  I2(:,:,1) + mycontrast(In{4},.0005,0);
%           I2(:,:,3) = mycontrast(In{3},.0003,0) + mycontrast(In{4},.0005,0);
%       end             
     
%      I2 =zeros(h*zm,w*zm,3,'uint16');
%      I2(:,:,1) = (In{1});
%      I2(:,:,2) = (In{2});
%      I2(:,:,3) = (In{3});
%      I2(240*zm+1:241*zm,10*zm+1:14*zm,:) = 255*ones(1*zm,4*zm,3,'uint8');
%      figure(1); clf; imagesc(I2); 

% It = zeros(100,100,'uint16');
% It(50,50) = 2^16; wc = 4;
%  gaussblur = fspecial('gaussian',30,wc);
% Io = imfilter(It,gaussblur);
% figure(6); clf; imagesc(Io); 
%      
