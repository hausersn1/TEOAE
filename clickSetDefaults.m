function click = clickSetDefaults(att)

%set default parameters

if ~exist('att', 'var')
    click.Attenuation = 45; %60;
else
    click.Attenuation = att;
end
click.Vref  = 1;
click.BufferSize = 2048;
click.RespDur = 1024;
click.SamplingRate = 48.828125; %kHz
click.Averages = 2048;
click.ThrowAway = 8;
click.doFilt = 1;
click.StimWin = 128;
click.device = 'ER10X';
