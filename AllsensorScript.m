    clear;
    files = dir('*.csv');
    num_files = length(files);
    results = cell(length(files), 1);
    figure;
    grid on
    num=1;%fig num
    for k = 1:num_files
        %%
        sensorData = importfile(files(k).name);
        sensorData.timestamp=sensorData.timestamp/10^3;
        date = datetime(sensorData.timestamp,'ConvertFrom','posixtime','Format','d-MMM-y HH:mm:ss.SS');
        sensorData.timestamp = date;
        expDuration(k)=round(datenum(max(sensorData.timestamp)-min(sensorData.timestamp))*(24*3600));% in seconds
        
        accel = sensorData(sensorData.tag == "ACCEL",:);
%%
        Standingsegment = [];
        Walkingsegment = [];
        sigStd = [];
        pstandtime = [];
        pwalktime = [];
        PwaitingTime=0;
        standingTimestamps = [];
        walkingTimestamps = [];
        starttime = min(sensorData.timestamp);
%%
% Ground Truth
        timestamp = sensorData.timestamp(1);
        tag = {'STAND'};
        groundTruth = table(timestamp,tag);
        groundTruth = [groundTruth;sensorData(sensorData.tag == "WALK" | sensorData.tag == "STAND",1:2)];
        groundTruth.Duration = [diff(groundTruth.timestamp);0];
        AwaitingTime = sum(groundTruth.Duration(groundTruth.tag=="STAND"));
        subplot(length(files),2,num)
        plot(seconds(accel.timestamp-starttime),accel.z,'color','b')
        hold on
        for n=1:length(groundTruth.timestamp)
            if(groundTruth.tag(n)=="STAND")
              plot([seconds(groundTruth.timestamp(n)-starttime) seconds(groundTruth.timestamp(n)-starttime)], [min(accel.z) max(accel.z)], 'LineWidth',3,'color','r')
            end
            if(groundTruth.tag(n)=="WALK")
              plot([seconds(groundTruth.timestamp(n)-starttime) seconds(groundTruth.timestamp(n)-starttime)], [min(accel.z) max(accel.z)], 'LineWidth',3,'color','g')
            end
            hold on
        end

        xlabel('Time (sec)');
        ylabel('Accel. (m/s^2)');
        tit = "Actual ";
        title(tit);
        num=num+1;
        
%%
% Estimation:
        window = 150; %check every one second / no overlapping
        signal=accel.z;
        L = length(signal); %number of available samples
        Noseg = floor(L/window);
        j=1;
        ii=1;
        
        s=0;
        subplot(length(files),2,num)
        for i=1:window:L
             ii=i+window-1;
             if ii<L
                 segment = accel(i:ii, :);
                 s = minus(max(segment.timestamp),min(segment.timestamp));
             else
                 segment = accel(i:end, :);
                 s = minus(max(segment.timestamp),min(segment.timestamp));
             end
             Pgt = groundTruth(groundTruth.timestamp <= segment.timestamp(1),:);
             threshold=1; % 1m/s2
             sigStd(j)=std(segment.z);
             if sigStd(j)<=threshold %this segment is standing
                PwaitingTime = PwaitingTime + s;
                pstandtime = [pstandtime;segment.timestamp(1)];
                plot(seconds(segment.timestamp-starttime),segment.z,'color','r');%standing
                hold on
                standingTimestamps = [standingTimestamps;segment.timestamp];
%                  for q=1:length(segment.timestamp)
                   dist = datenum(segment.timestamp(1)) - datenum(Pgt.timestamp);
                   [~,qq] = min(dist);
%                  end
                Standingsegment = [Standingsegment; {'STAND'}, Pgt.tag(qq)];
             else 
                plot(seconds(segment.timestamp-starttime),segment.z,'color','g');%walking
                walkingTimestamps = [walkingTimestamps;segment.timestamp];
                hold on
                pwalktime = [pwalktime;segment.timestamp(1)];
%                 for q=1:length(segment.timestamp)
                   dist = datenum(segment.timestamp(1)) - datenum(Pgt.timestamp);
                   [~,qq] = min(dist);
%                 end
                Walkingsegment = [Walkingsegment; {'WALK'}, Pgt.tag(qq)];
             end
             j=j+1;
             hold on
        end
        
        hold on
        xlabel('Time (sec)');
        ylabel('Accel. (m/s^2)');
        title('Estimated')
        num=num+1;
        
        Standingmatch = sum(Standingsegment(:,1) == Standingsegment(:,2));
        StandingAccuracy(k) = (Standingmatch/length(Standingsegment))*100;
        
        Walkingmatch = sum(Walkingsegment(:,1) == Walkingsegment(:,2));
        WalkingAccuracy(k) = (Walkingmatch/length(Walkingsegment))*100;
%%   
        disp('Total Actual Waiting Time (sec) = ');
        disp(seconds(AwaitingTime));
        ActualWT(k) = seconds(AwaitingTime);
        
        
        disp('Total Estimated Waiting Time = ');
        disp(seconds(PwaitingTime));
        estimatedWT(k) = seconds(PwaitingTime);

        disp( "Error = ");
        WTDiff(k) = ActualWT(k)-estimatedWT(k);
        pDiff(k)=abs(WTDiff(k))/ActualWT(k)*100;
        
        disp(abs(WTDiff(k)))
        
        stdSig(k)=mean(diff(sigStd));

%%
        
        walkingTimestamps = array2table(walkingTimestamps);
        walkingTimestamps.status = repmat({'WALK'}, size(walkingTimestamps));
        standingTimestamps = array2table(standingTimestamps);
        standingTimestamps.status = repmat({'STAND'}, size(standingTimestamps));
%       ResultsTable = outerjoin(walkingTimestamps,standingTimestamps);
%%        
        filename = files(k).name+".mat";
        save(filename,'walkingTimestamps','standingTimestamps')
    end
%%
    save('accuracy.mat','WTDiff')
    disp('Done!')
%%
figure;
%     meanStd = mean(sigStd);
%     plot(WTDiff,'DisplayName','WTDiff');hold on;plot(expDuration,'DisplayName','expDuration');hold off;
    for h=1:length(ActualWT)
        barall(h,1) = ActualWT(h);
        barall(h,2) = estimatedWT(h);
        barall(h,3) = expDuration(h);
    end
    bar(barall)
    hold on
    xlabel('Trial Number')
    ylabel('Time (sec)')
    legend('Actual WT','Estimated WT','Trip Duration')
    grid on
errorrate = mean(pDiff);
disp ('average error : ')
disp(errorrate);
disp ('mean(StandingAccuracy) : ')
disp(mean(StandingAccuracy));
disp ('mean(WalkingAccuracy) : ')
disp(mean(WalkingAccuracy));