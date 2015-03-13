# Introduction #

In this page we will provide a very simple tutorial for how to use this program for face detection and recognition and tracking.


# Face detection #

For face detection we used the Open CV Viola-Jones implementation available [here](http://www.mathworks.com/matlabcentral/fileexchange/19912). The mex file available in our source code is compiled for Matlab 32-bits under windows.

For other versions of Matlab please compile the mex file again. You'll also like to add these 3 lines of code to the end of the FaceDetect.cpp file available in the Face detector src directory to avoid memory leakage.

```
cvReleaseImage( &gray );
cvReleaseMemStorage(&storage);
cvReleaseHaarClassifierCascade(&cascade);
```

Now the face detector should be ready to go.

# Face recognition #

For face recognition we used a set of training data of faces. this training data is available in the Face directory. To change this directory or modify the classes you'll have to take a look at the imageOnMatrix.m file available in the source code. You can easily understand how it works, modify it or build another one from scratch.

Currently, we are considering the face for 5 classes. Mainly the 3 developers of the project and 2 volunteers.

# Face tracking #

This is the face tracker, the reason we are all here. To make it work we have to do the following.

## Windows users ##

  * Install the free DivX codec pack. This is needed for video encoding and decoding in Matlab.
  * Type: setup\_framework(); at the Matlab prompt.

## Linux users ##

  * In the command prompt execute the following lines:

```
sudo apt-get install ffmpeg g++-4.1
sudo apt-get install libavcodec-dev libavformat-dev libavdevice-dev libswscale-dev
```

  * Type: setup\_framework(); at the Matlab prompt.

After everything is set lets execute the program on a video. Sample videos are provided in the Videos directory. You can find videos for the people whose faces were given as training data in the Faces directory. This will make it easy to understand what's going on and easily modify it.

### Execute this code ###

```
eagles_tracker('../Videos/MOV03678.AVI', 0.05, 50, 3, {'ahmed', 'lluis'});
```

### Parameters description ###

  1. Video used for testing
  1. gamma
  1. tau
  1. radius
  1. Array of classes to be recognized and tracked

That's all. Now the program should be ready to run. Play with it and have fun. For further inquiries please post your comments and we'll be glad to make the required modifications as soon as possible.