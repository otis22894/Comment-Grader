function commentGrader_index
clc
tic
fprintf('Initializing gradebook and dictionary...\n'); 
% Load global hash table variables
global p
global hashSz
% Hash table should be stored in Dictionary.mat, must be in a a global
%folder
load('Dictionary.mat'); 
% Prime numbers for hashing
p = double([1 2 3 5 7 11 13 17 19 23]);
hashSz = 100000; 
%Find all students in the current folder
students = dir('*(*)');
student_names = sort(lower({students.name}));
no_Submission = 0; 
%Get the file names for testing (words about 95% of the time)
file_names = getFileNames(student_names);
%Attempt to find gradebook file
possibleNames = [dir(fullfile(cd,'*.csv'));dir(fullfile(cd,'*.xls'))];
possibleNames = {possibleNames(:).name}; 
possibleNames = possibleNames(cellfun(@(x) strcmp(x(1:9),'gradebook'),possibleNames)); 
if length(possibleNames)==1
    gradebook = possibleNames{1}; 
else
    % If can't find gradebook file, prompt user for it
    gradebook = uigetfile({'*.xls';'*.csv'},'Please select the gradebook file downloaded from T-Square'); 
end
% Pull gradebook data
[~,~,raw] = xlsread(gradebook); 
raw = raw(:,1:2); 
names = raw(2:end,2); 
[names,oldndx] = sort(lower(names));
% Get the students to skip while grading
% Might not need this with the new update
skipNDX = getSkipNdx(names,student_names);
% Need a counter so we can skip through as need be
folder_ndx = 1;
fprintf('Parsing Student Files... \n');
% Open and begin notes file for the skipped students 
fh = fopen('notes.txt','w'); 
fprintf(fh,'The following students submitted a homework, but are not part of the gradebook file provided');
fprintf(fh,'\nIt''s probably all TAs and special students approved by Professor Smith'); 
fprintf(fh,'\nIf this is not expected, redownload the gradebook file from T-Square\n\n'); 
skipCount = 0; 
for i = 1:length(raw)-1
    %Get time for display to user
    if(i~=1)
        endTime = toc(startTime); 
    else
        endTime = 0; 
    end
    %Display percentage done, time left, and dots graphic
    perccount(i,length(raw)-1,endTime);
    %Begin loop start time
    startTime = tic; 
    %See if we need to skip the student
    if all(i~=skipNDX)
        % If we encounter a submission name not in the gradebook, skip it
        % and keep skipping until we find a real name
        while ~strcmpi(names{i,1},student_names{folder_ndx}(1:find(student_names{folder_ndx}=='(')-1))
            fprintf(fh,'%s DOES NOT EXIST IN GRADEBOOK, NOT ASSIGNED COMMENT GRADE\n',student_names{folder_ndx}); 
            % Skip that folder
            folder_ndx = folder_ndx+1;
            skipCount = skipCount + 1; 
        end 
        % Go into student submission folder
        cd(student_names{folder_ndx}); 
        cd('Submission attachment(s)'); 
        % Initialize grade and problem count
        cummGrade = 0;
        problemCount = 0;
        % Loop through all reaquired files
        for j = 1:length(file_names)
            % Only check that file if they turned it in
            if exist(file_names{j},'file')
                % Pull grade from commentGrader function
                grade = commentGrader(file_names{j}); 
                cummGrade = cummGrade + grade;
                problemCount = problemCount + 1; 
            end
        end
        % Count number of people who didn't submit
        if problemCount == 0
            no_Submission = no_Submission + 1; 
        end
        % Student could have more than 100 because of the 1.2% increase
        % 1.2 bump to account for auto grader errors
        studGrade = min(((cummGrade / length(file_names)) .* (100/3)) .* 1.2,100);
        % Collect grades in second row of names cell array
        names{i,2} = studGrade;
        % Back out of student folder
        cd('..');
        cd('..');
        % Jump to the next student
        folder_ndx = folder_ndx+1;
    else
        % Assign zero if no attachments in folder
        names{i,2} = 0; 
    end
end
fclose(fh);
% Erase dot graphic
fprintf(1,repmat('\b',1,37));
fprintf('\nWriting Grade File...');
fh = fopen('grades.csv'); 
header_line = fgetl(fh); 
% Get the homework number from the grades file
homeworkNum = header_line(find(header_line==',')-2:find(header_line==',')-1); 
fclose(fh); 
% Write the new gradebook file
raw{1,3} = sprintf('EC Homework %s [100]',homeworkNum);
raw(2:end,3) = names(oldndx,2); 
xlswrite(sprintf('EC Homework %s.xls',homeworkNum),raw);
% Calc class average, subtract out those who didn't submit
classAvg = sum([raw{2:end,3}])./(length(names)-no_Submission);
time = toc;
%Display results
fprintf(['\n' repmat('=',[1,max(79,17+(3*(length(file_names)-1))+sum(cellfun(@length,file_names)))]) '\n']); 
fprintf('Total Run Time: %f\n',time);
fprintf('Class Average: %f\n',classAvg);
fprintf('FILES TESTED:  '); 
for i = 1:length(file_names)
    fprintf([file_names{i} ' | ']); 
end
fprintf('\n%d students with submissions were not in the gradebook and not assinged a grade\n',skipCount); 
fprintf('\t-Consult notes.txt for more info');
fprintf(['\n' repmat('=',[1,max(79,17+(3*(length(file_names)-1))+sum(cellfun(@length,file_names)))]) '\n']); 
end

function skipNdx = getSkipNdx(names,student_names) 
% This function finds the students who are not in the gradebook
% Student folder location is returned, and skipped in the above function
vec = ismember(names,cellfun(@(X) X(1:find(X=='(')-1),student_names,'uni',false));
skipNdx = find(vec==0); 
end

function file_names = getFileNames(student_names)
% This function attempts to pull the necessary files for grading
% Start this at 140 files, arbitrary number, needs to be big enough to
% handle 20 student's files on any given homework 
file_names = cell(1,140); 
% Pull 20 random students
for i = 1:20
    % Pull a random student
    cd(student_names{floor(1+(length(student_names)-1).*rand())}); 
    cd('Submission attachment(s)');
    % Pull all their files
    files = dir('*.m'); 
    files = {files.name}; 
    % Find where to start the insertion of the new file names
    firstNdx = find(cellfun(@isempty,file_names));
    % Put the new file names in place
    file_names(firstNdx(1):firstNdx(1)+length(files)-1) = files; 
    cd('..'); 
    cd('..'); 
end
% Find unique files, delete repeats
[file_names,~,c] = unique(file_names(~cellfun(@isempty,file_names)));
% Find how many times each file was present
repetitions = hist(c,length(file_names)); 
% Only keep those present at least twice (can be changed to bigger number
% if random files are too often kept, it hasn't been a problem so far0
file_names = file_names(repetitions>2);
% Remove homework file and ABCs
file_names = file_names(cellfun(@isempty,strfind(file_names,'hw')) & cellfun(@isempty,strfind(file_names,'ABC')));
% UNCOMMENT THE FOLLOWING CODE IF YOU ARE CONSISTENTLY MISSING A FILE OR
% TWO, MAYBE IF "HW" IS IN A FILE NAME
% file_nums = listdlg('ListString',file_names,'PromptString',sprintf('Pick ONLY the homework files...Hold CTRL to select multiple'),'Name','Select Homework Files','ListSize',[400 200],'InitialValue',1:length(file_names)); 
% file_names = file_names(file_nums);
end

function  perccount(currI,totalLoop,time)
% Define persistent variables to stay across function calls
persistent lastCall;
persistent times;
persistent dotLocs; 
if currI==1
    % Initialize variables if on first call 
    lastCall = []; 
    times = [];
    % Start necessary spaces 
    fprintf(1,repmat(' ',1,91));  
    % Initialize dot locations
    dotLocs = [1 2 3 7 8 9 13 14 15 19 20 21 25 26 27 31 32 33]; 
else
    % Collect times for averaging
    times = [times time]; 
end
% Average time and predict remaining time
timeLeft = (mean(times).*(totalLoop-currI)); 
% If this is not the first run through, and there has been a change
% percentage
% This only runs if there has been a change from the last percentage
% display
if(~isnan(timeLeft) && (currI==1 || lastCall  ~=  floor(((currI)/totalLoop) * 100)))
    % Calculate minutes and seconds left
    minutesLeft = num2str(floor(timeLeft./60)); 
    secondsLeft = num2str(round(mod(timeLeft,60)));
    % Erase old percentage, time, and dot displays
    fprintf(1,repmat('\b',1,87));
    % Calculate percentage completed
    pc_done  =  num2str(floor(((currI)/totalLoop) * 100));
    % Insert 0 in percentage if single digit
    if(length(pc_done)  ==  1)
        pc_done(2)  =  pc_done(1);
        pc_done(1)  =  '0';
    end
    % Insert 0 in minutes if single digit
    if(length(minutesLeft) == 1)
        minutesLeft(2) = minutesLeft(1); 
        minutesLeft(1) = '0'; 
    end
    % Insert 0 in seconds if single digit
    if(length(secondsLeft) == 1)
        secondsLeft(2) = secondsLeft(1); 
        secondsLeft(1) = '0'; 
    end
    % Display all lines
    fprintf(1,'      %s%% Completed\n',pc_done);
    fprintf('    Time Left: %s min. %s sec.',minutesLeft,secondsLeft);
    % Start dot display as all spaces
    dots = repmat(' ',1,36); 
    % Replace with dots
    dots(dotLocs) = '.'; 
    fprintf(1,['\n' dots]); 
    % Shift dots down one
    dotLocs = mod(dotLocs+1,37);
    % Darn you MATLAB for indexing at 0
    dotLocs(dotLocs==0) = 1; 
else
    % This section runs every time, used for dot display
    % Delete old dot display
    fprintf(1,repmat('\b',1,37));
    % Same as above
    dots = repmat(' ',1,36); 
    dots(dotLocs) = '.';
    fprintf(1,['\n' dots]); 
    dotLocs = mod(dotLocs+1,37); 
    dotLocs(dotLocs==0) = 1;
end
% Set last call to current status
lastCall  =  floor(((currI)/totalLoop) * 100);
end

