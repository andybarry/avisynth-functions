# use: import("abarryAviSynthFunctions.avs")
########### functions ################


function ConvertFramerate(clip v, float framerateIn, float framerateOut)
{
    v = v.AssumeFPS(framerateIn)
    v = v.ChangeFPS(framerateOut)
    return v
}

function AddBlankAudio(clip v, int rate)
{
    blankAudio = BlankClip(v, audio_rate=rate, channels=2)
    return AudioDub(v, blankAudio)
}

function ImportPng(string filename, int length)
{
    imageClip = ImageSource(filename, end=length)
    imageClip = imageClip.ConvertToYV12()
    imageClip = imageClip.AssumeFPS(30)

    return imageClip
}

function ConvertFormat(clip v, int width, int height, float framerate, int audiorate)
{
    # convert clips to the right size, adding bars where needed


    v = HasAudio(v) ? ((v.AudioRate == audiorate) ? v : v.ResampleAudio(audiorate) ) : AddBlankAudio(v, audiorate)


    # figure out if width or height is the limiting factor

    scaleFactor = (float(v.width) / float(v.height) > float(width)/float(height)) ? float(width)/float(v.width) : float(height)/float(v.height)

    newWidth = (int(float(v.width)*scaleFactor) % 2 == 0) ? int(float(v.width)*scaleFactor) : int(float(v.width)*scaleFactor) - 1

    newHeight = (int(float(v.height)*scaleFactor) % 2 == 0) ? int(float(v.height)*scaleFactor) : int(float(v.height)*scaleFactor) - 1


    #v = Subtitle(v, String(scaleFactor) + ": " + String(newWidth) + " x " + String(newHeight), 100, 100, font="Agency FB", text_color=$00ffffff, halo_color=$ff000000, size=20)

    v = LanczosResize(v, newWidth, newHeight)

    # now add bars

    v = AddBorders(v, (width - v.width)/2, (height - v.height)/2, (width - v.width)/2, (height - v.height)/2)

    v = v.ChangeFPS(framerate)

    return v

}

function TransitionSlowMoWorker(clip v, int frameStart, int frameEnd, float timeFactor, bool apply_text)
{
    slow = Trim(v, frameStart, frameEnd)

    newFramerate = (v.framerate * timeFactor > 0) ? v.framerate * timeFactor : 1

    slow = slow.assumeFPS(newFramerate)
    slow = ConvertFramerate(slow, slow.framerate, v.framerate)

    fontsize = (v.width > 1000) ? v.width/14 : v.width/10


    stringSpeed = (v.framerate > newFramerate) ? "1/" + String(int(v.framerate/newFramerate)) + "x" : String(int(newFramerate/v.framerate)) + "x"

    widthFactor = (float(v.width) / float(v.height) > 1.6) ? 0.85 : 0.8

    slow = (apply_text == true) ? Subtitle(slow, stringSpeed, int(v.width*widthFactor), int(v.height *.85), font="Agency FB", text_color=$00ffffff, halo_color=$ff000000, size=fontsize) : slow

    # debug subtitle
    #slow = Subtitle(slow, String(newFramerate), 200, 100, font="Agency FB", text_color=$00ffffff, halo_color=$ff000000, size=75)


    return slow
}


function TransitionBuild(clip v, float endingFactor, float timeFactor, bool apply_text)
{
    # what is this going to look like?
    #
    #   length of clip is how many frames we have to transition
    #   parameter saying what our starting rate was
    #   parameter saying what our ending rate is

    # ok so every pass halves the framerate

    thisRate = (endingFactor >= timeFactor/2.0) ? endingFactor : timeFactor/2.0

    front = TransitionSlowMoWorker(v, 0, v.framecount/2, thisRate, apply_text)

    back = Trim(v, v.framecount/2 + 1, 0)

    return (endingFactor >= timeFactor) ? front : front + TransitionBuild(back, endingFactor, thisRate, apply_text)
}

function TransitionBuildOut(clip v, float endingFactor, float timeFactor, bool apply_text)
{
    # what is this going to look like?
    #
    #   length of clip is how many frames we have to transition
    #   parameter saying what our starting rate was
    #   parameter saying what our ending rate is

    # ok so every pass halves the framerate

    thisRate = (endingFactor >= timeFactor/2.0) ? endingFactor : timeFactor/2.0

    front = Trim(v, 0, v.framecount/2)

    back = TransitionSlowMoWorker(v, v.framecount/2, 0, thisRate, apply_text)

    return (endingFactor >= timeFactor) ? back : TransitionBuildOut(front, endingFactor, thisRate) + back
}

##
## Simple slow-mo
##
## v:          video clip
## timefactor: multiplier on speed (ie 0.25 for quarter speed)
##
function SlowMo(clip v, float time_factor, bool apply_text)
{
    return TransitionSlowMoWorker(v, 0, v.framecount, time_factor, apply_text)
}

##
## Smoothly slows down and speeds up the video around the given frames
##
## v:                       video clip
## frame_start:             frame to start slowing down at
## frame_end:               frame to stop the slow-mo at (0 for end of clip)
## time_factor:             multiplier on speed (ie 0.25 for quarter speed)
## num_transition_frames:   number of frames to spend transitioning into and out of slow-mo
## apply_text:              true to add text to the corner displaying the time factor
function TransitionSlowMo(clip v, int frame_start, int frame_end, float time_factor, num_transition_frames, bool apply_text)
{
    # slow down at frameStart

    frameEnd = (frame_end == 0) ? v.framecount : frame_end
    frameStart = (frame_start == 0) ? 1 : frame_start

    num_transition_frames_at_end = (frame_end == 0) ? 0 : num_transition_frames


    transitionIn = TransitionBuild(Trim(v, frameStart, frameStart + num_transition_frames), time_factor, 1, apply_text)

    slow = TransitionSlowMoWorker(v, frameStart + num_transition_frames, frameEnd - num_transition_frames_at_end, time_factor, apply_text)

    front = Trim(v, 0, frameStart)

    back = Trim(v, frameEnd, 0)


    # if frame_end == 0, then there should be no frames after the slow-mo since the
    # entire end of the clip is slow-mo
    slowAndTransitionOut = (frame_end == 0) ? slow : slow + TransitionBuildOut(Trim(v, frameEnd - num_transition_frames, frameEnd, apply_text), time_factor, 1) + back

    return front + transitionIn + slowAndTransitionOut

}




