% resampling audio with libav

 In certain situations you might be faced with a multi-media which contains several audio stream, which were sampled at different rates. Too make things less complicated you might want to resample all these streams to a common sampling prior to working with them. libav has a built-in audio resampler that can be used to achieve this. For example to read an audio-file at 50Hz, which was originally sampled at 44100Hz, you can do the following:

    >>> from tests.common import fate_suite
    >>> from av.io import input
    >>>
    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> for stream, in input('a:0', 1000, audiofile, rate=50):
    ...   print(stream.shape)
