function [Results] = load_file(file)    
load([file.folder '/' file.name], 'Results')
end