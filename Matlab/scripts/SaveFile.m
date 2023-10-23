function [] = SaveFile(fileName,variable, variableName)
%SaveFile, used to save file (works with parfor)
%SaveFile(fileName,variable, variableName)
%Saves a file with "fileName" with the content of a "variable" with name "variableName"

S.(variableName)=variable;
save(fileName,'-struct', 'S')

end