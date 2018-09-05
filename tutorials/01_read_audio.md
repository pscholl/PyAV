% Read audio-stream from a multi-media file

 Hey there, welcome to the tutorial section for the python-avio library. In this tutorial you will learn how to read audio data from a multi-media file, and how to convert to a python numpy array for further processing.

 In python-avio a simple wrapper for the ffmpeg library suite is provided, the turorials will concentrate on a pythonic wrapper for pyav, which will allow (simplified) access to the data in a multi-media file. To start, we need first need to import the input() function of the av.io module:

    >>> from av.io import input

 We also need some files to work on. For now, we will use the files provided from the fate-suite of ffmpeg:

    >>> from tests.common import fate_suite

 This function allows to specify an input (this can be any string, a local file, a tcp stream, or anything ffmpeg can read as an input) to read from. The streams you want to read. By default, all streams are read. The input rate in which you want to read the streams, and the total amount of time you like to cover for each returned block of data. The input will then return an iterator to loop over blocks of the read input. These blocks are returned as numpy array containing the data for each stream. We'll choose a file for simplicity now:

    >>> for stream, in input('a:0', fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav'), 50, 1):
    ...   print(stream.shape)
    (2, 50)
    (2, 50)
    (2, 6)
