import av
import av.datasets


input_ = av.open(av.datasets.curated('pexels/time-lapse-video-of-night-sky-857195.mp4'))
output1 = open('night-sky.raw', 'wb')
output = open('night-sky.h264', 'wb')

filter_ = av.BitStreamFilterContext('h264_mp4toannexb')

for in_packet in input_.demux(video=0):
    output1.write(in_packet)
    for out_packet in filter_(in_packet):
        output.write(out_packet)
