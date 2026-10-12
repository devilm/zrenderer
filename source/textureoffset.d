module textureoffset;

struct TextureOffset
{
    int x;
    int y;
}

class TextureOffsetException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

TextureOffset textureOffsetForPath(const scope string texturePath,
        const scope string[] configuredOffsets)
{
    import std.conv : to, ConvException;
    import std.path : baseName, dirName;
    import std.string : split, strip;

    auto normalizedPath = texturePath.dup;
    foreach (ref character; normalizedPath)
    {
        if (character == '\\')
        {
            character = '/';
        }
    }

    const effectFolder = baseName(dirName(cast(string) normalizedPath));
    TextureOffset result;
    bool[string] seenFolders;

    foreach (entry; configuredOffsets)
    {
        const fields = split(entry, "=");
        if (fields.length != 2)
        {
            throw new TextureOffsetException(
                    "Invalid texture offset '" ~ entry ~ "': expected folder=x:y");
        }

        const folder = fields[0].strip.to!string;
        if (folder.length == 0 || folder in seenFolders)
        {
            throw new TextureOffsetException(
                    "Invalid or duplicate texture offset folder: " ~ folder);
        }
        seenFolders[folder] = true;

        const values = split(fields[1], ":");
        if (values.length != 2)
        {
            throw new TextureOffsetException(
                    "Invalid texture offset '" ~ entry ~ "': expected folder=x:y");
        }

        int x;
        int y;
        try
        {
            x = values[0].strip.to!int;
            y = values[1].strip.to!int;
        }
        catch (ConvException err)
        {
            throw new TextureOffsetException(
                    "Invalid texture offset '" ~ entry ~ "': x and y must be integers");
        }

        if (folder == effectFolder)
        {
            result = TextureOffset(x, y);
        }
    }

    return result;
}

unittest
{
    const offsets = ["c_released_ground=0:0", "other_effect=-4:12"];
    assert(textureOffsetForPath("texture\\effect\\c_released_ground\\ki.str", offsets) ==
            TextureOffset(0, 0));
    assert(textureOffsetForPath("texture/effect/other_effect/ki.str", offsets) ==
            TextureOffset(-4, 12));
    assert(textureOffsetForPath("texture/effect/unconfigured/ki.str", offsets) ==
            TextureOffset.init);
}

unittest
{
    bool thrown;
    try
    {
        textureOffsetForPath("texture/effect/c_released_ground/ki.str",
                ["c_released_ground=bad:0"]);
    }
    catch (TextureOffsetException)
    {
        thrown = true;
    }
    assert(thrown);
}
