% Plots from a pre-loaded TEOAE data structure
figure(1);
hold on;
plot(click.freq*1e-3, db(abs(click.Resp)), 'linew', 2);
ylabel('Response (dB SPL)', 'FontSize', 16);

uplim = max(db(abs(click.Resp)));
hold on;
semilogx(click.freq*1e-3, db(abs(click.NoiseFloor)), 'linew', 2);
xlabel('Frequency (kHz)', 'FontSize', 16);
legend('TEOAE', 'NoiseFloor');
xlim([0.4, 16]);
ticks = [0.5, 1, 2, 4, 8, 16];
set(gca, 'XTick', ticks, 'FontSize', 14, 'xscale', 'log');
ylim([-60, uplim + 5]);