% Read audio-stream from a multi-media file

 Hey there, welcome to the tutorial section for the python-avio library. In this tutorial you will learn how to read audio data from a multi-media file, and how to convert to a python numpy array for further processing.

 In python-avio a simple wrapper for the ffmpeg library suite is provided, the turorials will concentrate on a pythonic wrapper for pyav, which will allow (simplified) access to the data in a multi-media file. To start, we need first need to import the input() function of the av.io module:

    >>> from av.io import input, read

 We also need some files to work on. For now, we will use the files provided from the fate-suite of ffmpeg:

    >>> from tests.common import fate_suite

 The simplest way to load a file is to load it into memory completly, which however limits the size of the datafile that you can load and can slow down your program:

    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> (stream,), meta = read('a:', audiofile, 50)

 read() returns a list of streams, and a list of metadata. With the above shown syntax the first stream can be
extracted from this list. This streams contains two channels, and 90 frames when resampled to 50Hz:

    >>> print( stream.shape )
    (2, 90)

 This function allows to specify an input (this can be any string, a local file, a tcp stream, or anything ffmpeg can read as an input) to read from. The streams you want to read. By default, all streams are read. The input rate in which you want to read the streams, and the total amount of time you like to cover for each returned block of data. The input will then return an iterator to loop over blocks of the read input. These blocks are returned as numpy array containing the data for each stream. We'll choose a file for simplicity now:

    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> for stream, in input('a:0', audiofile, 50, 1):
    ...   print(stream.shape)
    (2, 50)
    (2, 50)
    (2, 6)


 You can also call the function to just open all streams and their stored rate and with a window of one second:


    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> for stream, in input(audiofile)
    ...   print(stream.shape)
    (2, 50)
    (2, 50)
    (2, 6)

 The numpy array objects that are returned by this function, contain additional information about the streams that are decoded. To access them there a special fields that are added at runtime (audiorate, …):

    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> for stream, in input(audiofile)
    ...   print(stream.audiorate)
    44100
    44100
    44100

 As the simplest call it is enough to just open the file and will open all streams contained in the file and their default rate. If the rates will differ they will automatically be resampled to the greatest common divider so that they can be in a synchronous fashion:


