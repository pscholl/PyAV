% reading video streams from a multi-media file

 PyAV can also be used to read video frames, mostly you want to use the input() method for this, since unpacking a video file into main memory quickly fills up your main memory:

    >>> from tests.common import fate_suite
    >>> from av.io import input
    >>> from matplotlib.pyplot import imshow
    >>>
    >>> videofile = fate_suite('mkv/test7_cut.mkv')
    >>> for vid, *_ in input('v:', file=videofile, window=1000):
    ...    print(vid.shape)
    (22, 1024, 576, 3)
    (1, 1024, 576, 3)
    (23, 1024, 576, 3)
    (24, 1024, 576, 3)
    (1, 1024, 576, 3)


 each yield of the generator returns a list of rgb24 encoded videoframes of the given width x height x rgb.

