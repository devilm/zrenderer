module validation;

bool isJobArgValid(const(string)[] jobids, int maxAmount = -1) pure @safe
{
    // Do not render body
    if (jobids.length == 1 && jobids[0] == "none")
    {
        return true;
    }

    bool isValid = true;

    size_t jobcount = 0;

    foreach (jobidstr; jobids)
    {
        import std.algorithm.searching : countUntil;
        import std.string : representation;

        auto rangeIndex = countUntil(jobidstr.representation, '-');

        import std.conv : to, ConvException;

        if (rangeIndex == 0)
        {
            isValid = false;
            break;
        }
        else if (rangeIndex < 0)
        {
            try
            {
                auto id = jobidstr.to!uint;
                if (id == uint.max)
                {
                    isValid = false;
                    break;
                }
                jobcount++;
            }
            catch (ConvException err)
            {
                isValid = false;
                break;
            }
        }
        else
        {
            if (rangeIndex + 1 >= jobidstr.length)
            {
                isValid = false;
                break;
            }

            try
            {
                auto start = jobidstr[0 .. rangeIndex].to!uint;
                auto end = jobidstr[rangeIndex + 1 .. $].to!uint;

                if (end < start)
                {
                    isValid = false;
                    break;
                }

                jobcount += end == start ? 1 : (end-start);
            }
            catch (ConvException err)
            {
                isValid = false;
                break;
            }
        }
    }

    if (maxAmount >= 0 && jobcount > maxAmount)
    {
        isValid = false;
    }

    return isValid;
}

import std.regex : ctRegex;

immutable CanvasRegex = ctRegex!(`^([0-9]+)x([0-9]+)([\+\-][0-9]+)([\+\-][0-9]+)$`);

bool isCanvasArgValid(const scope string canvas) pure @safe
{
    if (canvas.length == 0 || canvas == string.init)
    {
        return true;
    }

    import std.regex : matchFirst;

    auto matchFound = matchFirst(canvas, CanvasRegex);

    if (matchFound.length == 5)
    {
        import std.conv : to, ConvException;
        try
        {
            matchFound[1].to!uint;
            matchFound[2].to!uint;
            matchFound[3].to!int;
            matchFound[4].to!int;
        }
        catch (ConvException err)
        {
            return false;
        }
    }
    else
    {
        return false;
    }

    return true;
}

bool isEffectArgValid(const scope string effect) pure @safe
{
    foreach (character; effect)
    {
        if (character < 0x20 || character == '/' || character == '\\' ||
                character == ':' || character == '*' || character == '?' ||
                character == '"' || character == '<' || character == '>' ||
                character == '|')
        {
            return false;
        }
    }

    return effect != "." && effect != ".." &&
            (effect.length == 0 || (effect[$ - 1] != '.' && effect[$ - 1] != ' '));
}

bool isTextureArgValid(const scope string texture) pure @safe
{
    if (texture.length == 0)
    {
        return true;
    }

    if (texture[0] == '/' || texture[0] == '\\')
    {
        return false;
    }

    foreach (character; texture)
    {
        if (character < 0x20 || character == ':' || character == '*' ||
                character == '?' || character == '"' || character == '<' ||
                character == '>' || character == '|')
        {
            return false;
        }
    }

    import std.string : toLower;

    bool hasStrExtension = false;
    bool hasTextureRoot = false;
    size_t segmentCount;
    string lastSegment;
    string normalized;
    foreach (character; texture)
    {
        normalized ~= character == '\\' ? '/' : character;
    }

    import std.algorithm.iteration : splitter;
    foreach (segment; normalized.splitter('/'))
    {
        const index = segmentCount;
        ++segmentCount;
        lastSegment = segment.idup;
        if (segment.length == 0 || segment == "." || segment == "..")
        {
            return false;
        }
        if (index == 0 && segment != "texture")
        {
            return false;
        }
        if (index == 0)
        {
            hasTextureRoot = segment == "texture";
            continue;
        }
    }

    hasStrExtension = lastSegment.length >= 4 &&
        lastSegment[$ - 4 .. $].toLower == ".str";
    return hasTextureRoot && segmentCount >= 2 && hasStrExtension;
}

unittest
{
    assert(isEffectArgValid(""));
    assert(isEffectArgValid("subject_aura"));
    assert(isEffectArgValid("2026-aura"));
    assert(isEffectArgValid("거스트"));
    assert(isEffectArgValid("한복천사(날개)"));
    assert(!isEffectArgValid("../subject_aura"));
    assert(!isEffectArgValid("folder\\effect"));
    assert(isEffectArgValid("aura effect"));
    assert(!isEffectArgValid("."));
    assert(!isEffectArgValid("effect."));
    assert(isTextureArgValid(""));
    assert(isTextureArgValid("texture\\effect\\c_released_ground\\ki.str"));
    assert(isTextureArgValid("texture/effect/ki.STR"));
    assert(!isTextureArgValid("../texture/effect/ki.str"));
    assert(!isTextureArgValid("texture\\..\\ki.str"));
    assert(!isTextureArgValid("C:\\data\\ki.str"));
    assert(!isTextureArgValid("texture\\effect\\ki.bmp"));
}
