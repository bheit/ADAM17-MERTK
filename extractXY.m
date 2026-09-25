%% Function to extract diffusion tracks and scale x/y to match eSRRF images
% Must be run in a folder containing testOneCells.mat from the tracking 
% software of Jaqaman, K., Loerke, D., Mettlen, M. et al. Robust single-particle
% tracking in live-cell time-lapse sequences. Nat Methods 5, 695–702 (2008). 
% https://doi.org/10.1038/nmeth.1237.
%
% Output is separate X/Y coordinate files for freely diffusing and confined tracks
%
% Bryan Heit - September 2026

SRRFscale = 5; %magnfiication used for SRRF reconstrucitons
load('testOneCells.mat', 'confinedBrownianTracks','pureBrownianTracks');
trackIndex  = ExtractTracks([]);
freeTracks = trackIndex(pureBrownianTracks,:);
confinedTracks = trackIndex(confinedBrownianTracks,:);

freeX = round(freeTracks(:,1:8:end).*SRRFscale);
freeX(isnan(freeX)) = 0;
freeY = round(freeTracks(:,2:8:end).*SRRFscale);
freeY(isnan(freeY)) = 0;
confX = round(confinedTracks(:,1:8:end).*SRRFscale);
confX(isnan(confX)) = 0;
confY = round(confinedTracks(:,2:8:end).*SRRFscale);
confY(isnan(confY)) = 0;

maxX = max([max(freeX(:)),max(confX(:))])
maxX = max([max(freeY(:)),max(confY(:))])

writematrix(freeX, 'freeX.csv');
writematrix(freeY, 'freeY.csv');
writematrix(confX, 'confinedX.csv');
writematrix(confY, 'confinedY.csv');

clear;