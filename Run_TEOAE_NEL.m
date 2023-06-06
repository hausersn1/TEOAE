%% CLICK OAE using traditional windowing method
function Run_TEOAE_NEL(att)

% Create subject
subj = input('Please subject ID:', 's');
earflag = 1;
while earflag == 1
    ear = input('Please enter which year (L or R):', 's');
    switch ear
        case {'L', 'R', 'l', 'r', 'Left', 'Right', 'left', 'right', 'LEFT', 'RIGHT'}
            earname = strcat(ear, 'Ear');
            earflag = 0;
        otherwise
            fprintf(2, 'Unrecognized ear type! Try again!');
    end
end

% Make directory to save results
paraDir = 'C:\Users\Heinz Lab - NEL2\Desktop\TEOAE\Results';
addpath(genpath(paraDir));
if(~exist(strcat(paraDir,'\',subj),'dir'))
    mkdir(strcat(paraDir,'\',subj));
end
respDir = strcat(paraDir,'\',subj,'\');

% Tell user to make sure ER-10B+ gain is set correctly
uiwait(warndlg('Set ER-10B+ GAIN to 40 dB','SET ER-10B+ GAIN WARNING','modal'));

% Initializing Calibration
if exist('att', 'var')
    click = clickSetDefaults_NEL(att);
else
    click = clickSetDefaults_NEL();
end

% Make click
vo = clickStimulus(click.BufferSize + click.StimWin);
buffdata = zeros(2, numel(vo));
buffdata(1, :) = vo; % The other source plays nothing
click.vo = vo;
odd = 1:2:click.Averages;
even = 2:2:click.Averages;

drop = click.Attenuation;
dropOther = 120;

% Ask if we want a delay (for running yourself)
button = input('Do you want a 10 second delay? (Y or N):', 's');
switch button
    case {'Y', 'y', 'yes', 'Yes', 'YES'}
        DELAY_sec=10;
        fprintf(1, '\n%.f seconds until START...\n',DELAY_sec);
        pause(DELAY_sec)
        fprintf(1, '\nWe waited %.f seconds ...\nStarting Stimulation...\n',DELAY_sec);
    otherwise
        fprintf(1, '\nStarting Stimulation...\n');
end
% Initializing TDT
fig_num=99;
GB_ch=1;
FS_tag = 3;
Fs = 48828.125;
[f1RZ,RZ,~]=load_play_circuit_Nel2(FS_tag,fig_num,GB_ch);

% Make arrays to store measured mic outputs
resp = zeros(click.Averages, size(buffdata,2));
for k = 1:(click.Averages + click.ThrowAway)
    
    % Load the 2ch variable data into the RZ6:
    invoke(RZ, 'WriteTagVEX', 'datainL', 0, 'F32', buffdata(1, :));
    invoke(RZ, 'WriteTagVEX', 'datainR', 0, 'F32', buffdata(2, :));
    
    % Set the delay of the sound
    invoke(RZ, 'SetTagVal', 'onsetdel',100); % onset delay is in ms
    playrecTrigger = 1;
    
    % Set attenuations
    rc = PAset([0, 0, drop, dropOther]);
    
    % Set total length of sample
    RZ6ADdelay = 97; % Samples
    resplength = size(buffdata,2) + RZ6ADdelay; % How many samples to read from OAE buffer
    invoke(RZ, 'SetTagVal', 'nsamps', resplength);
    
    %Start playing from the buffer:
    invoke(RZ, 'SoftTrg', playrecTrigger);
    currindex = invoke(RZ, 'GetTagVal', 'indexin');
    
    while(currindex < resplength)
        currindex=invoke(RZ, 'GetTagVal', 'indexin');
    end
    
    vin = invoke(RZ, 'ReadTagVex', 'dataout', 0, resplength,...
        'F32','F64',1);
    
    % Save data
    if k > click.ThrowAway
        resp(k - click.ThrowAway,  :) = vin((RZ6ADdelay + 1):end);
    end
    
    % Get ready for next trial
    invoke(RZ, 'SoftTrg', 8); % Stop and clear "OAE" buffer
    %Reset the play index to zero:
    invoke(RZ, 'SoftTrg', 5); %Reset Trigger
    
    pause(0.05);
    
    fprintf(1, 'Done with trial %d / %d\n', k,...
        (click.ThrowAway + click.Averages));
end

%% Close
close_play_circuit(f1RZ, RZ);


%% Analysis
%compute the average
resp = resp(:, (click.StimWin+1):(click.StimWin + click.RespDur)); % Remove stimulus by windowing

if click.doFilt
    % High pass at 200 Hz using IIR filter
    [b, a] = butter(4, 200 * 2 * 1e-3/click.SamplingRate, 'high');
    resp = filtfilt(b, a, resp')';
end

vavg_odd = trimmean(resp(1:2:end, :), 20, 1);
vavg_even = trimmean(resp(2:2:end, :), 20, 1);
rampdur = 0.2e-3; %seconds
Fs = click.SamplingRate/2 * 1e3;
click.vavg = rampsound((vavg_odd + vavg_even)/2, Fs, rampdur);
click.noisefloor = rampsound((vavg_odd - vavg_even)/2, Fs, rampdur);

Vavg = rfft(click.vavg);
Vavg_nf = rfft(click.noisefloor);

% Apply calibartions to convert voltage to pressure
% For ER-10X, this is approximate
mic_sens = 50e-3; % mV/Pa. TO DO: change after calibration
mic_gain = db2mag(40); % +6 for balanced cable
P_ref = 20e-6;
DR_onesided = 1;
factors = DR_onesided * mic_gain * mic_sens * P_ref;
output_Pa_per_20uPa = Vavg / factors; % unit: 20 uPa / Vpeak
noise_Pa_per_20uPa = Vavg_nf / factors;

click.freq = 1000*linspace(0,click.SamplingRate/2,length(Vavg))';

click.Resp =  output_Pa_per_20uPa;
click.NoiseFloor = noise_Pa_per_20uPa;

%% Plot data
PlotResults_simple;

%% Save Ear Measurements
datetag = datestr(clock);
click.date = datetag;
datetag(strfind(datetag,' ')) = '_';
datetag(strfind(datetag,':')) = '_';
fname = strcat(respDir,'TEOAE_',...
    subj,earname,'_',datetag, '.mat');
save(fname,'click');
fprintf(1, 'Saved!\n');

end
