function outputMatrix = DualSPTAnalysis()
%
% Function to analyze dual-colour SPT tracks (pre-cropped and tracked) for
% nearest approaches and duration of potential interactions.
%
% Inputs:
%   -Cy3Input/Cy5Input: The diffusionAnalysisFinal.mat (or equivalent)
%    files for the Cy3 and Cy5 channels.
%   -Cy3Amp/Cy5Amp (optional): used to filter detected noise from the
%                          detected features prior to alignment. Values
%                          of 0.2-0.5 are usually good. Leave empty for no 
%                          filtering
%   -Cy3Label/Cy5Label: string labels indicating molecule tracked in Cy3
%    vs Cy5 channels
%   -minFrames: Minimum length (in frames) a track must be to be included
%    in the analysis
%   -interactDist: Distance (in nm) below which two particles are
%    considered to be interacting.
%   -frameRate = frame duration, in ms.
%   -pixelSize = size of pixels, in nm. 
%       -Calculated as (physical pixel size * binning)/Mag
%       -e.g. Fusion @ 100X: (6500 nm * bin2)/100 = 130 nm
%
% Outputs:
%   -TBD
%
% Bryan Heit, March 2026

%% Check inputs and load files
%gather input settings
InputValues = inputdlg({'Cy3 Amplitude Filtering, 0 = no filtering',...
    'Cy5 Amplitude Filtering, 0 = no filtering','Cy3 Channel Title',...
    'Cy5 Channel Title', 'Minimum Track Length to Analyze (in frames)', ...
    'Distance (in nm) below which two particles are considered to be interacting'...
    'frame duration, in ms', 'size of pixels, in nm'}, 'Cnfigure Tracking',...
    [1 50; 1 50;  1 50;  1 50; 1 50; 1 50; 1 50; 1 50;]); 

Cy3Amp = str2double(InputValues(1));
Cy5Amp = str2double(InputValues(2));
Cy3Label = char(InputValues(3));
Cy5Label = char(InputValues(4));
minFrames = str2double(InputValues(5));
interactDist = str2double(InputValues(6));
frameRate = str2double(InputValues(7));
pixelSize = str2double(InputValues(8));

%set track extraction criteria
 criteria.lifeTime.min=minFrames; 
 criteria.lifeTime.max=[];
 criteria.startTime.min=[];
 criteria.startTime.max=[];
 criteria.endTime.min=[];
 criteria.endTime.max=[];
 criteria.initialAmp.min=Cy3Amp;
 criteria.initialAmp.max=[];
 criteria.initialXCoord.min=[];
 criteria.initialXCoord.max=[];
 criteria.initialYCoord.min=[];
 criteria.initialYCoord.max=[];

[Cy3Input, workingDir] = uigetfile('*.mat','Select the Cy3 Tracking File');
cd (workingDir);
load (Cy3Input);
tracksMatrix= convStruct2MatIgnoreMS(tracksFinal);
trackInd=chooseTracks(tracksMatrix,criteria);
numSegmentsToAnalyze = length(trackInd);
Cy3Tracks = tracksMatrix(trackInd,:);
%extract x/y
for ii=1:size (Cy3Tracks,1) 
    Cy3X(ii,:) = Cy3Tracks(ii,1:8:end);
    Cy3Y(ii,:) = Cy3Tracks(ii,2:8:end);
end

criteria.initialAmp.min=Cy5Amp;

[Cy5Input, workingDir] = uigetfile('*.mat','Select the Cy5 Tracking File');
cd (workingDir);
load (Cy5Input);
tracksMatrix= convStruct2MatIgnoreMS(tracksFinal);
trackInd=chooseTracks(tracksMatrix,criteria);
numSegmentsToAnalyze = length(trackInd);
Cy5Tracks = tracksMatrix(trackInd,:);

%extract x/y
for ii=1:size (Cy5Tracks,1) 
    Cy5X(ii,:) = Cy5Tracks(ii,1:8:end);
    Cy5Y(ii,:) = Cy5Tracks(ii,2:8:end);
end

%Record inputs to output file
outputMatrix.inputs.workingDirectory = pwd;
outputMatrix.inputs.criteria = criteria;
outputMatrix.inputs.Cy3Input = Cy3Input;
outputMatrix.inputs.Cy5Input = Cy5Input;
outputMatrix.inputs.Cy3Amp = Cy3Amp;
outputMatrix.inputs.Cy5Amp = Cy5Amp;
outputMatrix.inputs.Cy3Label = Cy3Label;
outputMatrix.inputs.Cy5Label = Cy5Label;
outputMatrix.inputs.minFrames = minFrames;
outputMatrix.inputs.interactDist = interactDist;
outputMatrix.inputs.frameRate = frameRate;
outputMatrix.inputs.pixelSize = pixelSize;

[CalibrationFile, workingDir] = uigetfile('*.mat','Select the Calibration File');
cd (workingDir);
load('WView_Calibration.mat', 'xShift');
load('WView_Calibration.mat', 'yShift');

% Create the selection dialog
options = {'Use whole image calibration', 'Use centre region calibraiton', 'Use cropped edges calibraiton'};
selectionIndex = listdlg('PromptString', 'Select calibration area to use:', ...
                           'ListSize',[250,50],'SelectionMode', 'single', ...
                           'InitialValue', 2, 'ListString', options);

xShift = xShift(selectionIndex);
yShift = yShift(selectionIndex);

% adjust Cy5 positions.
Cy5X = Cy5X+xShift;
Cy5Y = Cy5Y+yShift;

%move to output directory
outPath = uigetdir(workingDir, 'Select the Output Directory');
cd (outPath);

%% Distance tables

%Cy3:Cy5
Cy3DistTable = zeros(size(Cy3X));
Cy3InteractorTable  = zeros(size(Cy3X));
for ii=1:size(Cy3X,1)
    for jj=1:size(Cy3X,2)
        if isnan(Cy3X(ii,jj))
            Cy3DistTable(ii,jj) = NaN;
            Cy3InteractorTable(ii,jj) = NaN;
        else
            Cy5temp(:,1) = Cy5X(:,jj);
            Cy5temp(:,2) = Cy5Y(:,jj);
            tDist = nearestneighbour([Cy3X(ii,jj);Cy3Y(ii,jj)],Cy5temp');
            Cy3DistTable(ii,jj) = sqrt(((Cy5temp(tDist,1)-Cy3X(ii,jj))^2)+(((Cy5temp(tDist,2)-Cy3Y(ii,jj))^2)));
            Cy3InteractorTable(ii,jj) = tDist;
        end
    end
end
Cy3DistTable = Cy3DistTable.*pixelSize;

%Cy5:Cy3
Cy5DistTable = zeros(size(Cy5X));
Cy5InteractorTable  = zeros(size(Cy5X));
for ii=1:size(Cy5X,1)
    for jj=1:size(Cy5X,2)
        if isnan(Cy5X(ii,jj))
            Cy5DistTable(ii,jj) = NaN;
            Cy5InteractorTable(ii,jj) = NaN;
        else
            Cy3temp(:,1) = Cy3X(:,jj);
            Cy3temp(:,2) = Cy3Y(:,jj);
            tDist = nearestneighbour([Cy5X(ii,jj);Cy5Y(ii,jj)],Cy3temp');
            Cy5DistTable(ii,jj) = sqrt(((Cy3temp(tDist,1)-Cy5X(ii,jj))^2)+(((Cy3temp(tDist,2)-Cy5Y(ii,jj))^2)));
            Cy5InteractorTable(ii,jj) = tDist;
        end
    end
end
Cy5DistTable = Cy5DistTable.*pixelSize;

% write to output variable
outputMatrix.distanceTables.Cy3X = Cy3X;
outputMatrix.distanceTables.Cy3Y = Cy3Y;
outputMatrix.distanceTables.Cy3DistTable = Cy3DistTable;
outputMatrix.distanceTables.Cy3InteractorTable = Cy3InteractorTable;
outputMatrix.distanceTables.Cy5X = Cy5X;
outputMatrix.distanceTables.Cy5Y = Cy5Y;
outputMatrix.distanceTables.Cy5DistTable = Cy5DistTable;
outputMatrix.distanceTables.Cy5InteractorTable = Cy5InteractorTable;

%% Extract Interacting Tracks
%Cy3 Tracks
Cy3InteractingTracks = [];
for ii=1:size(Cy3X,1)
    %identify potentially interacting tacks
    interactors = Cy3InteractorTable(ii,:);
    interactors = unique(interactors);
    interactors = interactors(~isnan(interactors));
    cTrack = zeros(size(interactors,2)+1,2*size(Cy3X,2));
    cTrack(1,1:2:end) = Cy3X(ii,:);
    cTrack(1,2:2:end) = Cy3Y(ii,:);

    for jj=2:size(cTrack,1)
        cTrack(jj,1:2:end) = Cy5X(interactors(jj-1),:);
        cTrack(jj,2:2:end) = Cy5Y(interactors(jj-1),:);
    end
    
    outputMatrix.Tracks.Cy3NNtrack(ii).RawTracks = cTrack;
    outputMatrix.Tracks.Cy3NNdist(ii) = min(Cy3DistTable(ii,:));
    
    if outputMatrix.Tracks.Cy3NNdist(ii)<= interactDist
        Cy3InteractingTracks(end+1).Cy3Track = ii; %record which tracks have interactions
        Cy3InteractingTracks(end).Cy5Interactors = interactors;

        dX = cTrack(1,1:2:end); 
        dY = cTrack(1,2:2:end);
        plot (dX,dY,'r');
        hold on;

        for jj=2:size(cTrack,1)
            dX = cTrack(jj,1:2:end); 
            dY = cTrack(jj,2:2:end);
            plot (dX, dY, 'Color', 'Magenta');
        end
        
        %scale plot
        minX = min(min(cTrack(:,1:2:end)));
        maxX = max(max(cTrack(:,1:2:end)));
        minY = min(min(cTrack(:,2:2:end)));
        maxY = max(max(cTrack(:,2:2:end)));
        deltaX = maxX-minX;
        deltaY = maxY-minY;
        if deltaX>deltaY
            deltaX = deltaX*1.1;
            maxY = ((maxY+minY)/2) + (0.5*deltaX);
            minY = ((maxY+minY)/2) - (0.5*deltaX);
            maxX = ((maxX+minX)/2) + (0.5*deltaX);
            minX = ((maxX+minX)/2) - (0.5*deltaX);
        else
            deltaY = deltaY*1.1;
            maxX = ((maxX+minX)/2) + (0.5*deltaY);
            minX = ((maxX+minX)/2) - (0.5*deltaY);
            maxY = ((maxY+minY)/2) + (0.5*deltaY);
            minY = ((maxY+minY)/2) - (0.5*deltaY);
        end
        axis ([minX maxX minY maxY]);
        legend (Cy3Label, Cy5Label);
        xlabel ('X position (nm)');
        ylabel ('Y position (nm)');
        axis square;
        hold off;
        saveas (gcf, [Cy3Label '_Interactor_' pad(num2str(ii),4,'left','0') '.fig'])
        close (gcf);
    end
end
outputMatrix.Tracks.Cy3InteractingTracks = Cy3InteractingTracks;
hist(outputMatrix.Tracks.Cy3NNdist,30);
xlabel (['Minimum ' Cy3Label ':' Cy5Label 'Separation (nm)']);
ylabel (['# ' Cy3Label ' Tracks']);
saveas (gcf, [Cy3Label '_' Cy5Label '_MinimumSeparation.fig']);
close (gcf);

%Cy5 Tracks
Cy5InteractingTracks = [];
for ii=1:size(Cy5X,1)
    %identify potentially interacting tacks
    interactors = Cy5InteractorTable(ii,:);
    interactors = unique(interactors);
    interactors = interactors(~isnan(interactors));
    cTrack = zeros(size(interactors,2)+1,2*size(Cy5X,2));
    cTrack(1,1:2:end) = Cy5X(ii,:);
    cTrack(1,2:2:end) = Cy5Y(ii,:);

    for jj=2:size(cTrack,1)
        cTrack(jj,1:2:end) = Cy3X(interactors(jj-1),:);
        cTrack(jj,2:2:end) = Cy3Y(interactors(jj-1),:);
    end
    
    outputMatrix.Tracks.Cy5NNtrack(ii).RawTracks = cTrack;
    outputMatrix.Tracks.Cy5NNdist(ii) = min(Cy5DistTable(ii,:));
    
    if outputMatrix.Tracks.Cy5NNdist(ii)<= interactDist
        Cy5InteractingTracks(end+1).Cy5Track = ii; %record which tracks have interactions
        Cy5InteractingTracks(end).Cy3Interactors = interactors;
        dX = cTrack(1,1:2:end); 
        dY = cTrack(1,2:2:end);
        plot (dX,dY,'Color', 'Magenta');
        hold on;

        for jj=2:size(cTrack,1)
            dX = cTrack(jj,1:2:end); 
            dY = cTrack(jj,2:2:end);
            plot (dX, dY, 'r');
        end
        
        %scale plot
        minX = min(min(cTrack(:,1:2:end)));
        maxX = max(max(cTrack(:,1:2:end)));
        minY = min(min(cTrack(:,2:2:end)));
        maxY = max(max(cTrack(:,2:2:end)));
        deltaX = maxX-minX;
        deltaY = maxY-minY;
        if deltaX>deltaY
            deltaX = deltaX*1.1;
            maxY = ((maxY+minY)/2) + (0.5*deltaX);
            minY = ((maxY+minY)/2) - (0.5*deltaX);
            maxX = ((maxX+minX)/2) + (0.5*deltaX);
            minX = ((maxX+minX)/2) - (0.5*deltaX);
        else
            deltaY = deltaY*1.1;
            maxX = ((maxX+minX)/2) + (0.5*deltaY);
            minX = ((maxX+minX)/2) - (0.5*deltaY);
            maxY = ((maxY+minY)/2) + (0.5*deltaY);
            minY = ((maxY+minY)/2) - (0.5*deltaY);
        end
        axis ([minX maxX minY maxY]);
        legend (Cy5Label, Cy3Label);
        xlabel ('X position (nm)');
        ylabel ('Y position (nm)');
        axis square;
        hold off;
        saveas (gcf, [Cy5Label '_Interactor_' pad(num2str(ii),4,'left','0') '.fig'])
        close (gcf);
    end
end
outputMatrix.Tracks.Cy5InteractingTracks = Cy5InteractingTracks;
hist(outputMatrix.Tracks.Cy5NNdist,30);
xlabel (['Minimum ' Cy5Label ':' Cy3Label 'Separation (nm)']);
ylabel (['# ' Cy5Label ' Tracks']);
saveas (gcf, [Cy5Label '_' Cy3Label '_MinimumSeparation.fig']);
close (gcf);

%% Analyze Interactors
%Cy3 track interactions
if ~isempty(Cy3InteractingTracks)
    for ii=1:size(outputMatrix.Tracks.Cy3InteractingTracks,2)
        clear pX pY dTable
        pX(1,:) = Cy3X(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy3Track,:);
        pY(1,:) = Cy3Y(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy3Track,:);
        outputMatrix.Interacting.Cy3Interactors(ii).Cy3Track = Cy3InteractingTracks(ii).Cy3Track; %record Cy3 track being analyzed
        outputMatrix.Interacting.Cy3Interactors(ii).Cy3Start = find(~isnan(pX),1)*frameRate; %starting time of track, in ms
        outputMatrix.Interacting.Cy3Interactors(ii).Cy3End = find(~isnan(pX)); 
        outputMatrix.Interacting.Cy3Interactors(ii).Cy3End = outputMatrix.Interacting.Cy3Interactors(ii).Cy3End(end)*frameRate;  %ending time of track, in ms

        %identify and extract interacting Cy5 tracks
        for jj=1:size(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy5Interactors,2)
            pX(jj+1,:) = Cy5X(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy5Interactors(jj),:);
            pY(jj+1,:) = Cy5Y(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy5Interactors(jj),:);
        end

                %generate distance table
        dTable = zeros (size(pX,1)-1,size(pX,2));
        for jj=1:size(pX,1)-1
            for kk=1:size(pX,2)
                dTable(jj,kk) = sqrt((pX(1,kk)-pX(jj+1,kk))^2+(pY(1,kk)-pY(jj+1,kk))^2);
            end
        end
        dTable = dTable.*pixelSize; %convert to nm
        interactTracks = min(dTable')<interactDist; %ID interacting tracks
        dTable = dTable(interactTracks,:); %remove non-interacting tracks
        pX = pX([true interactTracks],:); %remove non-interacting tracks
        pY = pY([true interactTracks],:); %remove non-interacting tracks
        iTracks = outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy5Interactors(interactTracks);
        
        %Cy5 track & cleavage data
        for jj = 2:size(pX,1)
            outputMatrix.Interacting.Cy3Interactors(ii).Cy5Interactors(jj-1) = iTracks(jj-1);
            Cy5Start = find(~isnan(pX(jj,:)),1)*frameRate; %starting time of track, in ms
            outputMatrix.Interacting.Cy3Interactors(ii).Cy5Start(jj-1) = Cy5Start;
            Cy5End = find(~isnan(pX(jj,:)))*frameRate;
            Cy5End = Cy5End(end);
            outputMatrix.Interacting.Cy3Interactors(ii).Cy5End(jj-1) = Cy5End;

            %score potential cleavage
            endDist = dTable(jj-1,max(find(~isnan(dTable(jj-1,:)))));
            if endDist <= interactDist %if the final point in the interaction is within interaction range
                if outputMatrix.Interacting.Cy3Interactors(ii).Cy3End > Cy5End
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved(jj-1) = 0;
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy5Cleaved(jj-1) = 1;
                elseif outputMatrix.Interacting.Cy3Interactors(ii).Cy3End < Cy5End
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved(jj-1) = 1;
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy5Cleaved(jj-1) = 0;
                else
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved(jj-1) = 0;
                   outputMatrix.Interacting.Cy3Interactors(ii).Cy5Cleaved(jj-1) = 0;
                end
            else
               outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved(jj-1) = 0;
               outputMatrix.Interacting.Cy3Interactors(ii).Cy5Cleaved(jj-1) = 0;
            end
        end

        %trim position tables
        pY(:,~any(~isnan(pX),1)) = []; %remove columns that are all NaNs
        dTable = dTable(:,~all(isnan(pX),1)); %remove all-NaN columns
        pX(:,~any(~isnan(pX),1)) = []; %remove columns that are all NaNs
        
        %calcualte interaction times
        for jj=1:size(dTable,1)
            outputMatrix.Interacting.Cy3Interactors(ii).InteractionTime(jj) = sum(dTable(jj,:)<interactDist)*frameRate;
        end
        
        %plot data
        timeAxis = 0:frameRate:(frameRate*(size(pX,2)-1));
        lineCol = jet(size(dTable,1));
        tLegend = {};
        for jj=1:size(dTable,1)
            plot (timeAxis,dTable(jj,:),'Color', lineCol(jj,:));
            hold on
            tLegend(jj) = {[Cy5Label ' #' int2str((iTracks(jj)))]};
        end
        legend (cellstr(tLegend));
        xlabel ('time (ms)');
        ylabel ([Cy3Label ':' Cy5Label ' Separation (nm)']);
        xLimit = xlim;
        rectangle ('Position', [xLimit(1),0,(xLimit(2)-xLimit(1)),interactDist], 'EdgeColor','none', 'FaceColor','y', 'FaceAlpha',0.4);
        title ([Cy3Label ' Track #' int2str(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy3Track) ' - ' Cy5Label ' Interactions']);
        hold off
        saveas (gcf, [Cy3Label ' Track #' int2str(outputMatrix.Tracks.Cy3InteractingTracks(ii).Cy3Track) ' - ' Cy5Label ' Distance Plot.fig'])
        close (gcf);

        outputMatrix.Interacting.Cy3Interactors(ii).distanceTable = dTable;
        outputMatrix.Interacting.Cy3Interactors(ii).Xpos = pX;
        outputMatrix.Interacting.Cy3Interactors(ii).Ypos = pY;
    end
end %end Cy3

%Cy5 track interactions
if ~isempty(Cy5InteractingTracks)
    for ii=1:size(outputMatrix.Tracks.Cy5InteractingTracks,2)
        clear pX pY dTable
        pX(1,:) = Cy5X(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy5Track,:);
        pY(1,:) = Cy5Y(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy5Track,:);
        outputMatrix.Interacting.Cy5Interactors(ii).Cy5Track = Cy5InteractingTracks(ii).Cy5Track; %record Cy5 track being analyzed
        outputMatrix.Interacting.Cy5Interactors(ii).Cy5Start = find(~isnan(pX),1)*frameRate; %starting time of track, in ms
        outputMatrix.Interacting.Cy5Interactors(ii).Cy5End = find(~isnan(pX)); 
        outputMatrix.Interacting.Cy5Interactors(ii).Cy5End = outputMatrix.Interacting.Cy5Interactors(ii).Cy5End(end)*frameRate;  %ending time of track, in ms

        %identify and extract interacting Cy3 tracks
        for jj=1:size(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy3Interactors,2)
            pX(jj+1,:) = Cy3X(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy3Interactors(jj),:);
            pY(jj+1,:) = Cy3Y(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy3Interactors(jj),:);
        end

                %generate distance table
        dTable = zeros (size(pX,1)-1,size(pX,2));
        for jj=1:size(pX,1)-1
            for kk=1:size(pX,2)
                dTable(jj,kk) = sqrt((pX(1,kk)-pX(jj+1,kk))^2+(pY(1,kk)-pY(jj+1,kk))^2);
            end
        end
        dTable = dTable.*pixelSize; %convert to nm
        interactTracks = min(dTable')<interactDist; %ID interacting tracks
        dTable = dTable(interactTracks,:); %remove non-interacting tracks
        pX = pX([true interactTracks],:); %remove non-interacting tracks
        pY = pY([true interactTracks],:); %remove non-interacting tracks
        iTracks = outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy3Interactors(interactTracks);
        
        %Cy3 track & cleavage data
        for jj = 2:size(pX,1)
            outputMatrix.Interacting.Cy5Interactors(ii).Cy3Interactors(jj-1) = iTracks(jj-1);
            Cy3Start = find(~isnan(pX(jj,:)),1)*frameRate; %starting time of track, in ms
            outputMatrix.Interacting.Cy5Interactors(ii).Cy3Start(jj-1) = Cy3Start;
            Cy3End = find(~isnan(pX(jj,:)))*frameRate;
            Cy3End = Cy3End(end);
            outputMatrix.Interacting.Cy5Interactors(ii).Cy3End(jj-1) = Cy3End;

            %score potential cleavage
            endDist = dTable(jj-1,max(find(~isnan(dTable(jj-1,:)))));
            if endDist <= interactDist %if the final point in the interaction is within interaction range
                if outputMatrix.Interacting.Cy5Interactors(ii).Cy5End > Cy3End
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved(jj-1) = 0;
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy3Cleaved(jj-1) = 1;
                elseif outputMatrix.Interacting.Cy5Interactors(ii).Cy5End < Cy3End
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved(jj-1) = 1;
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy3Cleaved(jj-1) = 0;
                else
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved(jj-1) = 0;
                   outputMatrix.Interacting.Cy5Interactors(ii).Cy3Cleaved(jj-1) = 0;
                end
            else
                outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved(jj-1) = 0;
                outputMatrix.Interacting.Cy5Interactors(ii).Cy3Cleaved(jj-1) = 0;
            end
        end

        %trim position tables
        pY(:,~any(~isnan(pX),1)) = []; %remove columns that are all NaNs
        dTable = dTable(:,~all(isnan(pX),1)); %remove all-NaN columns
        pX(:,~any(~isnan(pX),1)) = []; %remove columns that are all NaNs
        
        %calcualte interaction times
        for jj=1:size(dTable,1)
            outputMatrix.Interacting.Cy5Interactors(ii).InteractionTime(jj) = sum(dTable(jj,:)<interactDist)*frameRate;
        end
        
        %plot data
        timeAxis = 0:frameRate:(frameRate*(size(pX,2)-1));
        lineCol = jet(size(dTable,1));
        tLegend = {};
        for jj=1:size(dTable,1)
            plot (timeAxis,dTable(jj,:),'Color', lineCol(jj,:));
            hold on
            tLegend(jj,:) = {[Cy3Label ' #' int2str((iTracks(jj)))]};
        end
        legend (cellstr(tLegend));
        xlabel ('time (ms)');
        ylabel ([Cy5Label ':' Cy3Label ' Separation (nm)']);
        xLimit = xlim;
        rectangle ('Position', [xLimit(1),0,(xLimit(2)-xLimit(1)),interactDist], 'EdgeColor','none', 'FaceColor','y', 'FaceAlpha',0.4);
        title ([Cy5Label ' Track #' int2str(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy5Track) ' - ' Cy3Label ' Interactions']);
        hold off
        saveas (gcf, [Cy5Label ' Track #' int2str(outputMatrix.Tracks.Cy5InteractingTracks(ii).Cy5Track) ' - ' Cy3Label ' Distance Plot.fig'])
        close (gcf);

        outputMatrix.Interacting.Cy5Interactors(ii).distanceTable = dTable;
        outputMatrix.Interacting.Cy5Interactors(ii).Xpos = pX;
        outputMatrix.Interacting.Cy5Interactors(ii).Ypos = pY;
    end
end %end Cy5

%% Final Graphs

%collect Cy3 interaction duration data
Cy3_Uncleaved = 0;
Cy3_Cy5Duration = []; %interaction time
Cy3_Cy3Cleavage = 0; %Cy3 cleaved by Cy5 counter
Cy3_Cy3CleavageTime = []; %Cy3 cleaved by Cy5 interaction time
Cy3_Cy5Cleavage = 0; %Cy5 cleaved by Cy3 counter
Cy3_Cy5CleavageTime = []; %Cy5 cleaved by Cy3 interaction time
for ii=1:size(outputMatrix.Interacting.Cy3Interactors,2)
    for jj=1:size(outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved,2)
        if outputMatrix.Interacting.Cy3Interactors(ii).Cy3Cleaved(jj) == 1
            Cy3_Cy3Cleavage = Cy3_Cy3Cleavage+1;
            Cy3_Cy3CleavageTime(end+1) = outputMatrix.Interacting.Cy3Interactors(ii).InteractionTime(jj);
        elseif outputMatrix.Interacting.Cy3Interactors(ii).Cy5Cleaved(jj) == 1
            Cy3_Cy5Cleavage = Cy3_Cy5Cleavage + 1;
            Cy3_Cy5CleavageTime(end+1) = outputMatrix.Interacting.Cy3Interactors(ii).InteractionTime(jj);
        else
            Cy3_Uncleaved = Cy3_Uncleaved + 1;
            Cy3_Cy5Duration(end+1) = outputMatrix.Interacting.Cy3Interactors(ii).InteractionTime(jj);
        end
    end
end

%plot total track numbers; interacting vs c;leaved
outputMatrix.SummaryData.Cy3cleavageBarData = [Cy3_Uncleaved, Cy3_Cy3Cleavage, Cy3_Cy5Cleavage];
outputMatrix.SummaryData.Cy3cleavageBarLabels = {[Cy3Label ' uncleaved']; [Cy3Label ' cleaved']; [Cy5Label ' cleaved']};
bar(string(outputMatrix.SummaryData.Cy3cleavageBarLabels), outputMatrix.SummaryData.Cy3cleavageBarData, 'k');
yMax = max(outputMatrix.SummaryData.Cy3cleavageBarData)+1;
ylim([0 yMax]);
ylabel ('# Events');
title ([Cy3Label ' - ' Cy5Label ' Interactions and Cleavage']);
saveas (gcf, [Cy3Label ' InteractionNumbers.fig']);
close (gcf)

%plot fraction of interacting tracks; uncleaved vs cleaved
outputMatrix.SummaryData.Cy3cleavageBarFractions = outputMatrix.SummaryData.Cy3cleavageBarData./sum(outputMatrix.SummaryData.Cy3cleavageBarData);
bar(string(outputMatrix.SummaryData.Cy3cleavageBarLabels), outputMatrix.SummaryData.Cy3cleavageBarFractions, 'k');
yMax = round((max(outputMatrix.SummaryData.Cy3cleavageBarFractions)*1.2),1);
ylim([0 yMax]);
ylabel (['Fraction ' Cy3Label '-' Cy5Label ' Interactions']);
title ([Cy3Label ' - ' Cy5Label ' Interactions and Cleavage']);
saveas (gcf, [Cy3Label ' InteractionFractions.fig']);
close (gcf)

%plot fraction of total tracks; uncleaved vs cleaved
outputMatrix.SummaryData.Cy3cleavageFractionTotal = outputMatrix.SummaryData.Cy3cleavageBarData./size(outputMatrix.Tracks.Cy3NNtrack,2);
bar(string(outputMatrix.SummaryData.Cy3cleavageBarLabels), outputMatrix.SummaryData.Cy3cleavageFractionTotal, 'k');
yMax = round((max(outputMatrix.SummaryData.Cy3cleavageFractionTotal)*1.2),1,"significant");
ylim([0 yMax]);
ylabel (['Fraction ' Cy3Label '-' Cy5Label ' Interactions']);
title (['Fraction of ' Cy3Label '-' Cy5Label ' Particles that Interact']);
saveas (gcf, [Cy3Label ' TotalInteractionFractions.fig']);
close (gcf)

interactionMatrix = [];

if Cy3_Uncleaved ~= 0
    for ii = 1:Cy3_Uncleaved
        interactionMatrix(end+1, 1:2) = [1, Cy3_Cy5Duration(ii)];
    end
end

if Cy3_Cy3Cleavage ~=0
    for ii = 1:Cy3_Cy3Cleavage
        interactionMatrix(end+1, 1:2) = [2, Cy3_Cy3CleavageTime(ii)];
    end
end

if Cy3_Cy5Cleavage ~=0
    for ii = 1:Cy3_Cy5Cleavage
        interactionMatrix(end+1, 1:2) = [3, Cy3_Cy5CleavageTime(ii)];
    end
end

scatter(interactionMatrix(:,1),interactionMatrix(:,2))
maxY = round((max(interactionMatrix(:,2))*1.2),-1);
ylim([0 maxY]);
xlim([0.75 3.25]);
xticks([1 2 3]);
xticklabels(string(outputMatrix.SummaryData.Cy3cleavageBarLabels));
ylabel ([Cy3Label '-' Cy5Label ' Interaction Time']);
title ([Cy3Label ' - ' Cy5Label ' Interaction Time to Cleavage']);
saveas (gcf, [Cy3Label ' CleavageTime.fig']);
close (gcf)

outputMatrix.SummaryData.Cy3CleavageTimeData = interactionMatrix;


%collect Cy5 duration data
Cy5_Uncleaved = 0;
Cy5_Cy3Duration = []; %interaction time
Cy5_Cy5Cleavage = 0; %Cy5 cleaved by Cy3 counter
Cy5_Cy5CleavageTime = []; %Cy5 cleaved by Cy3 interaction time
Cy5_Cy3Cleavage = 0; %Cy3 cleaved by Cy5 counter
Cy5_Cy3CleavageTime = []; %Cy3 cleaved by Cy5 interaction time
for ii=1:size(outputMatrix.Interacting.Cy5Interactors,2)
    for jj=1:size(outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved,2)
        if outputMatrix.Interacting.Cy5Interactors(ii).Cy5Cleaved(jj) == 1
            Cy5_Cy5Cleavage = Cy5_Cy5Cleavage+1;
            Cy5_Cy5CleavageTime(end+1) = outputMatrix.Interacting.Cy5Interactors(ii).InteractionTime(jj);
        elseif outputMatrix.Interacting.Cy5Interactors(ii).Cy3Cleaved(jj) == 1
            Cy5_Cy3Cleavage = Cy5_Cy3Cleavage + 1;
            Cy5_Cy3CleavageTime(end+1) = outputMatrix.Interacting.Cy5Interactors(ii).InteractionTime(jj);
        else
            Cy5_Uncleaved = Cy5_Uncleaved + 1;
            Cy5_Cy3Duration(end+1) = outputMatrix.Interacting.Cy5Interactors(ii).InteractionTime(jj);
        end
    end
end

% plot total Cy5 tracks
outputMatrix.SummaryData.Cy5cleavageBarData = [Cy5_Uncleaved, Cy5_Cy5Cleavage, Cy5_Cy3Cleavage];
outputMatrix.SummaryData.Cy5cleavageBarLabels = {[Cy5Label ' uncleaved']; [Cy5Label ' cleaved']; [Cy3Label ' cleaved']};
bar(string(outputMatrix.SummaryData.Cy5cleavageBarLabels), outputMatrix.SummaryData.Cy5cleavageBarData, 'k');
yMax = max(outputMatrix.SummaryData.Cy5cleavageBarData)+1;
ylim([0 yMax]);
ylabel ('# Events');
title ([Cy5Label ' - ' Cy3Label ' Interactions and Cleavage']);
saveas (gcf, [Cy5Label ' InteractionNumbers.fig']);
close (gcf)

% plot fraciton of itneracting traacks cleaved/uncleaved
outputMatrix.SummaryData.Cy5cleavageBarFractions = outputMatrix.SummaryData.Cy5cleavageBarData./sum(outputMatrix.SummaryData.Cy5cleavageBarData);
bar(string(outputMatrix.SummaryData.Cy5cleavageBarLabels), outputMatrix.SummaryData.Cy5cleavageBarFractions, 'k');
yMax = round((max(outputMatrix.SummaryData.Cy5cleavageBarFractions)*1.2),1);
ylim([0 yMax]);
ylabel (['Fraction ' Cy5Label '-' Cy3Label ' Interactions']);
title ([Cy5Label ' - ' Cy3Label ' Interactions and Cleavage']);
saveas (gcf, [Cy5Label ' InteractionFractions.fig']);
close (gcf)

% plot fraction of total tracks; uncleaved vs cleaved
outputMatrix.SummaryData.Cy5cleavageFractionTotal = outputMatrix.SummaryData.Cy5cleavageBarData./size(outputMatrix.Tracks.Cy5NNtrack,2);
bar(string(outputMatrix.SummaryData.Cy5cleavageBarLabels), outputMatrix.SummaryData.Cy5cleavageFractionTotal, 'k');
yMax = round((max(outputMatrix.SummaryData.Cy5cleavageFractionTotal)*1.2),1,"significant");
ylim([0 yMax]);
ylabel (['Fraction ' Cy5Label '-' Cy3Label ' Interactions']);
title (['Fraction of ' Cy5Label ' - ' Cy3Label ' Particles that Interact']);
saveas (gcf, [Cy5Label ' TotalInteractionFractions.fig']);
close (gcf)
interactionMatrix = [];

if Cy5_Uncleaved ~= 0
    for ii = 1:Cy5_Uncleaved
        interactionMatrix(end+1, 1:2) = [1, Cy5_Cy3Duration(ii)];
    end
end

if Cy5_Cy5Cleavage ~=0
    for ii = 1:Cy5_Cy5Cleavage
        interactionMatrix(end+1, 1:2) = [2, Cy5_Cy5CleavageTime(ii)];
    end
end

if Cy5_Cy3Cleavage ~=0
    for ii = 1:Cy5_Cy3Cleavage
        interactionMatrix(end+1, 1:2) = [3, Cy5_Cy3CleavageTime(ii)];
    end
end

scatter(interactionMatrix(:,1),interactionMatrix(:,2))
maxY = round((max(interactionMatrix(:,2))*1.2),-1);
ylim([0 maxY]);
xlim([0.75 3.25]);
xticks([1 2 3]);
xticklabels(string(outputMatrix.SummaryData.Cy5cleavageBarLabels));
ylabel ([Cy5Label '-' Cy3Label ' Interaction Time']);
title ([Cy5Label ' - ' Cy3Label ' Interaction Time to Cleavage']);
saveas (gcf, [Cy5Label ' CleavageTime.fig']);
close (gcf)

outputMatrix.SummaryData.Cy5CleavageTimeData = interactionMatrix;

% potential cleavage events tracks
% plot tracks; if possible colour-code timeframe of tracks (jet vs other?),
% indicate interaction region somehow

% also need to add x/y correction from CalibrateWView. Pass calibration
% file as variable and save within outputMatrix

save ([Cy3Label '-' Cy5Label '_WView_SPT_Interactors.mat'], 'outputMatrix');

%% for testing; remove at end
% Cy3Input = 'Cy3trackedFeatures.mat';
% Cy5Input = 'Cy5trackedFeatures.mat';
% Cy3Amp = 0;
% Cy5Amp = 0;
% Cy3Label = 'MERTK';
% Cy5Label = 'ADAM17';
% minFrames = 10;
% interactDist = 50;
% frameRate = 50;
% pixelSize = 130;