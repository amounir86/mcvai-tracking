function T = kalman_tracker(fname, gamma, tau, radius);
% Initialize background model parameters
Segmenter.gamma   = gamma;
Segmenter.tau     = tau;
Segmenter.radius  = radius;
Segmenter.segment = @background_subtractor;

%% Detector
Recognizer.recognize = @find_blob;
Representer.represent = @filter_blobs2;

% The tracker module.
Tracker.H          = eye(6);        % System model
Tracker.Q          = 0.1 * eye(6);  % System noise
traker_state       = eye(6);        % Measurement model
traker_state(1,3)  = 1;
traker_state(2,4)  = 1;
Tracker.F          = traker_state;
Tracker.R          = 5 * eye(6);  % Measurement noise
Tracker.innovation = 0;
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
