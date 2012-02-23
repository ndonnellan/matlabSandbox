function [name, type, depth, varsToTest, tAccess, tAssign] = ...
    benchmark(varargin)
%% Description
%   [name, type, depth, varsToTest, tAccess, tAssign] = benchmark(varargin)
%
%   Find unique combinations of variable type, size and nesting level and
%   compute the time required for some simple assignment and access
%   operations. BENCHMARK takes any number of different variables as
%   arguments.
%
%   Example:
%       a = 1;
%       str = 'somestring';
%       s = struct('a',1,'str','otherstring');
%       f = @(x)x^2;
%       s2 = struct('bah',struct('hum',struct('bug',1)));
%       benchmark(a,str,s,f,s2);
%   << console output >>
% Benchmark complete
%   tAccess             tAssign           
%   0.81  ms            0.64  ms            double
%   0.86  ms            0.59  ms            char
%    6.7  ms              11  ms            struct > double
%    6.8  ms              11  ms            struct > char
%      1  ms            0.53  ms            function_handle
%      3  ms             5.8  ms            struct
%    7.7  ms              17  ms            struct > struct (2 similar)
%     11  ms              24  ms            struct > struct > struct
%     12  ms              24  ms            struct > struct > struct > double
%
name = {};
type = {};
depth = [];
typePath = {};
currDepth = 0;
sz = {};
maxDim = 1;
arg = [];

for n = 1:nargin
    % For each variable, determine the type, nest depth and push it to the
    % stack of variables to be analyzed
    thisVar = varargin{n};
    currLength = length(name);
    categorize(thisVar, ['var',num2str(n)], class(thisVar));
    
    % Set argument number using the change in length of the "arg" array
    if isempty(arg)
        arg = n * ones(length(name),1);
    else
        arg(currLength+1:length(name),1) = n;
    end
end

% Transform the size cell array into a matrix and set the sizes using the
% "sz" variable
sizeMat = ones(length(depth),maxDim);
for k = 1:nargin
    sizeMat(k, 1:length(sz{k})) = sz{k};
end

% Total array size (product of dimensions)
arraySize = prod(sizeMat,2);

% Find uniques among the properties we care about
[~, ~, idxTypes] = unique(type);
[~, ~, idxDepth] = unique(depth);
[~, ~, idxSize]  = unique(arraySize);

% Only keep sufficiently unique variables to benchmark (unique combination
% of type, size and nesting)
[~, varsToTest, similar] = unique([idxTypes, idxDepth, idxSize],'rows');
varsToTest = sort(varsToTest); % Re-order

tAccess = zeros(length(varsToTest),1);
tAssign = tAccess;
N = 1000;
for k = 1:numel(tAccess)
    varIdx = varsToTest(k);
    tic;
    accessTest(varargin{arg(varIdx)}, name{varIdx}, N);
    tAccess(k) = toc;
    
    tic;
    assignTest(varargin{arg(varIdx)}, name{varIdx}, N);
    tAssign(k) = toc;
end

disp('Benchmark complete');

% Remove parenthesis that were used in the computation
name = regexprep(name, '\(1\)', '');

fprintf([padStr('  tAccess', 20), padStr('  tAssign', 20), '\n']);
for k = 1:length(varsToTest)
    fprintf(padStr(['  ', timeStr(tAccess(k))], 20));
    fprintf(padStr(['  ', timeStr(tAssign(k))], 20));
    str = ['  ', typePath{varsToTest(k)}];
    if nnz(similar == k) > 1
        % If there are multiple matches for this combo, append a tag
        str = [str, ' (', num2str(nnz(similar==k)), ' similar)'];
    end
    fprintf([str, '\n']);
end
% End main function

    function categorize(var,thisName,thisType) % Begin nested function -------------
        props = whos('var');
        name    = [name;     thisName];
        type    = [type;     props.class];
        typePath= [typePath; thisType];
        depth   = [depth;    currDepth];
        sz      = [sz;       props.size];
        
        maxDim = max(numel(props.size),maxDim); % Update largest dimension
        
        if isstruct(var) || isobject(var)
            % Append a (1) to the name to deal with arrays of structs or
            % objects
            name{end}   = [name{end},'(1)'];
            thisName    = name{end};
            
            currDepth   = currDepth + 1; % Going down
            for f = fieldnames(var)' % FIELDNAMES returns a list of strings
                nextName = f{:}; % "f" is a 1x1 cell
                categorize(...
                    var(1).(nextName),...
                    [thisName, '.', nextName],...
                    [thisType, ' > ', class(var(1).(nextName))]);
            end
            currDepth   = currDepth - 1; % Coming up
        end
        
        if iscell(var)
            % Cells are unsupported at this point
        end
        
    end % End nested function ---------------------------------------------
end

function accessTest(var, varName, N)
% Access the variable given in "varName" using "var" N times
top = regexp(varName, '^\w+(?=\.)', 'match');

% Evaluate in this workspace
if isempty(top)
    eval([varName ' = var;']);
else
    % For nested objects
    eval([top{1} ' = var;']);
end
eval([...
    'for n = 1:N, ',...
    'a = ', varName, ';',...
    'end']);
end


function assignTest(var, varName, N)
% Assign the variable given in "varName" using "var" N times
top = regexp(varName,'^\w+(?=\.)','match');

% Evaluate in this workspace
if isempty(top)
    eval([varName ' = var;']);
else
    % For nested objects
    eval([top{1} ' = var;']);
end

eval([...
    'for n = 1:N, ',...
    varName ' = ' varName, ';',...
    'end']);
end

function str = timeStr(num)
% Takes a number in seconds of time elapsed and returns a fixed width
% representation in appropriate units
if num < 0.1
    num = num * 1e3;
    unit = ' ms'; % milliseconds
elseif num > 59.9
    num = num / 60;
    unit = 'min'; % minutes
else
    unit = 'sec'; % seconds
end

numStr = num2str(num,2);
STR_LEN = 4;
if length(numStr) < STR_LEN
    % If less than STR_LEN, prefix with whitespace
    numStr = [repmat(' ', 1, STR_LEN - length(numStr)), numStr];
end
str = [numStr, ' ', unit];
end

function str = padStr(str,L)
% Pad a string with whitespace if it's less than length "L"
Lstr = length(str);
if Lstr < L
    str = [str, repmat(' ', 1, L - Lstr)];
end
end