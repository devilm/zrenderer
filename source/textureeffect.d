module textureeffect;

import draw : Color, RawImage;
import linearalgebra : Box;

class TextureEffectException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

private struct TextureKeyFrame
{
    int frameIndex;
    int type;
    float offsetX;
    float offsetY;
    float[8] uvs;
    float[8] positions;
    float textureIndex;
    int animationType;
    float animationDelay;
    int blendSource;
    int blendDestination;
    float angle;
    float[4] color;
}

private struct TextureLayer
{
    string[] textureNames;
    RawImage[] textures;
    TextureKeyFrame[] keyFrames;
}

class TextureEffect
{
    private TextureLayer[] _layers;

    ushort frameRate;
    uint frameCount;
    Box bounds;

    private this(TextureLayer[] layers, uint frameCount, ushort frameRate)
    {
        this._layers = layers;
        this.frameCount = frameCount;
        this.frameRate = frameRate;
        this.bounds.toInfinity();
        import std.math : cos, sin;

        foreach (frame; 0 .. frameCount)
        {
            foreach (layer; this._layers)
            {
                TextureKeyFrame keyFrame;
                if (keyFrameAt(layer.keyFrames, cast(int) frame,
                        cast(uint) layer.textureNames.length, keyFrame))
                {
                    const angle = keyFrame.angle * (3.14159265358979323846f / 180f);
                    const cosine = cos(angle);
                    const sine = sin(angle);
                    foreach (corner; [2, 1, 0, 3])
                    {
                        const positionX = keyFrame.positions[corner];
                        const positionY = keyFrame.positions[corner + 4];
                        const x = keyFrame.offsetX - 320 +
                            positionX * cosine - positionY * sine;
                        const y = keyFrame.offsetY - 290 +
                            positionX * sine + positionY * cosine;
                        this.bounds.updateBounds(x, y, x, y);
                    }
                }
            }
        }

        if (this.bounds.isInfinite)
        {
            this.bounds.updateBounds(0, 0, 1, 1);
        }
    }

    void draw(ref RawImage destination, uint frame, int offsetX, int offsetY) const
    {
        foreach (layer; this._layers)
        {
            TextureKeyFrame keyFrame;
            if (!keyFrameAt(layer.keyFrames, cast(int) (frame % this.frameCount),
                    cast(uint) layer.textureNames.length, keyFrame))
            {
                continue;
            }

            const textureIndex = cast(int) keyFrame.textureIndex;
            if (textureIndex < 0 || textureIndex >= layer.textures.length)
            {
                continue;
            }

            auto texture = layer.textures[textureIndex];
            if (texture.width == 0 || texture.height == 0)
            {
                continue;
            }

            float[4] x;
            float[4] y;
            float[4] u;
            float[4] v;
            const angle = keyFrame.angle * (3.14159265358979323846f / 180f);
            import std.math : cos, sin;
            const cosine = cos(angle);
            const sine = sin(angle);

            foreach (corner; 0 .. 4)
            {
                const positionIndex = [2, 1, 0, 3][corner];
                const positionX = keyFrame.positions[positionIndex];
                const positionY = keyFrame.positions[positionIndex + 4];
                x[corner] = keyFrame.offsetX - 320 + positionX * cosine - positionY * sine +
                    offsetX;
                y[corner] = keyFrame.offsetY - 290 + positionX * sine + positionY * cosine +
                    offsetY;
            }

            u = [
                keyFrame.uvs[0] + keyFrame.uvs[2],
                keyFrame.uvs[0] + keyFrame.uvs[2],
                keyFrame.uvs[0],
                keyFrame.uvs[0]
            ];
            v = [
                keyFrame.uvs[1] + keyFrame.uvs[3],
                keyFrame.uvs[1],
                keyFrame.uvs[1],
                keyFrame.uvs[1] + keyFrame.uvs[3]
            ];

            drawTriangle(destination, texture, x, y, u, v, [0, 1, 2], keyFrame.color,
                    keyFrame.blendSource, keyFrame.blendDestination);
            drawTriangle(destination, texture, x, y, u, v, [0, 2, 3], keyFrame.color,
                    keyFrame.blendSource, keyFrame.blendDestination);
        }
    }
}

TextureEffect loadTextureEffect(string relativePath, string resourcePath)
{
    import std.file : read;
    import std.path : buildPath, dirName;
    import std.conv : to;
    import std.bitmanip : peek;
    import std.system : Endian;

    const strPath = buildPath(normalizeSeparators(resourcePath), "data",
            normalizeSeparators(relativePath));
    const strBytes = cast(const(ubyte)[]) read(strPath);
    size_t cursor;

    if (strBytes.length < 36 || cast(string) strBytes[0 .. 4] != "STRM")
    {
        throw new TextureEffectException("Invalid STR header: " ~ strPath);
    }

    const majorVersion = strBytes[4];
    if (majorVersion != 148)
    {
        throw new TextureEffectException("Unsupported STR version " ~
                majorVersion.to!string ~ " in " ~ strPath);
    }

    cursor = 8;
    const fps = peek!(int, Endian.littleEndian)(strBytes, cursor);
    cursor += int.sizeof;
    int maxKeyFrame = peek!(int, Endian.littleEndian)(strBytes, cursor);
    cursor += int.sizeof;
    const layerCount = peek!(int, Endian.littleEndian)(strBytes, cursor);
    cursor += int.sizeof + 16;

    if (fps <= 0 || fps > ushort.max || layerCount < 0 || layerCount > 256)
    {
        throw new TextureEffectException("Invalid STR header values: " ~ strPath);
    }

    TextureLayer[] layers = new TextureLayer[layerCount];
    const deriveFrameCount = maxKeyFrame == 0x6d617246;
    int highestKeyFrame;
    foreach (ref layer; layers)
    {
        const textureCount = readInt(strBytes, cursor);
        if (textureCount < 0 || textureCount > 256)
        {
            throw new TextureEffectException("Invalid STR texture count: " ~ strPath);
        }

        foreach (_; 0 .. textureCount)
        {
            layer.textureNames ~= readFixedString(strBytes, cursor, 128);
        }

        const keyFrameCount = readInt(strBytes, cursor);
        if (keyFrameCount < 0 || keyFrameCount > 100_000)
        {
            throw new TextureEffectException("Invalid STR keyframe count: " ~ strPath);
        }

        foreach (_; 0 .. keyFrameCount)
        {
            TextureKeyFrame keyFrame;
            keyFrame.frameIndex = readInt(strBytes, cursor);
            keyFrame.type = readInt(strBytes, cursor);
            keyFrame.offsetX = readFloat(strBytes, cursor);
            keyFrame.offsetY = readFloat(strBytes, cursor);
            foreach (ref value; keyFrame.uvs)
            {
                value = readFloat(strBytes, cursor);
            }
            foreach (ref value; keyFrame.positions)
            {
                value = readFloat(strBytes, cursor);
            }
            keyFrame.textureIndex = readFloat(strBytes, cursor);
            keyFrame.animationType = readInt(strBytes, cursor);
            keyFrame.animationDelay = readFloat(strBytes, cursor);
            keyFrame.angle = readFloat(strBytes, cursor) * (360f / 1024f);
            foreach (ref value; keyFrame.color)
            {
                value = readFloat(strBytes, cursor);
            }
            keyFrame.blendSource = readInt(strBytes, cursor);
            keyFrame.blendDestination = readInt(strBytes, cursor);
            readInt(strBytes, cursor); // Multi-texture flag

            if (keyFrame.frameIndex < 0 || keyFrame.type < 0 || keyFrame.type > 1)
            {
                throw new TextureEffectException("Invalid STR keyframe: " ~ strPath);
            }

            layer.keyFrames ~= keyFrame;
            if (deriveFrameCount && keyFrame.type == 0)
            {
                highestKeyFrame = keyFrame.frameIndex > highestKeyFrame
                    ? keyFrame.frameIndex : highestKeyFrame;
            }
        }

        bool[] usedTextures = new bool[layer.textureNames.length];
        int layerMaxFrame;
        foreach (keyFrame; layer.keyFrames)
        {
            if (keyFrame.type == 0 && keyFrame.frameIndex > layerMaxFrame)
            {
                layerMaxFrame = keyFrame.frameIndex;
            }
        }

        foreach (keyIndex, keyFrame; layer.keyFrames)
        {
            if (keyFrame.type != 0)
            {
                continue;
            }

            int endFrame = layerMaxFrame;
            foreach (nextKey; layer.keyFrames[keyIndex + 1 .. $])
            {
                if (nextKey.type == 0)
                {
                    endFrame = nextKey.frameIndex;
                    break;
                }
            }

            const hasTween = keyIndex + 1 < layer.keyFrames.length &&
                layer.keyFrames[keyIndex + 1].type == 1 &&
                layer.keyFrames[keyIndex + 1].frameIndex == keyFrame.frameIndex;
            if (!hasTween)
            {
                const textureIndex = cast(int) keyFrame.textureIndex;
                if (textureIndex >= 0 && cast(size_t) textureIndex < usedTextures.length)
                {
                    usedTextures[textureIndex] = true;
                }
                continue;
            }

            const tween = layer.keyFrames[keyIndex + 1];
            foreach (elapsed; 0 .. endFrame - keyFrame.frameIndex)
            {
                const textureIndex = animatedTextureIndex(keyFrame, tween, elapsed,
                        cast(uint) layer.textureNames.length);
                if (textureIndex >= 0 && cast(size_t) textureIndex < usedTextures.length)
                {
                    usedTextures[textureIndex] = true;
                }
            }
        }

        layer.textures.length = layer.textureNames.length;
        foreach (index, name; layer.textureNames)
        {
            if (!usedTextures[index] || name.length == 0)
            {
                continue;
            }

            const texturePath = findTexturePath(dirName(strPath), name);
            layer.textures[index] = readTexture(texturePath);
        }
    }

    if (cursor != strBytes.length)
    {
        throw new TextureEffectException("Unexpected trailing data in STR file: " ~ strPath);
    }

    if (deriveFrameCount)
    {
        maxKeyFrame = highestKeyFrame;
    }

    if (maxKeyFrame < 0 || maxKeyFrame > 100_000)
    {
        throw new TextureEffectException("Invalid STR frame count: " ~ strPath);
    }

    return new TextureEffect(layers, cast(uint) maxKeyFrame + 1, cast(ushort) fps);
}

private string normalizeSeparators(string path)
{
    import std.path : dirSeparator;

    string normalized;
    const separator = dirSeparator[0];
    foreach (character; path)
    {
        normalized ~= character == '/' || character == '\\' ? separator : character;
    }
    return normalized;
}

private int readInt(const(ubyte)[] bytes, ref size_t cursor)
{
    import std.bitmanip : peek;
    import std.system : Endian;

    ensureAvailable(bytes, cursor, int.sizeof);
    const value = peek!(int, Endian.littleEndian)(bytes, cursor);
    cursor += int.sizeof;
    return value;
}

private float readFloat(const(ubyte)[] bytes, ref size_t cursor)
{
    import std.bitmanip : peek;
    import std.system : Endian;

    ensureAvailable(bytes, cursor, float.sizeof);
    const value = peek!(float, Endian.littleEndian)(bytes, cursor);
    cursor += float.sizeof;
    return value;
}

private string readFixedString(const(ubyte)[] bytes, ref size_t cursor, size_t length)
{
    ensureAvailable(bytes, cursor, length);
    auto end = cursor;
    while (end < cursor + length && bytes[end] != 0)
    {
        ++end;
    }

    const value = cast(string) bytes[cursor .. end].dup;
    cursor += length;
    return value;
}

private void ensureAvailable(const(ubyte)[] bytes, size_t cursor, size_t length)
{
    if (cursor > bytes.length || length > bytes.length - cursor)
    {
        throw new TextureEffectException("Unexpected end of STR or texture file");
    }
}

private bool keyFrameAt(const(TextureKeyFrame)[] frames, int frame, uint textureCount,
        out TextureKeyFrame output)
{
    ptrdiff_t baseIndex = -1;
    foreach (i, keyFrame; frames)
    {
        if (keyFrame.type == 0 && keyFrame.frameIndex <= frame)
        {
            baseIndex = cast(ptrdiff_t) i;
        }
    }

    if (baseIndex < 0)
    {
        return false;
    }

    const base = frames[baseIndex];
    output = base;
    if (baseIndex + 1 >= frames.length)
    {
        return true;
    }

    const tween = frames[baseIndex + 1];
    if (tween.type != 1 || tween.frameIndex != base.frameIndex)
    {
        return true;
    }

    const elapsed = frame - base.frameIndex;
    output.offsetX += tween.offsetX * elapsed;
    output.offsetY += tween.offsetY * elapsed;
    output.angle += tween.angle * elapsed;
    foreach (index; 0 .. output.uvs.length)
    {
        output.uvs[index] += tween.uvs[index] * elapsed;
        output.positions[index] += tween.positions[index] * elapsed;
    }
    foreach (index; 0 .. output.color.length)
    {
        output.color[index] += tween.color[index] * elapsed;
    }
    output.textureIndex = animatedTextureIndex(base, tween, elapsed, textureCount);
    return true;
}

private int animatedTextureIndex(const ref TextureKeyFrame base,
        const ref TextureKeyFrame tween, int elapsed, uint textureCount)
{
    import std.algorithm : min;
    import std.math : floor;

    if (textureCount == 0)
    {
        return -1;
    }

    float index = base.textureIndex;
    switch (tween.animationType)
    {
        case 0:
            break;
        case 1:
            index += tween.textureIndex * elapsed;
            break;
        case 2:
            index = min(index + tween.animationDelay * elapsed, textureCount - 1);
            break;
        case 3:
            index += tween.animationDelay * elapsed;
            break;
        case 4:
            index -= tween.animationDelay * elapsed;
            break;
        default:
            break;
    }

    auto result = cast(int) floor(index);
    if (tween.animationType == 3 || tween.animationType == 4)
    {
        result %= cast(int) textureCount;
        if (result < 0)
        {
            result += textureCount;
        }
    }
    return result;
}

unittest
{
    TextureKeyFrame base;
    base.offsetX = 0f;
    base.offsetY = 0f;
    base.uvs[] = 0f;
    base.positions[] = 0f;
    base.textureIndex = 0;
    base.angle = 0f;
    base.color[] = 0f;
    TextureKeyFrame tween;
    tween.offsetX = 0f;
    tween.offsetY = 0f;
    tween.uvs[] = 0f;
    tween.positions[] = 0f;
    tween.color[] = 0f;
    tween.textureIndex = 0f;
    tween.type = 1;
    tween.animationType = 3;
    tween.animationDelay = 0.5f;
    tween.angle = 2f;
    tween.positions[0] = 1f;

    const frames = [base, tween];
    TextureKeyFrame evaluated;

    assert(keyFrameAt(frames, 2, 2, evaluated));
    assert(evaluated.textureIndex == 1);
    assert(evaluated.angle > 3.99f && evaluated.angle < 4.01f);
    assert(evaluated.positions[0] == 2f);

    tween.animationType = 4;
    tween.animationDelay = 1f;
    assert(animatedTextureIndex(base, tween, 1, 2) == 1);
}

private string findTexturePath(string directory, string name)
{
    import std.file : exists, dirEntries, SpanMode;
    import std.path : buildPath, baseName;
    import std.string : toLower;

    if (name.length == 0 || name == "." || name == "..")
    {
        throw new TextureEffectException("Invalid STR texture filename: " ~ name);
    }
    foreach (character; name)
    {
        if (character == '/' || character == '\\' || character == ':')
        {
            throw new TextureEffectException("Invalid STR texture filename: " ~ name);
        }
    }

    const exactPath = buildPath(directory, name);
    if (exists(exactPath))
    {
        return exactPath;
    }

    const wanted = name.toLower;
    foreach (entry; dirEntries(directory, SpanMode.shallow))
    {
        if (baseName(entry.name).toLower == wanted)
        {
            return entry.name;
        }
    }

    throw new TextureEffectException("STR texture file was not found: " ~ exactPath);
}

private RawImage readTexture(string filename)
{
    import std.file : read;

    const bytes = cast(const(ubyte)[]) read(filename);
    if (bytes.length >= 2 && bytes[0] == 'B' && bytes[1] == 'M')
    {
        return readBitmap(bytes, filename);
    }
    return readTarga(bytes, filename);
}

private RawImage readBitmap(const(ubyte)[] bytes, string filename)
{
    import std.bitmanip : peek;
    import std.system : Endian;

    if (bytes.length < 54)
    {
        throw new TextureEffectException("Invalid BMP texture: " ~ filename);
    }

    const pixelOffset = peek!(uint, Endian.littleEndian)(bytes, 10);
    const headerSize = peek!(uint, Endian.littleEndian)(bytes, 14);
    const width = peek!(int, Endian.littleEndian)(bytes, 18);
    const signedHeight = peek!(int, Endian.littleEndian)(bytes, 22);
    const bitsPerPixel = peek!(ushort, Endian.littleEndian)(bytes, 28);
    const compression = peek!(uint, Endian.littleEndian)(bytes, 30);
    const height = signedHeight < 0 ? -signedHeight : signedHeight;

    if (headerSize < 40 || width <= 0 || height <= 0 || width > 8192 || height > 8192 ||
            (bitsPerPixel != 24 && bitsPerPixel != 32) || compression != 0)
    {
        throw new TextureEffectException("Unsupported BMP texture: " ~ filename);
    }

    const bytesPerPixel = bitsPerPixel / 8;
    const rowStride = ((cast(size_t) width * bytesPerPixel + 3) / 4) * 4;
    ensureAvailable(bytes, pixelOffset, rowStride * height);

    RawImage image = { width: cast(uint) width, height: cast(uint) height,
        pixels: new Color[cast(size_t) width * height] };
    foreach (y; 0 .. height)
    {
        const sourceY = signedHeight < 0 ? y : height - y - 1;
        const row = pixelOffset + sourceY * rowStride;
        foreach (x; 0 .. width)
        {
            const index = row + x * bytesPerPixel;
            const blue = bytes[index];
            const green = bytes[index + 1];
            const red = bytes[index + 2];
            const alpha = bitsPerPixel == 32 ? bytes[index + 3] :
                (red == 0 && green == 0 && blue == 0 ? 0 : 255);
            image.pixels[cast(size_t) y * width + x] = makeColor(red, green, blue, alpha);
        }
    }

    return image;
}

private RawImage readTarga(const(ubyte)[] bytes, string filename)
{
    if (bytes.length < 18)
    {
        throw new TextureEffectException("Invalid TGA texture: " ~ filename);
    }

    const idLength = bytes[0];
    const colorMapType = bytes[1];
    const imageType = bytes[2];
    const width = bytes[12] | (bytes[13] << 8);
    const height = bytes[14] | (bytes[15] << 8);
    const bitsPerPixel = bytes[16];

    if (colorMapType != 0 || (imageType != 2 && imageType != 3 &&
            imageType != 10 && imageType != 11) || width == 0 || height == 0 ||
            width > 8192 || height > 8192 ||
            (bitsPerPixel != 8 && bitsPerPixel != 24 && bitsPerPixel != 32))
    {
        throw new TextureEffectException("Unsupported TGA texture: " ~ filename);
    }

    const bytesPerPixel = bitsPerPixel / 8;
    size_t cursor = 18 + idLength;
    RawImage image = { width: width, height: height,
        pixels: new Color[cast(size_t) width * height] };
    const topOrigin = (bytes[17] & 0x20) != 0;
    const rightOrigin = (bytes[17] & 0x10) != 0;

    size_t written;
    while (written < image.pixels.length)
    {
        size_t runLength = 1;
        bool repeated = false;
        if (imageType == 10 || imageType == 11)
        {
            ensureAvailable(bytes, cursor, 1);
            const packet = bytes[cursor++];
            runLength = (packet & 0x7F) + 1;
            repeated = (packet & 0x80) != 0;
        }

        if (runLength > image.pixels.length - written)
        {
            throw new TextureEffectException("Invalid TGA RLE packet: " ~ filename);
        }

        Color repeatedColor;
        if (repeated)
        {
            repeatedColor = readTargaPixel(bytes, cursor, bitsPerPixel);
        }

        foreach (_; 0 .. runLength)
        {
            const pixel = repeated ? repeatedColor : readTargaPixel(bytes, cursor, bitsPerPixel);
            const sourceX = written % width;
            const sourceY = written / width;
            const x = rightOrigin ? width - sourceX - 1 : sourceX;
            const y = topOrigin ? sourceY : height - sourceY - 1;
            image.pixels[y * width + x] = pixel;
            ++written;
        }
    }

    return image;
}

private Color readTargaPixel(const(ubyte)[] bytes, ref size_t cursor, uint bitsPerPixel)
{
    const bytesPerPixel = bitsPerPixel / 8;
    ensureAvailable(bytes, cursor, bytesPerPixel);

    Color color;
    if (bitsPerPixel == 8)
    {
        const value = bytes[cursor++];
        color = makeColor(value, value, value, 255);
    }
    else
    {
        color = makeColor(bytes[cursor + 2], bytes[cursor + 1], bytes[cursor],
                bitsPerPixel == 32 ? bytes[cursor + 3] : 255);
        cursor += bytesPerPixel;
    }
    return color;
}

private Color makeColor(ubyte red, ubyte green, ubyte blue, ubyte alpha) pure nothrow @safe @nogc
{
    return Color((cast(uint) alpha << 24) | (cast(uint) blue << 16) |
            (cast(uint) green << 8) | red);
}

private void drawTriangle(ref RawImage destination, const RawImage texture,
        const float[4] x, const float[4] y, const float[4] u, const float[4] v,
        const int[3] corners, const float[4] tint, int blendSource, int blendDestination)
{
    import std.algorithm : max, min;
    import std.math : ceil, floor;

    const a = corners[0];
    const b = corners[1];
    const c = corners[2];
    const area = (x[b] - x[a]) * (y[c] - y[a]) -
        (y[b] - y[a]) * (x[c] - x[a]);
    if (area == 0)
    {
        return;
    }

    const minX = max(0, cast(int) floor(min(x[a], min(x[b], x[c]))));
    const maxX = min(cast(int) destination.width - 1,
            cast(int) ceil(max(x[a], max(x[b], x[c]))));
    const minY = max(0, cast(int) floor(min(y[a], min(y[b], y[c]))));
    const maxY = min(cast(int) destination.height - 1,
            cast(int) ceil(max(y[a], max(y[b], y[c]))));

    foreach (pixelY; minY .. maxY + 1)
    {
        foreach (pixelX; minX .. maxX + 1)
        {
            const px = pixelX + 0.5f;
            const py = pixelY + 0.5f;
            const w1 = ((x[b] - px) * (y[c] - py) -
                    (y[b] - py) * (x[c] - px)) / area;
            const w2 = ((x[c] - px) * (y[a] - py) -
                    (y[c] - py) * (x[a] - px)) / area;
            const w3 = 1f - w1 - w2;
            if (w1 < 0 || w2 < 0 || w3 < 0)
            {
                continue;
            }

            const textureU = (w1 * u[a] + w2 * u[b] + w3 * u[c]) *
                (texture.width - 1);
            const textureV = (w1 * v[a] + w2 * v[b] + w3 * v[c]) *
                (texture.height - 1);
            const sampleX = min(texture.width - 1, cast(uint) max(0f, textureU));
            const sampleY = min(texture.height - 1, cast(uint) max(0f, textureV));
            Color source = texture.pixels[cast(size_t) sampleY * texture.width + sampleX];
            source.r = cast(ubyte) min(255f, source.r * clamp(tint[0], 0, 255) / 255f);
            source.g = cast(ubyte) min(255f, source.g * clamp(tint[1], 0, 255) / 255f);
            source.b = cast(ubyte) min(255f, source.b * clamp(tint[2], 0, 255) / 255f);
            source.a = cast(ubyte) min(255f, source.a * clamp(tint[3], 0, 255) / 255f);
            const destIndex = cast(size_t) pixelY * destination.width + pixelX;
            destination.pixels[destIndex] = blend(destination.pixels[destIndex], source,
                    blendSource == 5 && blendDestination == 7);
        }
    }
}

private float clamp(float value, float lower, float upper) pure nothrow @safe @nogc
{
    return value < lower ? lower : value > upper ? upper : value;
}

private Color blend(Color destination, Color source, bool additive = false) pure nothrow @safe @nogc
{
    import std.algorithm : min;

    if (source.a == 0)
    {
        return destination;
    }
    if (additive)
    {
        const alpha = source.a + destination.a * (255 - source.a) / 255;
        if (alpha == 0)
        {
            return Color.init;
        }

        Color result;
        result.r = cast(ubyte) min(255, (source.r * source.a +
                destination.r * destination.a) / alpha);
        result.g = cast(ubyte) min(255, (source.g * source.a +
                destination.g * destination.a) / alpha);
        result.b = cast(ubyte) min(255, (source.b * source.a +
                destination.b * destination.a) / alpha);
        result.a = cast(ubyte) alpha;
        return result;
    }
    if (destination.a == 0 || source.a == 255)
    {
        return source;
    }

    const alpha = source.a + destination.a * (255 - source.a) / 255;
    Color result;
    result.r = cast(ubyte) ((source.r * source.a +
            destination.r * destination.a * (255 - source.a) / 255) / alpha);
    result.g = cast(ubyte) ((source.g * source.a +
            destination.g * destination.a * (255 - source.a) / 255) / alpha);
    result.b = cast(ubyte) ((source.b * source.a +
            destination.b * destination.a * (255 - source.a) / 255) / alpha);
    result.a = cast(ubyte) alpha;
    return result;
}

unittest
{
    const destination = Color(0xFF646464);
    const source = Color(0x80646464);
    const normal = blend(destination, source);
    const additive = blend(destination, source, true);

    assert(normal.r == 100);
    assert(additive.r == 150);
    assert(additive.a == 255);
}

private void appendLE(T)(ref ubyte[] bytes, T value)
{
    import std.bitmanip : nativeToLittleEndian;

    auto littleEndian = nativeToLittleEndian(value);
    bytes ~= littleEndian[];
}

unittest
{
    import std.file : mkdirRecurse, rmdirRecurse, tempDir, write;
    import std.path : buildPath, dirSeparator;
    import std.uuid : randomUUID;

    const root = buildPath(tempDir(), "zrenderer-str-test-" ~ randomUUID.toString);
    const effectDirectory = buildPath(root, "data", "texture", "effect");
    mkdirRecurse(effectDirectory);
    scope (exit)
    {
        rmdirRecurse(root);
    }

    ubyte[] strBytes = cast(ubyte[]) "STRM".dup;
    strBytes ~= [cast(ubyte) 148, 0, 0, 0];
    strBytes.appendLE(60);
    strBytes.appendLE(1);
    strBytes.appendLE(1);
    strBytes ~= new ubyte[16];
    strBytes.appendLE(3);

    foreach (name; ["MISSING.BMP", "FIXTURE.BMP", "FIXTURE.TGA"])
    {
        strBytes ~= cast(const(ubyte)[]) name;
        strBytes ~= new ubyte[128 - name.length];
    }

    strBytes.appendLE(2);
    foreach (frame, textureIndex; [1f, 2f])
    {
        strBytes.appendLE(cast(int) frame);
        strBytes.appendLE(0);
        strBytes.appendLE(320f);
        strBytes.appendLE(290f);
        foreach (value; [0f, 0f, 1f, 1f, 0f, 0f, 1f, 1f])
        {
            strBytes.appendLE(value);
        }
        foreach (value; [-2f, 2f, 2f, -2f, -2f, -2f, 2f, 2f])
        {
            strBytes.appendLE(value);
        }
        strBytes.appendLE(textureIndex);
        strBytes.appendLE(0);
        strBytes.appendLE(0f);
        strBytes.appendLE(0f);
        foreach (_; 0 .. 3)
        {
            strBytes.appendLE(255f);
        }
        strBytes.appendLE(255f);
        strBytes.appendLE(5);
        strBytes.appendLE(7);
        strBytes.appendLE(0);
    }
    write(buildPath(effectDirectory, "test.str"), strBytes);

    ubyte[] bmpBytes = cast(ubyte[]) "BM".dup;
    bmpBytes.appendLE(58u);
    bmpBytes.appendLE(0u);
    bmpBytes.appendLE(54u);
    bmpBytes.appendLE(40u);
    bmpBytes.appendLE(1);
    bmpBytes.appendLE(1);
    bmpBytes.appendLE(cast(ushort) 1);
    bmpBytes.appendLE(cast(ushort) 24);
    bmpBytes.appendLE(0u);
    bmpBytes.appendLE(4u);
    bmpBytes.appendLE(0u);
    bmpBytes.appendLE(0u);
    bmpBytes.appendLE(0u);
    bmpBytes.appendLE(0u);
    bmpBytes ~= [5, 25, 200, 0];
    write(buildPath(effectDirectory, "fixture.bmp"), bmpBytes);

    ubyte[22] tgaBytes;
    tgaBytes[2] = 2;
    tgaBytes[12] = 1;
    tgaBytes[14] = 1;
    tgaBytes[16] = 32;
    tgaBytes[17] = 0x20;
    tgaBytes[18] = 10;
    tgaBytes[19] = 20;
    tgaBytes[20] = 220;
    tgaBytes[21] = 255;
    write(buildPath(effectDirectory, "fixture.tga"), tgaBytes[]);

    string mixedRoot;
    const separator = dirSeparator[0];
    foreach (character; root)
    {
        mixedRoot ~= character == separator ? (separator == '\\' ? '/' : '\\') : character;
    }
    auto effect = loadTextureEffect("texture\\effect\\test.str", mixedRoot);
    assert(effect.frameCount == 2);
    assert(effect.frameRate == 60);
    assert(effect.bounds.x1 == -2 && effect.bounds.y1 == -2);
    assert(effect.bounds.x2 == 2 && effect.bounds.y2 == 2);

    RawImage output = { width: 5, height: 5, pixels: new Color[25] };
    effect.draw(output, 0, 2, 2);
    assert(output.pixels[12].a > 0);
    assert(output.pixels[12].r > 100);

    output.pixels[] = Color.init;
    effect.draw(output, 1, 2, 2);
    assert(output.pixels[12].a > 0);
    assert(output.pixels[12].r > 100);
}
