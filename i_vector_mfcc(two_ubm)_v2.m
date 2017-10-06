%% ��������

clear; close all; clc;

%% ��������� ���������� � ���������
addpath(genpath('utility'));
addpath(genpath('CQCC_v1.0'));
addpath(genpath('bosaris_toolkit'));
addpath('MSR Identity Toolkit v1.0/code');
addpath('voicebox');

%% PATH's ��� ������ � �������
dir_data = fullfile('D','Data');

pathToDatabase = fullfile(dir_data,'ASVspoof2017_train_dev','wav');
trainProtocolFile = fullfile(dir_data,'ASVspoof2017_train_dev', 'protocol', 'ASVspoof2017_train.trn');
devProtocolFile = fullfile(dir_data,'ASVspoof2017_train_dev', 'protocol', 'ASVspoof2017_dev.trl');
evaProtocolFile = fullfile(dir_data,'ASVspoof2017_eval', 'protocol', 'KEY_ASVspoof2017_eval_V2.trl');

%% ������ ����� 

fileID = fopen('D:\Data\ASVspoof2017_eval\protocol\KEY_ASVspoof2017_eval_V2.trl');
protocol = textscan(fileID, '%s%s');
filenames = protocol{1};
labels = protocol{2};
fclose(fileID);

%% ���������� ����
feature = 'mfcc_two_ubm';
directory_features = fullfile('D:','Filin','spoofing_replay_cqcc','extracted_features', feature);
                                   
load(fullfile(directory_features, 'genuineMFCCTrain.mat'));
load(fullfile(directory_features, 'genuineMFCCDev.mat'));
load(fullfile(directory_features, 'spoofMFCCDev.mat'));
load(fullfile(directory_features, 'spoofMFCCTrain.mat'));
load(fullfile(directory_features, 'evaluationMFCCFeature.mat'));

%% ���������� train � development

training_genuine = cat(1, genuineMFCCTrain, genuineMFCCDev);
training_spoof = cat(1, spoofMFCCTrain, spoofMFCCDev);
all_data = cat(1, training_genuine, training_spoof);

%% �������� �� ������ ������

clear genuineMFCCTrain;
clear genuineMFCCDev;
clear spoofMFCCTrain;
clear spoofMFCCDev;

%%  UBM-������

nmix = 512; % number of Gaussian components
final_niter = 10;
ds_factor = 1;
nWorkers = 12; % max allowed in the toolkit

ubm = gmm_em(all_data(:),nmix, final_niter, ds_factor, nWorkers);
ubm_genuine = gmm_em(training_genuine(:), nmix, final_niter, ds_factor, nWorkers);
ubm_spoof = gmm_em(training_spoof(:), nmix, final_niter, ds_factor, nWorkers);

save(fullfile(directory_features, 'ubm.mat'), 'ubm');
save(fullfile(directory_features, 'ubm_genuine.mat'), 'ubm_genuine');
save(fullfile(directory_features, 'ubm_spoof.mat'), 'ubm_spoof');

%% ������� ��������� background ������ ubm
map_tau = 10.0;
config = 'mwv';

ubm_adapted_genuine = mapAdapt(training_genuine(:), ubm, map_tau, config);
ubm_adapted_spoof   = mapAdapt(training_spoof(:), ubm, map_tau, config);

%%
save(fullfile(directory_features, 'ubm_adapted_genuine.mat'), 'ubm_adapted_genuine');
save(fullfile(directory_features, 'ubm_adapted_spoof.mat'), 'ubm_adapted_spoof');

%% ������� scores ��� ���������������� �������

scores_nonadapted = zeros(size(evaluationFeature));

parfor i = 1:length(evaluationFeature)
    ubm_genuine_llk = mean(compute_llk(evaluationFeature{i}, ubm_genuine.mu, ubm_genuine.sigma, ubm_genuine.w(:)));
    ubm_spoof_llk = mean(compute_llk(evaluationFeature{i}, ubm_spoof.mu, ubm_spoof.sigma, ubm_spoof.w(:)));
    scores_nonadapted(i) = ubm_genuine_llk - ubm_spoof_llk;
end

%% EER ��� ���������������� ������� (EER is 24.90)

[Pmiss,Pfa] = rocch(scores_nonadapted(strcmp(labels,'genuine')),scores_nonadapted(strcmp(labels,'spoof')));
[pm,pf] = compute_roc(scores_nonadapted(strcmp(labels,'genuine')),scores_nonadapted(strcmp(labels,'spoof')));
EER = rocch2eer(Pmiss,Pfa) * 100; 
fprintf('EER is %.2f\n', EER);

%% ������� scores ��� �������������� �������

scores_adapted = zeros(size(evaluationFeature));

for i = 1:length(evaluationFeature)
    ubm_genuine_llk = mean(compute_llk(evaluationFeature{i}, ubm_adapted_genuine.mu, ubm_adapted_genuine.sigma, ubm_adapted_genuine.w(:)));
    ubm_spoof_llk = mean(compute_llk(evaluationFeature{i}, ubm_adapted_spoof.mu, ubm_adapted_spoof.sigma, ubm_adapted_spoof.w(:)));
    scores_adapted(i) = ubm_genuine_llk - ubm_spoof_llk;
end

%% EER ��� �������������� ������� (EER is 27.14) map_tau = 10.0, config = 'mwv'

[Pmiss,Pfa] = rocch(scores_adapted(strcmp(labels,'genuine')),scores_adapted(strcmp(labels,'spoof')));
[pm,pf] = compute_roc(scores_adapted(strcmp(labels,'genuine')),scores_adapted(strcmp(labels,'spoof')));
EER = rocch2eer(Pmiss,Pfa) * 100; 
fprintf('EER is %.2f\n', EER);
