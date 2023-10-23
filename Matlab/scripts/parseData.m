function [D] = parseData(dataFile)
    D = jsondecode(fileread(dataFile));
    
    for experiment_cell = fieldnames(D)'
        experiment = experiment_cell{:};
        inputs = [];
        for inp_cell = fieldnames(D.(experiment).input)'
            inp = inp_cell{:};
            tmpInput = table();
            tmpInput.t = D.(experiment).input.(inp).t;
            tmpInput.(inp) = D.(experiment).input.(inp).f;
            if isempty(inputs)
                inputs = tmpInput;
            else
                inputs = outerjoin(inputs, tmpInput,'MergeKeys',true);
            end
        end
    
        D.(experiment).inputs = fillmissing(inputs,'previous');
        D.(experiment).input = [];
    end
end
