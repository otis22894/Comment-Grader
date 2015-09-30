function [grade] = commentGrader(filename)
% This function does the actual grading of the files
% Files are graded on 3 criteria
%   1. What percentage of words per line are real (english) words
%   2. What is the ratio of comment lines to total lines
%   3. What is the spread (distribution) of comment lines to total lines
% Grades are then assigned by constants which can be seen at the bottom. 
% Insert filename into hashtable
insertItem(filename); 
fh = fopen(filename);
line = fgetl(fh);
totalLines = 0;
commentLines = 0;

%The first loop runs through the file and adds all the varialbe names to
%the hash table so they can be recodnized as real words later
while ischar(line)
    %Remove all spaces, makes parsing easier
    line(isspace(line)) = '';
    %Don't worry about lines with main keywords
    if ~isempty(line) && isempty(strfind(line,'function')) && isempty(strfind(line,'end')) && isempty(strfind(line,'else')) && isempty(strfind(line,'otherwise'))
        %Only count lines with code
        totalLines = totalLines + 1;
        %Skip comment lines / conditional / loop lines
        if line(1) ~= '%' && isempty(strfind(line,'if')) && isempty(strfind(line,'for')) && isempty(strfind(line,'while')) && isempty(strfind(line,'elseif')) && isempty(strfind(line,'switch')) && isempty(strfind(line,'case'))
            % Find assignemnt if there is one
            equals = find(line=='=');
            % Only continue parsing if there is a variable
            if ~isempty(equals)
                assignment = equals(1);
                %Pull variable name 
                varName = line(1:assignment-1);
                %Checks to make sure we didn't pull a logical comparison,
                %that's bad
                if (~isempty(varName) && (varName(end) ~= '~' && varName(end) ~= '<' && varName(end) ~= '>')) && (numel(line)>=(assignment+1)  && line(assignment+1) ~= '=')
                    %Multiple outputs if there is a bracket
                    if varName(1) == '['
                        %The following only works for multiple outputs
                        %separated by commas, because the spaces were
                        %removed earlier, this is such a small bug that it
                        %is not worth all the extra time fixing
                        varName(1) = '';
                        varName(end) = '';
                        commas = [0 find(varName==',')];
                        %Insert all variable names into hash table
                        for i = 1:length(commas)-1
                            insertItem(varName(commas(i)+1:commas(i+1)-1));
                        end
                        insertItem(varName(commas(end)+1:end));
                    else
                        %Insert single variable name into hash table
                        insertItem(varName);
                    end
                end
            end
        end
    end
    line = fgetl(fh);
end

frewind(fh);
line = fgetl(fh);
%Status = is each word a real word
status = zeros(commentLines,15);
%Grouping = spread of comment/code lines
grouping = zeros(1,2*totalLines);
j = 1;
i  = 1;
%This second loop does the grading of the file 
while ischar(line)
    %Remove beginning/ending spaces
    line = strtrim(line);
    %Start counting words
    wordCount = 1;
    if ~isempty(line)
        %Find out if the line has a comment in it or not
        %Also account for in-line comments
        if ~isempty(strfind(line,'%'))
            %Find where the comment starts
            loc = strfind(line,'%'); 
            %If it is more than 10 into the line (spaces excluded) 
            %I assume it is an in-line comment (meaning that there is 
            %code and comments on the line
            %10 is an arbirary number and can be changed in the future
            if loc(1) >= 10
                %If in-line comment, we need to add a 0 and a 1 to grouping
                %otherwise students won't get the grade they deserve
                %Without this, inline commenting just looks like a chunk of
                %comments 
                grouping(j) = 0; 
                grouping(j+1) = 1; 
                j = j + 1; 
            else
                %Otherwise, mark that line as a comment
                grouping(j) = 1; 
            end
            %Take out the comment part
            line = line(strfind(line,'%'):end);
            %Incriment line counter
            commentLines = commentLines + 1;
            %Take out all percent signs, not necessary
            line = strrep(line,'%','');
            %Take out beg/end spaces
            line = strtrim(line);
            %Split up the line up into words (cell array)
            words = strsplit(line); 
            %Loop through all the words
            for w = 1:length(words)
                %Look up each word in the dictionary, and place the result
                %in the status array (1 = word, 0 = not word)
                status(i,wordCount) = lookUp(upper(words{w}(isletter(words{w})))); 
                wordCount = wordCount + 1;
            end
            %Place word count ni status array at the end
            status(i,wordCount) = wordCount-1;
            i = i + 1;
        else
            %Not a comment line
            grouping(j) = 0;
        end
        j = j + 1;
    end
    line = fgetl(fh);
end
%Start calculating percentages
percentages = zeros(1,size(status,1),'int8');
for i = 1:size(status,1)
    %Calculate the percentage of words that were in the dictionary
    row = status(i,:);
    total = row(row>1);
    if total ~= 0
        percentages(i) = sum(row(1:total)) ./ total;
    end
end
%Find percentages needed for grading
engWordPercent = mean(percentages);
percentageOfLines = commentLines / (totalLines-2);
percentageSpread = sum(abs(diff(grouping))) /(totalLines-2);

%Assign a grade
%These constants can be changed in the future if need be
if engWordPercent >= 0.75 && percentageOfLines >= 0.20 && percentageSpread >= 0.20
    grade = 3;
elseif engWordPercent >= 0.50 && percentageOfLines >= 0.1 && percentageSpread >= 0.1
    grade = 2;
elseif engWordPercent >= 0.25 && percentageOfLines >= 0.05 && percentageSpread >= 0.07
    grade = 1;
else
    grade = 0;
end

fclose(fh);
end

function res = lookUp(str)
%This function looks up words in the dictionary
%Look up time of O(N) where N is the size of the dictionary
global hashTable
index = hashCode(str);
res = false;
cl = hashTable{index};
for ndx = 1:length(cl)
    if strcmp(cl{ndx}, str)
        res = true;
        break;
    end
end
end

function k = hashCode(str)
%This function creates a hash code for the given string input
    global p
    global hashSz
    N = min(length(str), 10);
    k = str(1:N) * p(1:N)';
    k = round(rem(k, hashSz)) + 1;
end

function insertItem(str)
%This function inserts a string into the hash table dictionary
global hashTable
index = hashCode(str);
if isempty(hashTable{index})
    entry = {str};
else
    entry = [{str} hashTable{index}];
end
hashTable(index) = {entry};
end

function terms = strsplit(s)
%this function splits up a line into a cell array of words
w = isspace(s);
if any(w)
    % decide the positions of terms
    dw = diff(w);
    sp = [1, find(dw == -1) + 1];     % start positions of terms
    ep = [find(dw == 1), length(s)];  % end positions of terms
    nt = numel(sp);
    terms = cell(1, nt);
    for i = 1 : nt
        terms{i} = s(sp(i):ep(i));
    end
else
    terms = {s};
end
end
