% stream audio-data from a ffmpeg URL

 While reading a file completely into memory is a convenient way to read data, there are situations where you do not want to wait until the data source is closed, or where you do not want to keep the whole file in memory. For example, when streaming live-data from your device, you usually do not want to wait for the recording to stop before processing it's data, or keep the whole recording indefinitely in memory. These are situation where the streaming API, that is modeled based on python's iterator pattern comes into play.

 Instead of using the 'read' function, we can use the 'input' in pretty much the same way. Only one parameter is added, which is the window size. This window size specifies the duration that is collected before a new block of data is yielded by the iterator and provided to work with. This means, the input is read in blocks, which have a window-size duration. 


#    >>> from tests.common import fate_suite
#    >>> from av.io import read
#    >>>
#    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
#    >>> for stream, in input('a:0', audiofile, 50, 1):
#    ...   print(stream.shape)
#    (2, 50)
#    (2, 50)
#    (2, 6)

 You can also call the function to just open all streams and their stored rate and with a window of one second:


#   >>> for stream, in input(audiofile)
#   ...   print(stream.shape)
#   (2, 50)
#   (2, 50)
#   (2, 6)

 The numpy array objects that are returned by this function, contain additional information about the streams that are decoded. To access them there a special fields that are added at runtime (audiorate, …):

#   >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
#   >>> for stream, in input(audiofile)
#   ...   print(stream.audiorate)
#   44100
#   44100
#   44100

 As the simplest call it is enough to just open the file and will open all streams contained in the file and their default rate. If the rates will differ they will automatically be resampled to the greatest common divider so that they can be in a synchronous fashion:



