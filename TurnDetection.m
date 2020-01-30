% clear;clc;
% sensorData = importfile('sensorData_1577050715922.csv');
% sensorData.timestamp=sensorData.timestamp/10^3;
% date = datetime(sensorData.timestamp,'ConvertFrom','posixtime','Format','d-MMM-y HH:mm:ss.SS');
% sensorData.timestamp = date;
%%
clear;
    files = dir('*.csv');
    num_files = length(files);
    results = cell(length(files), 1);
    
for k = 1:num_files
        sensorData = importfile(files(k).name);
        sensorData.timestamp=sensorData.timestamp/10^3;
        date = datetime(sensorData.timestamp,'ConvertFrom','posixtime','Format','d-MMM-y HH:mm:ss.SS');
        sensorData.timestamp = date;
        
        dAngleTime = [];
        turnsTimes = [];
        dAngleTime1 = [];
        meanAngle = [];
        dAngle = [];
        ddAngle = [];
        newdAngle = [];
        turns = [];
        dAngleTimestamp = [];
        TurnTime = [];
        turningTimestamps = [];
%%
%Detection:
        rotation = sensorData(sensorData.tag == "ROTATION",:);
        rx = rotation.x;
        ry = rotation.y;
        rz = rotation.z.*(180/pi);%convert radian to degree
        rotation.z = rz;
        
        window = 100;
        j = 1;
        jj = 1;

        for n=1:window:length(rz)
            ii=n+window-1;
            if ii<length(rz)
                 segment = rotation(n:ii,:);

            else
                 segment = rotation(n:end,:);
            end
            % calculate the mean of rotation degree in each segment
            meanAngle(j) = mean(segment.z);
            % set the timestamp of mean angle change as the last timestamp in the
            % segment
            dAngleTime(j) = seconds(segment.timestamp(end)-rotation.timestamp(1));
            dAngleTimestamp = [dAngleTimestamp;segment.timestamp(end)];
             if j == 1 
                 dAngle(j) = 0;
             else
                 % claculate the difference between two consecuitive angle
                 % means
                 dAngle(j) = meanAngle(j) - meanAngle(j-1);
             end
            % set a threshold=10, then check if this is a turn
            % if the angle mean change between 2 consecutive segments is larger than...
            % the threshold, then the last segment has a turn 
            if abs(dAngle(j))>10 % this is a turn
                turns(jj) = dAngleTime(j);
                ddAngle(jj) = dAngle(j);
                TurnTime = [TurnTime dAngleTimestamp(j)];
                jj=jj+1;
            end
            j=j+1;
            newdAngle = dAngle;
        end
%         turns = turns';
%         turns = repmat({"TURN"}, size(turns));
        %%
        % Plotting Results
        rd = rotation.timestamp-rotation.timestamp(1); % Convert to duration since start of experiment.
        rd.Format = 's'; % Specify that you want to see seconds in the dis
        figure;
        set(0,'DefaultFigureWindowStyle','normal')
        subplot(3,1,1)
            plot(rd,rz)
            hold on
            dAngleTime1 = seconds(dAngleTime);
            plot(dAngleTime1,newdAngle)
            hold on
            turnsTimes = seconds(turns);
            plot(turnsTimes, ddAngle,'.r','MarkerSize',15)
            title('Estimated Turning Time')
            xlabel('time (sec)')
            ylabel('Yaw (degree/sec)')
            legend('Rotation Z-axis','Delta Mean Angle','Estimated Turns')
            grid on
%%           
% Ground Truth:
        turn = sensorData(sensorData.tag == "TURN",1);
        td = turn.timestamp-rotation.timestamp(1);
        
        subplot(3,1,2)
            p=plot(rd,rz);
            hold on
            for n=1:length(turn.timestamp)
                  plot([td(n) td(n)], [min(rotation.z) max(rotation.z)], 'LineWidth',3,'color','r')
            end
            title('Actual Turning Time')
            xlabel('time (sec)')
            ylabel('Yaw (degree/sec)')
            legend('Rotation Z-Axis','Actual Turns')
            grid on
        %%
        %Identifying how angle changes while turning
        dAngle = diff(meanAngle);
        subplot(3,1,3)
            [pksh,locsh] = findpeaks(abs(dAngle),'MinPeakHeight',10);
            plot(abs(dAngle));
            hold on;
            scatter(locsh,pksh);
            hold on
            title("Rotation Peaks from Z-Axis");
            xlabel("Samples");
            ylabel("Absolute Mean Angular Velocity (degree/sec)");
            
        turningTimestamps = array2table(TurnTime');
        turningTimestamps.status = repmat({'TURN'}, size(turningTimestamps));
        
        filename = files(k).name+".mat";
        save('-append',filename,'turningTimestamps')
        
        disp(filename)
        
        %%
        ActualTurnsNum(k) = length(turn.timestamp);
%         ActualTurnsTimes = seconds(turn.timestamp);
        TurnTime = TurnTime';
        EstimatedTurnsNum(k) = length(TurnTime);
%         EstimatedTurnsTimes = seconds(TurnTime);
        
end