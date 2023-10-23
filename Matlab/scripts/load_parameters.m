function [Results] = load_parameters(trigger, resultsFolder)

files = dir(['Results/' resultsFolder '/']);
files = files([files.bytes]>0); % remove path levels

if trigger == "latest" && ~isempty(files)
    [~, idx] = max([files.datenum]);
    R = load( ['Results/' resultsFolder '/' files(idx).name] );

elseif trigger ==  "oldest" && ~isempty(files)
    [~, idx] = min([files.datenum]);
    R = load( ['Results/' resultsFolder '/' files(idx).name] );

elseif trigger == "min_cost" && ~isempty(files)
    cost = zeros(1,length(files));

    for i = 1:length(files)
        string = convertCharsToStrings(files(i).name);
        values  = str2double(regexp(string,'\d+','match'));
        cost(i) = str2double([num2str(values(1)) '.'  num2str(values(2))]);
    end

    [~,idx] = min(cost);
    R = load( ['Results/' resultsFolder '/' files(idx).name] );
end
Results = R.Results;
end