clear;
files = dir('*.csv');
num_files = length(files);
results = cell(length(files), 1);

for k = 1:num_files
        sensorData = importfile(files(k).name);
        sensorData.timestamp=sensorData.timestamp/10^3;
        date = datetime(sensorData.timestamp,'ConvertFrom','posixtime','Format','d-MMM-y HH:mm:ss.SS');
        sensorData.timestamp = date;
        %%
        gps = sensorData(sensorData.tag == "GPS",:);
        %Logging from GPS: Latitude, longitude, bearing, speed, time of the fix, accuracy, number of satellites used for the fix
        Latitude = gps.x;
        Longitude = gps.y;
        gpstimestamp = gps.timestamp;
        Bearing = gps.z;
%         Accuracy = gps.VarName8;

        load(files(k).name+".mat");
        standingTimestamps.Properties.VariableNames = {'timestamp' 'status'};
        turningTimestamps.Properties.VariableNames = {'timestamp' 'status'};
        walkingTimestamps.Properties.VariableNames = {'timestamp' 'status'};

        allStatus = [standingTimestamps;turningTimestamps;walkingTimestamps];
        allStatus = sortrows(allStatus,1);
        allStatus.status = categorical(allStatus.status);
        %%
        wp = webmap('Open Street Map');
        wmline(Latitude, Longitude, 'Color', 'blue' );
        %%
        sLatitude = [];
        sLongitude = [];
        tLatitude = [];
        tLongitude = [];
        intersection1WT = [];
        intersection2WT = [];
        intersection1Stands = [];
        intersection2Stands = [];
        intersection1x = [36.86856 36.86829 36.86817 36.86849 36.86856];
        intersection1y = [-76.28853 -76.28858 -76.28823 -76.28822 -76.28853];
        intersection2x = [36.86915 36.86891 36.86881 36.86907 36.86915];
        intersection2y = [-76.29197 -76.29213 -76.29170 -76.29165 -76.29197];
        
        %%
        % find the nearest position of standing time
        for i=1:length(gpstimestamp)
           dist = abs(datenum(allStatus.timestamp) - datenum(gpstimestamp(i)));
           [~,ii] = min(dist);
           
            if(allStatus.status(ii)=='STAND')
                sLatitude = [sLatitude;Latitude(i)]; % standing latitude
                sLongitude = [sLongitude;Longitude(i)]; % standing longitude
                % classify standing coordinates into 2 intersections:
                % Intesection 1 : Lewellyn x 21st
                in1 = inpolygon(Latitude(i),Longitude(i),intersection1x,intersection1y);
                if(in1)
                % this point inside intersection1, then theperson is
                % waiting
                    intersection1Stands = [intersection1Stands; Latitude(i),Longitude(i)];
                    intersection1WT = [intersection1WT;allStatus.timestamp(ii)];
                end 
                in2 = inpolygon(Latitude(i),Longitude(i),intersection2x,intersection2y);
                if(in2)
                    intersection2Stands = [intersection2Stands; Latitude(i),Longitude(i)];
                    intersection2WT = [intersection2WT;allStatus.timestamp(ii)];
                end
                
            end
        end
        
        %%
        secondsCounter1 = 0;
        secondsDiff1 = [];
        secondsDiff1 = [0;diff(intersection1WT)];% calculate the difference between timestamps
        for s = 1:length(secondsDiff1)
            if seconds(secondsDiff1(s,1))<=10 % if duration is longer than 5 seconds, it means the time stamp does not belong to the same waiting time interval
                secondsCounter1 = secondsCounter1 + seconds(secondsDiff1(s,1));
            else
                secondsCounter1 = secondsCounter1 + 0;
            end
        end
        secondsCounter2 = 0;
        secondsDiff2 = [0;diff(intersection2WT)];% calculate the difference between timestamps
        for s = 1:length(secondsDiff2)
            if seconds(secondsDiff2(s,1))<=10 % if duration is longer than 5 seconds, it means the time stamp does not belong to the same waiting time interval
                secondsCounter2 = secondsCounter2 + seconds(secondsDiff2(s,1));
            else
                secondsCounter2 = secondsCounter2 + 0;
            end
        end
        
        intersect1WaitingTime(k) = seconds(secondsCounter1);
        intersect2WaitingTime(k) = seconds(secondsCounter2);
        %%
        wmline(intersection1x,intersection1y) % plot intersection1 boundries
        hold on
        wmline(intersection2x,intersection2y) % plot intersection2 boundries
        hold on
%         wmline(intersection1Stands(:,1),intersection1Stands(:,2),'r+') % stand points inside intersection1
%         wmline(intersection2Stands(:,1),intersection2Stands(:,2),'r+') % stand points inside intersection2
%         hold off
        %%
        tind = find(allStatus.status=='TURN');
        ttimes = allStatus.timestamp(tind);

        for i=1:length(ttimes)
            dist = abs(datenum(gps.timestamp) - datenum(ttimes(i)));
            [~,ii] = min(dist);
            tLatitude = [tLatitude;Latitude(ii)]; % turning latitude
            tLongitude = [tLongitude;Longitude(ii)]; % turning longitude
        end
        wmmarker(sLatitude, sLongitude, 'Icon', 'icons8-map-pin-stand.PNG');
        wmmarker(tLatitude, tLongitude, 'Icon', 'icons8-map-pin-turn.PNG');
        %%
        figure
        title(files(k).name)
        plot(gpstimestamp,Latitude)
%         yyaxis right
%         ylabel('Accuracy (m)');
%         plot(gpstimestamp,Accuracy,'r')
end

%%
% Intersections statstics on boxplot
figure
intersect1WaitingTime = seconds(intersect1WaitingTime)';
intersect2WaitingTime = seconds(intersect2WaitingTime)';
boxplot([intersect1WaitingTime, intersect2WaitingTime],'label', {'Intersection 1', 'Intersection 2'});
xlabel('Intersections')
ylabel('Waiting Time (sec)')
title('Waiting Time at Intersections')
