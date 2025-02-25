clear ; close all; clc
%13/03/2020 - 15/02/2022
data = readtable('autonomous_agents_data_v2.xlsx');

%pm stands for per million
new_cases_pm = table2array(data(:,{'new_cases_per_million'}));

%Calculate smoothed statistics
%spm stands for 3 days smoothed per million
new_cases_spm = zeros(length(new_cases_pm)-2,1);

%1st value refers to 1 day AFTER the original start
%and last value 1 day BEFORE the original end
%14/03/2020 - 14/02/2022
for i=1:length(new_cases_spm)
    new_cases_spm(i,1) = mean(new_cases_pm(i:i+2,1));
end

%3 classes for percentage change
%Class 1: more than 5% decrease
%Class 2: more than 5% increase
%Class 3: +/- 5% change

%Transition Model: P(true_cases_t|true_cases_t-1)
T = [2/9 1/72 5/72; 1/72 2/9 5/72; 6/72 6/72 2/9];  %previous state in rows, next state in columns

%Sensor Model: P(new_cases_t|true_cases_t)
sensor_model = [5/18 1/72 2/72; 1/72 5/18 2/72; 3/72 3/72 5/18];
%D_t = P(new_cases_t|true_cases_t=i)
D1 = diag(sensor_model(1,:));   %Class 1
D2 = diag(sensor_model(2,:));   %Class 2
D3 = diag(sensor_model(3,:));   %Class 3
D = zeros(length(new_cases_spm),3,3);
D(1,:,:) = D3;

new_cases_spm_perc_change = zeros(length(new_cases_spm),3);
new_cases_spm_perc_change (1,:) = [0 0 1];
for i=2:length(new_cases_spm)
    %P(d_cases%) percentage change of cases
    if new_cases_spm(i,1)/new_cases_spm(i-1,1) - 1 < -0.05
        %more than 5% decrease from prev
        new_cases_spm_perc_change(i,:) = [1 0 0];
        D(i,:,:) = D1;
    elseif new_cases_spm(i,1)/new_cases_spm(i-1,1) - 1 > 0.05
        %more than 5% increase from prev
        new_cases_spm_perc_change(i,:) = [0 1 0];
        D(i,:,:) = D2;
    else
        %+/- 5% of prev
        new_cases_spm_perc_change(i,:) = [0 0 1];
        D(i,:,:) = D3;
    end
end

%% Filtering/Check the obvious
filtering_count = 0;
true_cases_spm_perc_change = zeros(size(new_cases_spm_perc_change));
for t=1:length(new_cases_spm)
    true_cases_spm_perc_change(t,:) = forward(t,D,T);
    true_cases_spm_perc_change_sum = sum(sum(true_cases_spm_perc_change(t,:)));
    true_cases_spm_perc_change(t,:) = true_cases_spm_perc_change(t,:)./true_cases_spm_perc_change_sum; %normalize, so the probabilities sum to 1
    [M1,I1] = max(true_cases_spm_perc_change(t,:));
    [M2,I2] = max(new_cases_spm_perc_change(t,:));
    if I1 == I2 %check if true_cases imitate new_cases
        filtering_count = filtering_count+1;
    end
end

fprintf("Fitlering is %f%% accurate\n", 100*filtering_count/t);


%% Prediction
%days for which we will predict
dt = between(datetime('15-Feb-2022'), datetime('2-Mar-2022'), 'days');
dt = abs(split(dt,'days'))+1;   %"+1" to include March 2nd

predicted_true_cases_spm_perc_change = zeros(dt,3);
predicted_true_cases_spm_perc_change(1,:) = true_cases_spm_perc_change(t,:)*T;  %for 15/2, first day of non-monitored data
predicted_true_cases_spm_perc_change_sum = sum(sum(predicted_true_cases_spm_perc_change(1,:)));
predicted_true_cases_spm_perc_change(1,:) = predicted_true_cases_spm_perc_change(1,:)./predicted_true_cases_spm_perc_change_sum;

for t=2:dt  %for the next days
    predicted_true_cases_spm_perc_change(t,:) = predicted_true_cases_spm_perc_change(t-1,:)*T;
    predicted_true_cases_spm_perc_change_sum = sum(sum(predicted_true_cases_spm_perc_change(t,:)));
    predicted_true_cases_spm_perc_change(t,:) = predicted_true_cases_spm_perc_change(t,:)./predicted_true_cases_spm_perc_change_sum;
end

%data on excel for period 13/02/2022 - 03/03/2022
prediction_data = readtable('autonomous_agents_prediction_data_v2.xlsx');
prediction_new_cases_pm = table2array(prediction_data(:,{'new_cases_per_million'}));
prediction_new_cases_spm = zeros(length(prediction_new_cases_pm)-2,1);

%Calculate smoothed statistics
%1st value refers to 1 day AFTER the original start
%and last value 1 day BEFORE the original end
%aka 14/02/2022 - 03/03/2022
for i=1:length(prediction_new_cases_spm)
    prediction_new_cases_spm(i,1) = mean(prediction_new_cases_pm(i:i+2,1));
end

%1st value refers to 2 DAYS AFTER the original start, aka 15/02/2022
prediction_new_cases_spm_perc_change = zeros(length(prediction_new_cases_spm)-1,3);

for i=2:length(prediction_new_cases_spm_perc_change)
    %P(d_cases%) percentage change of cases
    if prediction_new_cases_spm(i,1)/prediction_new_cases_spm(i-1,1) - 1 < -0.05
        %more than 5% decrease from prev
        prediction_new_cases_spm_perc_change(i,:) = [1 0 0];
        D(i,:,:) = D1;
    elseif prediction_new_cases_spm(i,1)/prediction_new_cases_spm(i-1,1) - 1 > 0.05
        %more than 5% increase from prev
        prediction_new_cases_spm_perc_change(i,:) = [0 1 0];
        D(i,:,:) = D2;
    else
        %+/- 5% of prev
        prediction_new_cases_spm_perc_change(i,:) = [0 0 1];
        D(i,:,:) = D3;
    end
end

prediction_count = 0;
for t=1:length(predicted_true_cases_spm_perc_change)
    [M1,I1] = max(predicted_true_cases_spm_perc_change(t,:));
    [M2,I2] = max(prediction_new_cases_spm_perc_change(t,:));
    if I1 == I2 %check if true_cases imitate new_cases
        prediction_count = prediction_count+1;
    end
end
fprintf("Prediction is %f%% accurate\n", 100*prediction_count/t);


%Θεώρημα Ολική Πιθανότητας -> NOT WORKING AT THE MOMENT
% P_true_cases_spm = zeros(length(new_cases_spm),3,1);
% P_true_cases_spm(1,:) = [0 0 1];
% for i=2:length(new_cases_spm)
%     P_true_cases_spm(i,:) = transpose(transition_model*transpose(P_true_cases_spm(i-1,:)))/(1-sensor_model);
%     %a = sum(P_true_cases_spm(i,:));
%     %P_true_cases_spm(i,:) = P_true_cases_spm(i,:)./a;
% end
