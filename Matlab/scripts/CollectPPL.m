function [fileName, bestParams, n_sets] = CollectPPL(folder, m, D, limit)
    files = dir([folder '/**/*optPPL*']);
    load([files(1).folder '/' files(1).name],'Results')
    nParams = length(Results.xbest);
    parameterSets = nan(length(files), nParams+1);
    parameterSets(:,1) = 1e90;
    
    i = 1;
    for experiment = shuffle(string(fieldnames(D))')
        for var = shuffle(string(fieldnames(D.(experiment)))')
            if ~ismember(var, ["meta", "info", "input", "inputs"])
                for t = shuffle(D.(experiment).(var).Time(:).')
                    for pol = [-1, 1]
                        fprintf('Collecting [%s, %s, %g, %i]\n',  experiment, var, t, pol)
    
                        % Load the best solution found so far
                        files = dir(sprintf('%s/**/[%s, %s, %g] optPPL*.mat', folder, experiment, var, t));
    
                        while true % Runs until the cost is acceptable, or no files exist
                            filesT = struct2table(files);
                            values = pol*str2double(extract(filesT.name, regexpPattern('[\+\-0-9]\.[0-9]+e[\+\-][0-9]+')));
                            [~, minIdx] = min(values);
    
                            Results_temp = load_file(files(minIdx));
                            cost = obj_f(Results_temp.xbest, m, D);
    
                            if cost<=limit+0.1
                                parameterSets(i, 1) = cost;
                                parameterSets(i, 2:end) = Results_temp.xbest;
                                i = i+1;
                                break
                            elseif isempty(values)
                                break
                            end
                            files(minIdx) = [];
                        end
                    end
                end
            end
        end
    end
    
    parameterSets(any(isnan(parameterSets),2),:) = [];
    parameterSets = unique(parameterSets , 'rows');
    
    parameterSets = sortrows(parameterSets,1,'ascend');
    bestParams = parameterSets(1,2:end);
  
    parameterSets(:,end+1) = nan;
    fileName = 'PPL_parameters_collected.dat';
    writematrix(parameterSets, [folder '/' fileName])

    n_sets = size(parameterSets,1);
    end