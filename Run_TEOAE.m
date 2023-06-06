%% CLICK OAE using traditional windowing method
function Run_TEOAE(att)

try
    % Initialize ER-10X  (Also needed for ER-10C for calibrator)
    initializeER10X;
    
    % Initializing TDT
    % Specify path to cardAPI here
    pcard = genpath('C:\Experiments\cardAPI\');
    addpath(pcard);
    card = initializeCard;
    
    
    % Initializing Calibration
    if exist('att', 'var')
        click = clickSetDefaults(att);
    else
        click = clickSetDefaults();
    end
    
    driverflag = 1;
    while driverflag == 1
        driver = input('Please enter whether you want driver 1 or 2 (on ER-10X):');
        switch driver
            case {1, 2}
                drivername = strcat('Ph',num2str(driver));
                driverflag = 0;
            otherwise
                fprintf(2, 'Unrecognized driver! Try again!');
        end
    end
    click.drivername = drivername;
    
    subj = input('Please subject ID:', 's');
    earflag = 1;
    while earflag == 1
        ear = input('Please enter which ear (L or R):', 's');
        switch ear
            case {'L', 'R', 'l', 'r', 'Left', 'Right', 'left', 'right', 'LEFT', 'RIGHT'}
                earname = strcat(ear, 'Ear');
                earflag = 0;
            otherwise
                fprintf(2, 'Unrecognized ear type! Try again!');
        end
    end
    
    % The button section is just so you can start the program, go into the
    % booth and run yourself as the subject
    button = input('Do you want the subject to press a button to proceed? (Y or N):', 's');
    switch button
        case {'Y', 'y', 'yes', 'Yes', 'YES'}
            getResponse(card.RZ);
            fprintf(1, '\nSubject pressed a button...\nStarting Stimulation...\n');
        otherwise
            fprintf(1, '\nStarting Stimulation...\n');
    end
    
    % Make directory to save results if it doesn't already exist
    paraDir = './Results/';
    % whichScreen = 1;
    addpath(genpath(paraDir));
    if(~exist(strcat(paraDir,'\',subj),'dir'))
        mkdir(strcat(paraDir,'\',subj));
    end
    respDir = strcat(paraDir,'\',subj,'\');
    
    % Make click
    vo = clickStimulus(click.BufferSize + click.StimWin);
    buffdata = zeros(2, numel(vo));
    buffdata(driver, :) = vo; % The other source plays nothing
    click.vo = vo;
    odd = 1:2:click.Averages;
    even = 2:2:click.Averages;
    
    
    
    
    drop = click.Attenuation;
    dropOther = 120;
    
    if driver == 1
        vins = playCapture2(buffdata, card, click.Averages, ...
            click.ThrowAway, drop, dropOther, 1);
    else
        vins = playCapture2(buffdata, card, click.Averages, ...
            click.ThrowAway, dropOther, drop, 1);
    end
    
    %compute the average
    vins = vins(:, (click.StimWin+1):(click.StimWin + click.RespDur)); % Remove stimulus by windowing
    
    if click.doFilt
        % High pass at 200 Hz using IIR filter
        [b, a] = butter(4, 200 * 2 * 1e-3/click.SamplingRate, 'high');
        vins = filtfilt(b, a, vins')';
    end
    
    vavg_odd = trimmean(vins(odd, :), 20, 1);
    vavg_even = trimmean(vins(even, :), 20, 1);
    rampdur = 0.2e-3; %seconds
    Fs = click.SamplingRate/2 * 1e3;
    click.vavg = rampsound((vavg_odd + vavg_even)/2, Fs, rampdur);
    click.noisefloor = rampsound((vavg_odd - vavg_even)/2, Fs, rampdur);
    
    
    Vavg = rfft(click.vavg);
    Vavg_nf = rfft(click.noisefloor);
    
    % Apply calibartions to convert voltage to pressure
    % For ER-10X, this is approximate
    mic_sens = 50e-3; % mV/Pa. TO DO: change after calibration
    mic_gain = db2mag(gain + 6); % +6 for balanced cable
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
    fname = strcat(respDir,'CEOAE_',click.drivername,click.device,'_',...
        subj,earname,'_',datetag, '.mat');
    save(fname,'click');
    
    %% Close TDT, ER-10X connections etc. and cleanup
    
    closeER10X;
    closeCard(card);
    rmpath(pcard);
    
    % just before the subject arrives
    
catch me
    closeER10X;
    closeCard(card);
    rmpath(pcard);
    rethrow(me);
end