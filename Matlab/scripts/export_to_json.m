

function [] = export_to_json(varargin)
%% Export mat structures to json
% Inputs:
%     filepath - str including file extension (.mat)
%     isparam - optinal, bool
%     modelName - optional, string with modelName (name of IQM textfile) 

% Assign inputs
filepath = varargin{1};

switch size(varargin,2)
    case 1
        isparam = false;
        modelName = [];

    case 2
        if class(varargin{2}) == "string" || class(varargin{2}) == "char"
            modelName = varargin{2};
            isparam = false;
        else
            modelName = [];
            isparam = varargin{2};
        end

    case 3
        if class(varargin{2}) == "string" || class(varargin{2}) == "char"
            modelName = varargin{2};
            isparam = varargin{3};
        else
            modelName = varargin{3};
            isparam = varargin{2};
        end

    otherwise
        warning('to many inputs. Format is \n filepath, optional-bool, optional-modelName')

        if class(varargin{2}) == "string" || class(varargin{2}) == "char"
            modelName = varargin{2};
            isparam = varargin{3};
        else
            modelName = varargin{3};
            isparam = varargin{2};
        end
end

%% format output
data = importdata(filepath);
s = [];

%strucure param data with cost and params 
if isparam
    s.f = data.fbest;
    s.x = exp(data.xbest); 
    
    if ~isempty(modelName)
        [pnames, ~] = IQMparameters(IQMmodel([modelName '.txt']));
        s.pnames = pnames;
    end
% strucutures i.e. data structures
else
    s = data;
end

%preview format
jsonencode(s,PrettyPrint=true)

% print to file
strseg = split(filepath, ["\", "/"]);
resname = extractBefore(strseg{end}, ".mat");
JSONFILE_name= strcat([resname '.json']); 
fid=fopen(JSONFILE_name,'w'); 
fprintf(fid, jsonencode(s, PrettyPrint=true)); 
fclose(fid); 
end