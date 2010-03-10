function T = eagles_tracker(fname, gamma, tau, radius);
% This tracker is based on Kalman filters.
% It uses .... for segmentation
% It uses .... for detection
% It uses .... for representation
% Finally, the Kalman filter tracks position, size and velocity

%% Segmenter
% Initialize background model parameters
Segmenter.gamma   = gamma;
Segmenter.tau     = tau;
Segmenter.radius  = radius;
Segmenter.segment = @background_subtractor;

%% Detector
Recognizer.recognize = @find_blob;

%% Represnter
Representer.represent = @filter_blobs2;

%% Tracker

% Boundingbox tracker parameters
Tracker.BBH          = eye(4);        % System model
Tracker.BBQ          = 5 * eye(4);  % System noise
Tracker.BBF          = eye(4);        % Measurement model
Tracker.BBR          = 5 * eye(4);    % Measurement noise
Tracker.BBinnovation = 0;

% Velocity tracker parameters
velTMat = [1 0 1 0; 0 1 0 1; 0 0 1 0; 0 0 0 1];
Tracker.VH          = velTMat;        % System model
Tracker.VQ          = 0.5 * velTMat;  % System noise
Tracker.VF          = velTMat;        % Measurement model
Tracker.VR          = 5 * velTMat;    % Measurement noise
Tracker.Vinnovation = 0;

Tracker.track      = @kalman_step;

%% Visualizer
% A custom visualizer for the Kalman state.
Visualizer.visualize = @visualize_kalman;
Visualizer.paused    = false;

%% Initialize
% Set up the global tracking system.
T.segmenter   = Segmenter;
T.recognizer  = Recognizer;
T.representer = Representer;
T.tracker     = Tracker;
T.visualizer  = Visualizer;

%% Execute
% And run the tracker on the video.
run_tracker(fname, T);
return
