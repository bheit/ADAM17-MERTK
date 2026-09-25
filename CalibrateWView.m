function [xShift, yShift, alignmentMatrix] = CalibrateWView (OpenFig)
%
% Function to calculate the SPT alignment of the W-View beyween the Cy3 adn
% Cy5 channels. Short (10+ frames) timelapses of tetraspeck beads need to
% be pre-tracked using the SPT software prior to this analysis. 
% 
% ***Do not run MMF for this tracking***
%
% This needs to be done before each experiment as the alignment of the 
% W-View canchange day-to-day. The "trackedfeatures.mat" file from the 
% single-cell analysis folders for the Cy3 and Cy5 channels is required.
%
% Input Variables:
%   -Cy3: The 'trackedfeature.mat' file for the Cy3 channel
%   -Cy5: The 'trackedfeature.mat' file for the Cy5 channel
%   -pixSize: Nearest0-neighbour cutoff; if a matching track isn't located
%   within this range a particle is assumed to be unpaired and is ignored
%   in the analysis
%   -OpenFig: if set >0 keeps the alignment figure open at the end of the
%   run. If unset or set to 0 the figure auto-closes
%
% Output Variables:
%   -xShift: the shift in the x-axis for the image centre, in pixels
%   -yShift: the shift in the y-axis for the image centre, in pixels
%   -alignmentMatrix: full alignment matrix for the entire image
%
% Bryan Heit
% October 3, 2025

%% Check Inputs
% if (nargin ~= 2)
%     error ('Incorrect number of input arguments');
% end

[Cy3, workingDir] = uigetfile('*.mat','Select the Cy3 Tracking File');
cd (workingDir);
load(Cy3, 'tracksFinal');
for ii=1:size (tracksFinal,1)
    dX = tracksFinal(ii).tracksCoordAmpCG(1:8:end);
    dY = tracksFinal(ii).tracksCoordAmpCG(2:8:end);
    Cy3_Positions(ii,1) = mean(dX);
    Cy3_Positions(ii,2) = mean(dY);
end
Cy3_Positions = Cy3_Positions(~any(isnan(Cy3_Positions), 2), :);
clear tracksFinal dX dY

Cy5 = uigetfile('*.mat','Select the Cy5 Tracking File');
load(Cy5, 'tracksFinal');
for ii=1:size (tracksFinal,1)
    dX = tracksFinal(ii).tracksCoordAmpCG(1:8:end);
    dY = tracksFinal(ii).tracksCoordAmpCG(2:8:end);
    Cy5_Positions(ii,1) = mean(dX);
    Cy5_Positions(ii,2) = mean(dY);
end
Cy5_Positions = Cy5_Positions(~any(isnan(Cy5_Positions), 2), :);
clear tracksFinal dX dY

%set maximum filter distance based on 1.5X pixel size
prompt = {'Enter the maximum paired-distance threshold cutoff, in pixels'};
dlgtitle = 'Distance Threshold';
fieldsize = [1 40];
definput = {'5'};
pixSize = inputdlg(prompt,dlgtitle,fieldsize,definput);
pixSize = str2double(pixSize(1));

alignmentMatrix.Cy3Positions = Cy3_Positions;
alignmentMatrix.Cy5Positions = Cy5_Positions;
alignmentMatrix.distanceCutoff = pixSize;

%% Find Nearest Cross-Neighbour
displacements = zeros(size(Cy3_Positions,1),5); %Cy3X, Cy3Y, dX, dY, Eucld
for ii=1:size(Cy3_Positions(:,1))
    Idx = knnsearch(Cy5_Positions(:,1:2), Cy3_Positions(ii,1:2));
    displacements(ii,1:2) = Cy3_Positions(ii,1:2);
    displacements(ii,3) = Cy3_Positions(ii,1)-Cy5_Positions(Idx,1);
    displacements(ii,4) = Cy3_Positions(ii,2)-Cy5_Positions(Idx,2);
    displacements(ii,5) = sqrt((Cy3_Positions(ii,1)-Cy5_Positions(Idx,1))^2+(Cy3_Positions(ii,2)-Cy5_Positions(Idx,2))^2);
end

%remove impossible values (>1.5 pixel diamters)
noMatch = displacements(:,5) < pixSize;
displacements = displacements(noMatch, :);


%separate middle of image (x: 125:375, y: 300:900)
centreDisp = displacements(displacements(:,1)<375,:);
centreDisp = centreDisp(centreDisp(:,1)>125,:);
centreDisp = centreDisp(centreDisp(:,2)<900,:);
centreDisp = centreDisp(centreDisp(:,2)>300,:);


%edge-trim image (x: 50:450, y: 100:max-50)
edgeDisp = displacements(displacements(:,1)<450,:);
edgeDisp = edgeDisp(edgeDisp(:,1)>50,:);
maxYcoord = max(displacements(:,2));
edgeDisp = edgeDisp(edgeDisp(:,2)<(maxYcoord-100),:);
edgeDisp = edgeDisp(edgeDisp(:,2)>50,:);


xShift(1) = mean(displacements(:,3));
xShift(2) = mean(centreDisp(:,3));
xShift(3) = mean(edgeDisp(:,3));
yShift(1) = mean(displacements(:,4));
yShift(2) = mean(centreDisp(:,4));
yShift(3) = mean(edgeDisp(:,4));
alignmentMatrix.displacements = displacements;
alignmentMatrix.xShift = xShift;
alignmentMatrix.yShift = yShift;
alignmentMatrix.centreDisp = centreDisp;
%% Plot Data

%invert y-axis for plotting
gData = zeros(size(displacements,1),3); %X/Y/euclid
C5Data = zeros(size(displacements,1),2); %X/Y
gData(:,1) = displacements(:,1);
C5Data(:,1) = displacements(:,1)-displacements(:,3);
gData(:,3) = displacements(:,5);
minY = min(displacements(:,2));
maxY = max(displacements(:,2));
dY = maxY+minY;
gData(:,2) = dY-displacements(:,2);
C5Data(:,2) = gData(:,2)+displacements(:,4);

cData = zeros(size(centreDisp,1),3); %X/Y/euclid
cData(:,1) = centreDisp(:,1);
cData(:,3) = centreDisp(:,5);
minY = min(centreDisp(:,2));
maxY = max(centreDisp(:,2));
dY = maxY+minY;
cData(:,2) = dY-centreDisp(:,2);

tCy5 = Cy5_Positions(:,1:2);
minY = min(tCy5(:,2));
maxY = max(tCy5(:,2));
dY = maxY+minY;
tCy5(:,2) = dY-tCy5(:,2);

%plot displacement map
figure
set(gcf, 'Position',  [2, 2, 950, 950])
subplot(1,2,1)
hold on
N = 100;
x = vertcat(gData(:,1));
y = vertcat(gData(:,2));
z = vertcat(gData(:,3));
[X, Y] = meshgrid(linspace(min(x)-0.2, max(x)+0.2, N), linspace(min(y)-0.2, max(y)+0.2, N));
F = scatteredInterpolant(x, y, z);
Z = F(X, Y);
contourf(X, Y, Z, 100);
axis ([0, 550, 50, 1000]);
colorbar();
title ('Precision Contour Map');
rectangle('Position',[125,300,250,600], 'EdgeColor','w');
rectangle('Position',[50,100,450,(maxYcoord-100)], 'EdgeColor','y');
scatter(gData(:,1),gData(:,2), '.', 'r')
hold off

%plot positions
subplot(1,2,2)
hold on
scatter(C5Data(:,1), C5Data(:,2),'.', 'k')
scatter(gData(:,1),gData(:,2), 'r') 
%scatter(tCy5(:,1),tCy5(:,2), '.', 'k')
axis ([0, 550, 50, 1000]);
title ('Fluorophore Positions');
rectangle('Position',[125,300,250,600], 'EdgeColor','b');
rectangle('Position',[50,100,450,(maxYcoord-100)], 'EdgeColor','y');
text(130,310,[num2str(xShift(2)) ', ' num2str(yShift(2))],'FontSize',8, 'Color','k');
text(60,110,[num2str(xShift(3)) ', ' num2str(yShift(3))],'FontSize',8, 'Color','k');
text(40,75,[num2str(xShift(1)) ', ' num2str(yShift(1))],'FontSize',8, 'Color','k');
legend('Cy3','Cy5')

hold off

saveas(gcf,'WView_Calibration.pdf');
save('WView_Calibration.mat', 'xShift', 'yShift', 'alignmentMatrix');

if nargin == 1
    if OpenFig == 0
        close (gcf);
    end
else
    close (gcf);
end

end %end function

