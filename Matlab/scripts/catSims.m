function [S] = catSims(structs, skipT1)
%CatSims Concatenates multiple structs in an array
if nargin<2
    skipT1 = true;
end

if skipT1 % When simulating, we need to start in the same point as we ended in the previous simulation, but we do not want to store that time twice
    idx1 = 2;
else
    idx1 = 1;
end
S = structs(1);
for i = 2:length(structs)
    fields = fieldnames(S);
    for k = 1:numel(fields)
        aField     = fields{k}; 
        if strcmp(aField,'time') % If field is a horizontal 1D array
            S.(aField) = horzcat(S.(aField), structs(i).(aField)(idx1:end));
        elseif contains(aField, 'values')%if field is a vertical 1D array
            S.(aField) = vertcat(S.(aField), structs(i).(aField)(idx1:end,:));
        end
    end
end
end
