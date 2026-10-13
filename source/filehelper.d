module filehelper;

import config : Config, OutputFormat;
import draw : RawImage;
import logging : LogLevel, LogDg;
import std.zip : ZipArchive;

string[] storeImages(const RawImage[] images, int requestFrame, immutable(Config) config,
        const scope string outputFilename, const scope string zipFilename, LogDg log,
        float animationInterval, ZipArchive archive, ushort animationFrameRate = 0,
        ubyte[]* responseBody = null)
{
    import std.file : mkdirRecurse, FileException;
    import std.path : buildPath;

    bool shouldPutInZip = config.outputFormat == OutputFormat.zip;
    string[] filenames;

    if (responseBody is null)
    {
        try
        {
            if (shouldPutInZip)
            {
                mkdirRecurse(buildPath(config.outdir, zipFilename, outputFilename));
            }
            else
            {
                mkdirRecurse(buildPath(config.outdir, outputFilename));
            }
        }
        catch (FileException err)
        {
            log(LogLevel.error, err.msg);
            return [];
        }
    }

    if (config.singleframes)
    {
        foreach (i, image; images)
        {
            auto names = storeImage(image, cast(int) i, outputFilename, config, zipFilename,
                    archive, responseBody);
            filenames ~= names.filename;
        }
    }

    if (images.length > 1)
    {
        auto names = storeAnimation(images, outputFilename, config, animationInterval,
                animationFrameRate, zipFilename, archive, responseBody);
        filenames ~= names.filename;
    }
    else
    {
        if (requestFrame < 0)
        {
            auto names = storeImage(images[0], -1, outputFilename, config, zipFilename,
                    archive, responseBody);
            filenames ~= names.filename;
        }
        else
        {
            auto names = storeImage(images[0], requestFrame, outputFilename, config, zipFilename,
                    archive, responseBody);
            filenames ~= names.filename;
        }
    }

    return filenames;
}

private auto storeImage(const scope RawImage image, int frame, const scope string outputFilename,
        immutable(Config) config, lazy const scope string zipFilename, lazy ZipArchive archive,
        ubyte[]* responseBody)
{
    import imageformats.png : saveToPngFile, saveToPngMemory;

    auto names = getFilenames(outputFilename, config, zipFilename, config.outputFormat, config.action, frame);

    if (config.outputFormat == OutputFormat.zip)
    {
        import std.path : buildPath;

        if (responseBody !is null)
        {
            putDataInZip(archive, saveToPngMemory(image),
                    buildPath(outputFilename, names.basename));
        }
        else
        {
            saveToPngFile(image, names.filename);
            putFileInZip(archive, names.filename, buildPath(outputFilename, names.basename));
        }
    }
    else if (responseBody !is null)
    {
        if ((*responseBody).length == 0)
        {
            *responseBody = saveToPngMemory(image);
        }
    }
    else
    {
        saveToPngFile(image, names.filename);
    }

    return names;
}

private auto storeAnimation(const scope RawImage[] images, const scope string outputFilename,
        immutable(Config) config, float animationInterval, ushort animationFrameRate,
        lazy const scope string zipFilename, lazy ZipArchive archive, ubyte[]* responseBody)
{
    import imageformats.png : saveToApngFile, saveToApngMemory;
    import std.conv : to;

    auto names = getFilenames(outputFilename, config, zipFilename, config.outputFormat, config.action, -1);

    ushort delayNumerator;
    ushort delayDenominator;
    if (animationFrameRate > 0)
    {
        delayNumerator = 1;
        delayDenominator = animationFrameRate;
    }
    else
    {
        delayNumerator = (25 * animationInterval).to!ushort;
        delayDenominator = 1000;
    }

    if (config.outputFormat == OutputFormat.zip)
    {
        import std.path : buildPath;

        if (responseBody !is null)
        {
            putDataInZip(archive, saveToApngMemory(images, delayNumerator,
                    delayDenominator), buildPath(outputFilename, names.basename));
        }
        else
        {
            saveToApngFile(images, names.filename, delayNumerator, delayDenominator);
            putFileInZip(archive, names.filename, buildPath(outputFilename, names.basename));
        }
    }
    else if (responseBody !is null)
    {
        if ((*responseBody).length == 0)
        {
            *responseBody = saveToApngMemory(images, delayNumerator, delayDenominator);
        }
    }
    else
    {
        saveToApngFile(images, names.filename, delayNumerator, delayDenominator);
    }

    return names;
}

private auto getFilenames(const scope string outputFilename, immutable(Config) config,
        lazy const scope string zipFilename, OutputFormat outputFormat, int action, int frame)
{
    import std.path : buildPath;
    import std.format : format;

    struct Filenames
    {
        string basename;
        string filename;
    }

    Filenames names;

    names.basename = (frame < 0) ? format("%d.png", action) : format("%d-%d.png", action, frame);
    names.filename = (outputFormat == OutputFormat.zip)
        ? buildPath(config.outdir, zipFilename, outputFilename, names.basename)
        : buildPath(config.outdir, outputFilename, names.basename);

    return names;
}

private void putFileInZip(ZipArchive archive, const scope string filename, const scope string nameInZip)
{
    import std.file : read;

    putDataInZip(archive, cast(ubyte[]) read(filename), nameInZip);
}

private void putDataInZip(ZipArchive archive, ubyte[] data, const scope string nameInZip)
{
    import std.zip : ArchiveMember, CompressionMethod;

    auto member = new ArchiveMember();
    member.compressionMethod = CompressionMethod.none;
    member.name = nameInZip;
    member.expandedData(data);
    archive.addMember(member);
}
