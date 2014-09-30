
########### functions ################


function ConvertFramerate(clip v, float framerateIn, float framerateOut)
{
    v = v.AssumeFPS(framerateIn)
    v = v.ChangeFPS(framerateOut)
    return v
}
function slow50(clip v, float framerate)
{
    v = v.assumeFPS(framerate/2)
    return v.changeFPS(framerate)
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

function slowmo_50(clip v, float framerate)
{
    v=assumeTFF(v)
    v=bob(v)

    return v.assumefps(framerate)
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

function TransitionSlowMoWorker(clip v, int frameStart, int frameEnd, float timeFactor)
{
    slow = Trim(v, frameStart, frameEnd)

    newFramerate = (v.framerate * timeFactor > 0) ? v.framerate * timeFactor : 1

    slow = slow.assumeFPS(newFramerate)
    slow = ConvertFramerate(slow, slow.framerate, v.framerate)

    fontsize = (v.width > 1000) ? v.width/14 : v.width/10


    stringSpeed = (v.framerate > newFramerate) ? "1/" + String(int(v.framerate/newFramerate)) + "x" : String(int(newFramerate/v.framerate)) + "x"

    widthFactor = (float(v.width) / float(v.height) > 1.6) ? 0.85 : 0.8

    slow = Subtitle(slow, stringSpeed, int(v.width*widthFactor), int(v.height *.85), font="Agency FB", text_color=$00ffffff, halo_color=$ff000000, size=fontsize)

    # debug subtitle
    #slow = Subtitle(slow, String(newFramerate), 200, 100, font="Agency FB", text_color=$00ffffff, halo_color=$ff000000, size=75)


    return slow
}


function TransitionBuild(clip v, float endingFactor, float timeFactor)
{
    # what is this going to look like?
    #
    #   length of clip is how many frames we have to transition
    #   parameter saying what our starting rate was
    #   parameter saying what our ending rate is

    # ok so every pass halves the framerate

    thisRate = (endingFactor >= timeFactor/2.0) ? endingFactor : timeFactor/2.0

    front = TransitionSlowMoWorker(v, 0, v.framecount/2, thisRate)

    back = Trim(v, v.framecount/2 + 1, 0)

    return (endingFactor >= timeFactor) ? front : front + TransitionBuild(back, endingFactor, thisRate)
}

function TransitionBuildOut(clip v, float endingFactor, float timeFactor)
{
    # what is this going to look like?
    #
    #   length of clip is how many frames we have to transition
    #   parameter saying what our starting rate was
    #   parameter saying what our ending rate is

    # ok so every pass halves the framerate

    thisRate = (endingFactor >= timeFactor/2.0) ? endingFactor : timeFactor/2.0

    front = Trim(v, 0, v.framecount/2)

    back = TransitionSlowMoWorker(v, v.framecount/2, 0, thisRate)

    return (endingFactor >= timeFactor) ? back : TransitionBuildOut(front, endingFactor, thisRate) + back
}

##
## Smoothly slows down and speeds up the video around the given frames
##
function TransitionSlowMo(clip v, int frameStartIn, int frameEndIn, float timeFactor, early_amount)
{
    # slow down at frameStart

    frameEnd = (frameEndIn == 0) ? v.framecount : frameEndIn
    frameStart = (frameStartIn == 0) ? 1 : frameStartIn


    transitionIn = TransitionBuild(Trim(v, frameStart, frameStart + early_amount), timeFactor, 1)

    slow = TransitionSlowMoWorker(v, frameStart + early_amount, frameEnd - early_amount, timeFactor)

    front = Trim(v, 0, frameStart)

    back = Trim(v, frameEnd, 0)



    transitionOutAndBack = (frameEndIn == 0) ? back : TransitionBuildOut(Trim(v, frameEnd - early_amount, frameEnd), timeFactor, 1) + back

    return front + transitionIn + slow + transitionOutAndBack

}




