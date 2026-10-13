module imageformats.png;

import std.stdio : File;
import draw : RawImage;
import libpng.png;

private struct MemoryOutput
{
    ubyte[] data;
    bool failed;
}

private extern(C) void writeToMemory(png_structp png_ptr, png_bytep data,
        size_t length) nothrow
{
    MemoryOutput* output;
    try
    {
        output = cast(MemoryOutput*) png_get_io_ptr(png_ptr);
        if (output.failed)
        {
            return;
        }

        output.data ~= data[0 .. length];
    }
    catch (Throwable)
    {
        if (output !is null)
        {
            output.failed = true;
        }
    }
}

private ubyte[] finishMemoryWrite(png_structp png_ptr, png_infop png_info_ptr,
        ref MemoryOutput output)
{
    png_destroy_write_struct(&png_ptr, &png_info_ptr);
    if (output.failed)
    {
        throw new Exception("Unable to allocate PNG output buffer");
    }

    return output.data;
}

void saveToPngFile(const scope RawImage image, string filename)
{
    auto file = File(filename, "wb");
    if (!file.tryLock())
    {
        file.close();
        return;
    }
    scope (exit)
    {
        file.unlock();
        file.close();
    }

    png_bytep[] png_row_pointers = new png_bytep[image.height];

    for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
    {
        png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
    }

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);
    scope(failure)
    {
        png_destroy_write_struct(&png_ptr, &png_info_ptr);
    }

    png_set_IHDR(png_ptr,
            png_info_ptr,
            image.width,
            image.height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    png_init_io(png_ptr, file.getFP());
    png_set_rows(png_ptr, png_info_ptr, cast(ubyte**) png_row_pointers);
    png_write_png(png_ptr, png_info_ptr, PNG_TRANSFORM_IDENTITY, null);

    png_destroy_write_struct(&png_ptr, &png_info_ptr);
}

ubyte[] saveToPngMemory(const scope RawImage image)
{
    png_bytep[] png_row_pointers = new png_bytep[image.height];
    for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
    {
        png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
    }

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);

    png_set_IHDR(png_ptr,
            png_info_ptr,
            image.width,
            image.height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    MemoryOutput output;
    png_set_write_fn(png_ptr, &output, &writeToMemory, null);
    png_set_rows(png_ptr, png_info_ptr, cast(ubyte**) png_row_pointers);
    png_write_png(png_ptr, png_info_ptr, PNG_TRANSFORM_IDENTITY, null);

    return finishMemoryWrite(png_ptr, png_info_ptr, output);
}

void saveToApngFile(const scope RawImage[] images, string filename, ushort delayNumerator,
        ushort delayDenominator)
{
    auto file = File(filename, "wb");
    if (!file.tryLock())
    {
        file.close();
        return;
    }
    scope (exit)
    {
        file.unlock();
        file.close();
    }

    png_bytep[] png_row_pointers = new png_bytep[images[0].height];

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);
    scope(failure)
    {
        png_destroy_write_struct(&png_ptr, &png_info_ptr);
    }

    png_set_IHDR(png_ptr,
            png_info_ptr,
            images[0].width,
            images[0].height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    png_set_acTL(png_ptr, png_info_ptr, cast(uint) images.length, 0);

    png_init_io(png_ptr, file.getFP());

    png_write_info(png_ptr, png_info_ptr);

    foreach (image; images) {
        for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
        {
            png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
        }

        png_write_frame_head(png_ptr, png_info_ptr, null, image.width, image.height, 0, 0,
                delayNumerator, delayDenominator, PNG_DISPOSE_OP_NONE, PNG_BLEND_OP_SOURCE);
        png_write_image(png_ptr, cast(ubyte**) png_row_pointers);
        png_write_frame_tail(png_ptr, png_info_ptr);
    }

    png_write_end(png_ptr, png_info_ptr);
    //png_set_rows(png_ptr, png_info_ptr, cast(ubyte**) png_row_pointers);
    //png_write_png(png_ptr, png_info_ptr, PNG_TRANSFORM_IDENTITY, null);

    png_destroy_write_struct(&png_ptr, &png_info_ptr);
}

ubyte[] saveToApngMemory(const scope RawImage[] images, ushort delayNumerator,
        ushort delayDenominator)
{
    png_bytep[] png_row_pointers = new png_bytep[images[0].height];

    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, null, null, null);
    png_infop png_info_ptr = png_create_info_struct(png_ptr);

    png_set_IHDR(png_ptr,
            png_info_ptr,
            images[0].width,
            images[0].height,
            8,
            PNG_COLOR_TYPE_RGB_ALPHA,
            PNG_INTERLACE_NONE,
            PNG_COMPRESSION_TYPE_BASE,
            PNG_FILTER_TYPE_BASE);

    png_set_acTL(png_ptr, png_info_ptr, cast(uint) images.length, 0);

    MemoryOutput output;
    png_set_write_fn(png_ptr, &output, &writeToMemory, null);
    png_write_info(png_ptr, png_info_ptr);

    foreach (image; images)
    {
        for (auto rowIndex = 0; rowIndex < image.height; ++rowIndex)
        {
            png_row_pointers[rowIndex] = cast(png_bytep) &image.pixels[rowIndex * image.width];
        }

        png_write_frame_head(png_ptr, png_info_ptr, null, image.width, image.height, 0, 0,
                delayNumerator, delayDenominator, PNG_DISPOSE_OP_NONE, PNG_BLEND_OP_SOURCE);
        png_write_image(png_ptr, cast(ubyte**) png_row_pointers);
        png_write_frame_tail(png_ptr, png_info_ptr);
    }

    png_write_end(png_ptr, png_info_ptr);

    return finishMemoryWrite(png_ptr, png_info_ptr, output);
}

unittest
{
    import draw : Color;

    RawImage image = { width: 1, height: 1, pixels: [Color(0xFF000000)] };
    auto png = saveToPngMemory(image);
    assert(png.length > 8);
    assert(png[0 .. 8] == [cast(ubyte) 137, 80, 78, 71, 13, 10, 26, 10]);

    RawImage[] frames = [image, image];
    auto apng = saveToApngMemory(frames, 1, 10);
    assert(apng.length > png.length);
    assert(apng[37 .. 41] == cast(ubyte[]) "acTL");
}
