function [] = WaterfallPI(resultsFolder)

files = dir(['Results_PI/' resultsFolder '/']);
paramfiles = files([files.bytes]>0); % remove path levels

%find unique parameters 
pnames = struct();
for i = 1:length(paramfiles)
    pnames.name(i) = convertCharsToStrings(extractBefore(paramfiles(i).name, ' (' ));
end
uniquePNames = unique(pnames.name); 

%result structure
results = struct();

%itterate over all parametes 
for pnum = 1:length(uniquePNames)
    id = [];
    for i = 1:length(paramfiles)
        id(i) = isequal(pnames.name(i), uniquePNames(pnum));
    end
    
    % find the inital parameter and the value
    idStartguess = 0;
    startvalue = 0;
    for j = find(id==1)
        name = regexp(paramfiles(j).name,'\S+\s.\d+.\d+\S\S\d+\S+','match'); 
        if contains(name{:}, '.mat')
            idStartguess = j;
            startvalue = str2double(regexp(paramfiles(j).name,'\d+.\d+\S+\d+','match'));
            results.(uniquePNames(pnum)).maximize = startvalue;
            results.(uniquePNames(pnum)).minimize = startvalue;
            break

        end
    end

    %itterate over the parameter
    for j = find(id==1)
        if j ~= idStartguess %startguess already handled
            values  = str2double(regexp(paramfiles(j).name,'\d+.\d+\S+\d+','match'));
    
            if values(1) >= startvalue
                results.(uniquePNames(pnum)).maximize = [results.(uniquePNames(pnum)).maximize; values(1)];
            else
                results.(uniquePNames(pnum)).minimize = [results.(uniquePNames(pnum)).minimize; values(1)];
            end
        end
    end
end

fields = fieldnames(results); 
for i = 1:length(fields)
    field = fields{i};
    results.(field).maximize = sort(results.(field).maximize, 'ascend'); 
    results.(field).minimize = sort(results.(field).minimize, 'descend'); 

    %plot
    figure('Name',field)
    subplot(1,2,1)
        plot(1:length(results.(field).maximize), log(results.(field).maximize), '-s', "MarkerFaceColor", "blue", "MarkerEdgeColor", "blue")
        title('Maximize')
        xlabel('iterations')
        ylabel('value (log)')
    subplot(1,2,2)
        plot(1:length(results.(field).minimize), log(results.(field).minimize), '-s', "MarkerFaceColor", "blue", "MarkerEdgeColor", "blue")
        title('Minimize')
        xlabel('iterations')
        ylabel('value (log)')
        exportgraphics(gcf, sprintf('Figures/PI-waterfall/%s.pdf',field), "BackgroundColor","none","ContentType","vector")
end

end